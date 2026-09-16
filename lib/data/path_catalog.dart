import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'content/content_api.dart' show contentApiBaseUrl;
import 'path_challenges.dart';
import 'path_levels.dart';

/// Loads Path gates + waves from API or bundled `assets/path/data.json`.
class PathCatalogStore {
  PathCatalogStore._();
  static final instance = PathCatalogStore._();

  List<PathLevel> _levels = List<PathLevel>.from(pathLevels);
  final Map<String, List<PathChallenge>> _challengesByLevel = {};
  var _loaded = false;
  String _viewerGradeSelection = 'Grade 9';

  void setViewerGrade(String selection) {
    _viewerGradeSelection = selection;
  }

  List<PathLevel> get levels {
    final allowed = pathVisibleGradeIds(_viewerGradeSelection);
    final filtered = _levels
        .where((l) => l.status != 'draft' && allowed.contains(l.gradeId))
        .toList();
    filtered.sort((a, b) {
      final g = pathGradeSortKey(a.gradeId).compareTo(pathGradeSortKey(b.gradeId));
      if (g != 0) return g;
      return a.number.compareTo(b.number);
    });
    return filtered;
  }

  List<PathChallenge> challengesFor(String levelId) {
    final list = _challengesByLevel[levelId];
    if (list == null || list.isEmpty) return const [];
    return List<PathChallenge>.from(list);
  }

  List<PathChallenge> resolveChallenges(PathLevel level) {
    final cms = challengesFor(level.id);
    if (cms.isNotEmpty) return cms;
    return challengesForLevel(level);
  }

  /// Daily gate metadata scoped to the visible catalog (not hard-locked to Bio).
  PathLevel get dailyLevel {
    final gates = levels;
    if (gates.isEmpty) return pathDailyLevel;
    final subjects = <String, int>{};
    for (final l in gates) {
      subjects[l.subject] = (subjects[l.subject] ?? 0) + 1;
    }
    final subject = subjects.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final gradeId = gates.first.gradeId;
    return PathLevel(
      id: kPathDailyId,
      number: 0,
      title: 'Daily Streak Gate',
      kind: PathLevelKind.checkpoint,
      subject: subject,
      xpReward: 40,
      competency: 'Revisit weak skills from your Path',
      skillTag: 'daily',
      hook:
          'One short gate a day keeps your streak alive. Weak skills come back.',
      gradeId: gradeId,
    );
  }

  List<PathChallenge> resolveDaily(List<String> weakSkillTags) {
    final gates = levels;
    final visibleSkills = {for (final l in gates) l.skillTag};
    final scoped = [
      for (final tag in weakSkillTags)
        if (visibleSkills.contains(tag) || tag == 'daily') tag,
    ];

    final pool = <PathChallenge>[];
    for (final level in gates) {
      final waves = challengesFor(level.id);
      for (final c in waves) {
        final matchWeak = scoped.isEmpty ||
            scoped.contains(c.skillTag) ||
            scoped.contains(level.skillTag);
        if (matchWeak) pool.add(c);
      }
    }
    if (pool.isEmpty) {
      for (final level in gates) {
        pool.addAll(challengesFor(level.id));
      }
    }
    if (pool.isNotEmpty) {
      // Prefer variety: take up to 3 waves, skill-biased first.
      final picked = <PathChallenge>[];
      final usedTypes = <PathChallengeType>{};
      for (final c in pool) {
        if (picked.length >= 3) break;
        if (usedTypes.contains(c.type) && picked.length >= 2) continue;
        picked.add(c);
        usedTypes.add(c.type);
      }
      while (picked.length < 3 && picked.length < pool.length) {
        final next = pool[picked.length % pool.length];
        if (!picked.contains(next)) {
          picked.add(next);
        } else {
          break;
        }
      }
      return picked;
    }

    return challengesForDaily(scoped.isNotEmpty ? scoped : weakSkillTags);
  }

  PathLevel? levelById(String id) {
    if (id == kPathDailyId) return dailyLevel;
    for (final level in levels) {
      if (level.id == id) return level;
    }
    return null;
  }

  Future<void> load({bool force = false}) async {
    if (_loaded && !force) return;
    _loaded = false;
    try {
      final uri = Uri.parse('${contentApiBaseUrl()}/api/path');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        _applyJson(jsonDecode(res.body) as Map<String, dynamic>);
        _loaded = true;
        return;
      }
    } catch (_) {
      // Fall through to asset bundle.
    }

    try {
      final raw = await rootBundle.loadString('assets/path/data.json');
      _applyJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      _levels = List<PathLevel>.from(pathLevels);
      _challengesByLevel.clear();
    }
    _loaded = true;
  }

  void _applyJson(Map<String, dynamic> root) {
    final catalog = root['catalog'] is Map<String, dynamic>
        ? root['catalog'] as Map<String, dynamic>
        : root;

    final levelsRaw = catalog['levels'];
    if (levelsRaw is List && levelsRaw.isNotEmpty) {
      final parsed = <PathLevel>[];
      for (final row in levelsRaw) {
        if (row is! Map) continue;
        final map = Map<String, dynamic>.from(row);
        if (map['status'] == 'draft') continue;
        parsed.add(PathLevel.fromJson(map));
      }
      parsed.sort((a, b) => a.number.compareTo(b.number));
      if (parsed.isNotEmpty) _levels = parsed;
    }

    _challengesByLevel.clear();
    final challengesRaw = catalog['challenges'];
    if (challengesRaw is! List) return;

    final ordered = <String, List<({int order, PathChallenge c})>>{};
    for (final row in challengesRaw) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      if (map['status'] == 'draft') continue;
      final challenge = pathChallengeFromJson(map);
      if (challenge == null) continue;
      final levelId = map['levelId']?.toString() ?? '';
      if (levelId.isEmpty) continue;
      final order = (map['order'] as num?)?.toInt() ?? 0;
      ordered.putIfAbsent(levelId, () => []).add((order: order, c: challenge));
    }
    for (final entry in ordered.entries) {
      entry.value.sort((a, b) => a.order.compareTo(b.order));
      _challengesByLevel[entry.key] = [for (final x in entry.value) x.c];
    }
  }
}

PathChallenge? pathChallengeFromJson(Map<String, dynamic> map) {
  final type = map['type']?.toString() ?? 'strike';
  final skillTag = map['skillTag']?.toString() ?? 'practice';
  final waveLabel = map['waveLabel']?.toString();

  switch (type) {
    case 'blitz':
      return BlitzChallenge(
        prompt: map['prompt']?.toString() ?? '',
        isTrue: map['isTrue'] == true,
        seconds: (map['seconds'] as num?)?.toInt() ?? 8,
        skillTag: skillTag,
        waveLabel: waveLabel ?? 'BLITZ',
      );
    case 'link':
      final pairsRaw = map['pairs'];
      final pairs = <String, String>{};
      if (pairsRaw is Map) {
        pairsRaw.forEach((k, v) {
          if ('$k'.trim().isEmpty) return;
          pairs['$k'] = '$v';
        });
      }
      return LinkChallenge(
        pairs: pairs,
        skillTag: skillTag,
        waveLabel: waveLabel ?? 'LINK',
      );
    case 'sequence':
      final steps = <String>[];
      final rawSteps = map['stepsInOrder'];
      if (rawSteps is List) {
        for (final s in rawSteps) {
          final t = '$s'.trim();
          if (t.isNotEmpty) steps.add(t);
        }
      }
      return SequenceChallenge(
        title: map['title']?.toString() ?? 'Order the steps',
        stepsInOrder: steps,
        skillTag: skillTag,
        waveLabel: waveLabel ?? 'SEQUENCE',
      );
    case 'answer':
      final accepted = <String>[];
      final rawAccepted = map['acceptedAnswers'];
      if (rawAccepted is List) {
        for (final a in rawAccepted) {
          final t = '$a'.trim();
          if (t.isNotEmpty) accepted.add(t);
        }
      }
      final kindRaw = map['inputKind']?.toString() ?? 'any';
      final inputKind = switch (kindRaw) {
        'number' => AnswerInputKind.number,
        'text' => AnswerInputKind.text,
        _ => AnswerInputKind.any,
      };
      return AnswerChallenge(
        prompt: map['prompt']?.toString() ?? '',
        correctAnswer: map['correctAnswer']?.toString() ?? '',
        acceptedAnswers: accepted,
        hint: map['hint']?.toString(),
        inputKind: inputKind,
        skillTag: skillTag,
        waveLabel: waveLabel ?? 'ANSWER',
      );
    case 'strike':
    default:
      final options = <String>[];
      final rawOpts = map['options'];
      if (rawOpts is List) {
        for (final o in rawOpts) {
          options.add('$o');
        }
      }
      return StrikeChallenge(
        prompt: map['prompt']?.toString() ?? '',
        options: options,
        correctIndex: (map['correctIndex'] as num?)?.toInt() ?? 0,
        skillTag: skillTag,
        waveLabel: waveLabel ?? 'STRIKE',
      );
  }
}
