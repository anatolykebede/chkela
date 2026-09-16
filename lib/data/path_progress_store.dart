import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/auth_session_store.dart';
import 'path_catalog.dart';
import 'path_levels.dart';
import 'path_progress_api.dart';

/// Stable progress key: `gradeId:levelId` (avoids cross-grade id collisions).
String pathStarKey(PathLevel level) => '${level.gradeId}:${level.id}';

/// Persists Path stars, streak, energy, and weak skills.
class PathProgressStore extends ChangeNotifier {
  PathProgressStore._();
  static final instance = PathProgressStore._();

  static const maxEnergy = 8;
  static const regenMinutes = 10;
  static const _starsKey = 'path_stars_v2';
  static const _clearedLegacyKey = 'path_cleared_level_ids_v1';
  static const _energyKey = 'path_energy_v3';
  static const _energyAtKey = 'path_energy_at_v3';
  static const _energyMigratedKey = 'path_energy_v3_filled';
  static const _streakKey = 'path_streak_v2';
  static const _lastPlayKey = 'path_last_play_day_v2';
  static const _weakKey = 'path_weak_skills_v2';
  static const _dailyKey = 'path_daily_done_v2';
  static const _xpKey = 'path_xp_wallet_v2';
  static const _remoteMergedKey = 'path_remote_merged_v1';

  final Map<String, int> _stars = {};
  final Map<String, int> _weakSkills = {};
  var _energy = maxEnergy;
  DateTime? _energyUpdatedAt;
  var _streak = 0;
  String? _lastPlayDay;
  String? _dailyDoneDay;
  var _xp = 0;
  bool _loaded = false;
  bool _remoteSynced = false;

  Future<void> load({bool pullRemote = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final needsFill = prefs.getBool(_energyMigratedKey) != true;

    if (_loaded && !needsFill) {
      _regenEnergy();
      await _expireBrokenStreak(persist: true);
      if (pullRemote && !_remoteSynced) {
        await _pullAndMergeRemote();
      }
      return;
    }

    final starsRaw = prefs.getString(_starsKey);
    _stars.clear();
    if (starsRaw != null && starsRaw.isNotEmpty) {
      final decoded = jsonDecode(starsRaw) as Map<String, dynamic>;
      decoded.forEach((k, v) => _stars[k] = (v as num).toInt());
    } else {
      // Migrate legacy cleared ids → 1 star.
      final legacy = prefs.getStringList(_clearedLegacyKey) ?? const [];
      for (final id in legacy) {
        _stars[id] = 1;
      }
    }
    _migrateStarKeysToNamespaced();

    final weakRaw = prefs.getString(_weakKey);
    _weakSkills.clear();
    if (weakRaw != null && weakRaw.isNotEmpty) {
      final decoded = jsonDecode(weakRaw) as Map<String, dynamic>;
      decoded.forEach((k, v) => _weakSkills[k] = (v as num).toInt());
    }

    _energy = prefs.getInt(_energyKey) ?? maxEnergy;
    final atMs = prefs.getInt(_energyAtKey);
    _energyUpdatedAt =
        atMs == null ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(atMs);
    _streak = prefs.getInt(_streakKey) ?? 0;
    _lastPlayDay = prefs.getString(_lastPlayKey);
    _dailyDoneDay = prefs.getString(_dailyKey);
    _xp = prefs.getInt(_xpKey) ?? 0;
    await _expireBrokenStreak(persist: true);

    // One-shot recovery after the broken hourly regen left tanks at 0.
    if (needsFill) {
      _energy = maxEnergy;
      _energyUpdatedAt = DateTime.now();
      await prefs.setBool(_energyMigratedKey, true);
      await prefs.setInt(_energyKey, _energy);
      await prefs.setInt(
        _energyAtKey,
        _energyUpdatedAt!.millisecondsSinceEpoch,
      );
    } else {
      _regenEnergy();
    }
    _loaded = true;

    if (pullRemote) {
      await _pullAndMergeRemote();
    }
    notifyListeners();
  }

  /// Remap bare `levelId` keys → `gradeId:levelId` using the catalog.
  void _migrateStarKeysToNamespaced() {
    final known = <String, PathLevel>{};
    for (final level in [...PathCatalogStore.instance.levels, ...pathLevels]) {
      known[level.id] = level;
    }
    final bareKeys = _stars.keys.where((k) => !k.contains(':')).toList();
    for (final key in bareKeys) {
      final level = known[key];
      if (level == null) continue;
      final nk = pathStarKey(level);
      final legacy = _stars[key] ?? 0;
      final cur = _stars[nk] ?? 0;
      if (legacy > cur) _stars[nk] = legacy;
      _stars.remove(key);
    }
  }

  Future<void> _pullAndMergeRemote() async {
    final phone = await AuthSessionStore.loadSessionPhone();
    if (phone == null || phone.isEmpty) {
      _remoteSynced = true;
      return;
    }
    final remote = await PathProgressApi.instance.fetchByPhone(phone);
    _remoteSynced = true;
    if (remote == null) return;

    var changed = false;
    final remoteStars = remote['stars'];
    if (remoteStars is Map) {
      remoteStars.forEach((k, v) {
        final n = (v as num?)?.toInt() ?? 0;
        final key = k.toString();
        if (n > (_stars[key] ?? 0)) {
          _stars[key] = n;
          changed = true;
        }
      });
    }
    final remoteWeak = remote['weakSkills'];
    if (remoteWeak is Map) {
      remoteWeak.forEach((k, v) {
        final n = (v as num?)?.toInt() ?? 0;
        final key = k.toString();
        if (n > (_weakSkills[key] ?? 0)) {
          _weakSkills[key] = n;
          changed = true;
        }
      });
    }
    final remoteXp = (remote['xp'] as num?)?.toInt() ?? 0;
    if (remoteXp > _xp) {
      _xp = remoteXp;
      changed = true;
    }
    final remoteStreak = (remote['streak'] as num?)?.toInt() ?? 0;
    if (remoteStreak > _streak) {
      _streak = remoteStreak;
      changed = true;
    }
    final remoteDaily = remote['dailyDoneDay']?.toString();
    if (remoteDaily != null &&
        remoteDaily.isNotEmpty &&
        (_dailyDoneDay == null || remoteDaily.compareTo(_dailyDoneDay!) > 0)) {
      _dailyDoneDay = remoteDaily;
      changed = true;
    }

    _migrateStarKeysToNamespaced();
    if (changed) {
      await _persist();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_remoteMergedKey, true);
    }
    await _expireBrokenStreak(persist: true);
  }

  void _regenEnergy() {
    final now = DateTime.now();
    final updated = _energyUpdatedAt ?? now;
    if (_energy >= maxEnergy) {
      _energyUpdatedAt = now;
      return;
    }
    final minutes = now.difference(updated).inMinutes;
    if (minutes < regenMinutes) return;
    final gained = minutes ~/ regenMinutes;
    if (gained <= 0) return;
    _energy = (_energy + gained).clamp(0, maxEnergy);
    // Keep leftover progress toward the next refill.
    _energyUpdatedAt = updated.add(Duration(minutes: gained * regenMinutes));
  }

  /// Full refill (used after energy-system migrations / recovery).
  Future<void> refillEnergy() async {
    await load(pullRemote: false);
    _energy = maxEnergy;
    _energyUpdatedAt = DateTime.now();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_starsKey, jsonEncode(_stars));
    await prefs.setString(_weakKey, jsonEncode(_weakSkills));
    await prefs.setInt(_energyKey, _energy);
    await prefs.setInt(
      _energyAtKey,
      (_energyUpdatedAt ?? DateTime.now()).millisecondsSinceEpoch,
    );
    await prefs.setInt(_streakKey, _streak);
    if (_lastPlayDay != null) await prefs.setString(_lastPlayKey, _lastPlayDay!);
    if (_dailyDoneDay != null) {
      await prefs.setString(_dailyKey, _dailyDoneDay!);
    }
    await prefs.setInt(_xpKey, _xp);
    notifyListeners();
  }

  String _dayKey([DateTime? dt]) {
    final d = dt ?? DateTime.now();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  /// Streak is only "alive" if the last Path play was today or yesterday.
  int get liveStreak {
    if (_streak <= 0) return 0;
    final today = _dayKey();
    final yesterday =
        _dayKey(DateTime.now().subtract(const Duration(days: 1)));
    if (_lastPlayDay == today || _lastPlayDay == yesterday) return _streak;
    return 0;
  }

  Future<void> _expireBrokenStreak({required bool persist}) async {
    if (_streak <= 0) return;
    final today = _dayKey();
    final yesterday =
        _dayKey(DateTime.now().subtract(const Duration(days: 1)));
    if (_lastPlayDay == today || _lastPlayDay == yesterday) return;
    _streak = 0;
    if (persist) await _persist();
  }

  int starsFor(String levelId) {
    // Prefer namespaced keys for catalog levels; fall back to bare id.
    for (final level in _gates) {
      if (level.id == levelId) {
        final namespaced = _stars[pathStarKey(level)];
        if (namespaced != null) return namespaced;
        break;
      }
    }
    return _stars[levelId] ?? 0;
  }

  int starsForLevel(PathLevel level) {
    final n = _stars[pathStarKey(level)];
    if (n != null) return n;
    return _stars[level.id] ?? 0;
  }

  bool isCleared(String levelId) => starsFor(levelId) >= 1;

  bool isClearedLevel(PathLevel level) => starsForLevel(level) >= 1;

  int get clearedCount =>
      _gates.where((l) => isClearedLevel(l)).length;

  int get totalStars =>
      _gates.fold<int>(0, (sum, l) => sum + starsForLevel(l));

  int get maxStars => _gates.length * 3;

  List<PathLevel> get _gates => PathCatalogStore.instance.levels;

  int get energy {
    _regenEnergy();
    return _energy;
  }

  int get streak => _streak;

  int get xpWallet => _xp;

  bool get dailyDoneToday => _dailyDoneDay == _dayKey();

  List<String> get weakSkillTags {
    final entries = _weakSkills.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in entries.take(4)) e.key];
  }

  bool get canPlay => energy > 0;

  /// Minutes until the next +1 energy (0 if full or ready now).
  int get minutesUntilNextEnergy {
    _regenEnergy();
    if (_energy >= maxEnergy) return 0;
    final updated = _energyUpdatedAt ?? DateTime.now();
    final elapsed = DateTime.now().difference(updated).inMinutes;
    final remaining = regenMinutes - (elapsed % regenMinutes);
    if (elapsed >= regenMinutes && _energy < maxEnergy) {
      // Regen should have applied; treat as ready.
      return 0;
    }
    return remaining.clamp(1, regenMinutes);
  }

  String get energyRefillLabel {
    final minutes = minutesUntilNextEnergy;
    if (energy > 0) return '';
    if (minutes <= 1) return 'Energy refills in about 1 minute';
    return 'Energy refills in $minutes minutes';
  }

  PathLevelStatus statusFor(PathLevel level) {
    if (isClearedLevel(level)) return PathLevelStatus.cleared;

    // Unlock within each grade independently (G12 does not grind G9→G12 as one chain).
    final sameGrade =
        _gates.where((l) => l.gradeId == level.gradeId).toList();
    final index = sameGrade.indexWhere((l) => l.id == level.id);
    if (index <= 0) return PathLevelStatus.current;

    final prev = sameGrade[index - 1];
    if (isClearedLevel(prev)) return PathLevelStatus.current;
    return PathLevelStatus.locked;
  }

  PathLevel? get currentLevel {
    for (final level in _gates) {
      if (statusFor(level) == PathLevelStatus.current) return level;
    }
    // All cleared: suggest lowest star for 3★ chase.
    PathLevel? best;
    var bestStars = 4;
    for (final level in _gates) {
      final s = starsForLevel(level);
      if (s < bestStars) {
        bestStars = s;
        best = level;
      }
    }
    return best ?? (_gates.isEmpty ? null : _gates.last);
  }

  /// Prefer daily if not done, else current, else imperfect stars.
  PathLevel continueTarget({bool preferDaily = true}) {
    if (preferDaily && !dailyDoneToday) {
      return PathCatalogStore.instance.dailyLevel;
    }
    return currentLevel ??
        (_gates.isEmpty
            ? PathCatalogStore.instance.dailyLevel
            : _gates.first);
  }

  Future<bool> spendEnergy() async {
    await load(pullRemote: false);
    _regenEnergy();
    if (_energy <= 0) return false;
    _energy -= 1;
    _energyUpdatedAt = DateTime.now();
    await _persist();
    return true;
  }

  /// Refund one energy (quit after paying, before a finished attempt).
  Future<void> refundEnergy() async {
    await load(pullRemote: false);
    _regenEnergy();
    if (_energy >= maxEnergy) return;
    _energy = (_energy + 1).clamp(0, maxEnergy);
    _energyUpdatedAt = DateTime.now();
    await _persist();
  }

  Future<PathAttemptResult> recordAttempt({
    required PathLevel level,
    required int stars,
    required int xpGained,
    required List<String> missedSkills,
    required bool isDaily,
  }) async {
    await load(pullRemote: false);
    final key = pathStarKey(level);
    final previous = isDaily ? 0 : starsForLevel(level);
    final best = stars > previous ? stars : previous;
    if (!isDaily && stars > 0) {
      _stars[key] = best;
      _stars.remove(level.id); // drop legacy bare id if present
    }

    final appliedXp = isDaily
        ? (stars > 0 ? xpGained : 0)
        : (xpForStars(level, best) - xpForStars(level, previous))
            .clamp(0, level.xpReward);
    if (appliedXp > 0) _xp += appliedXp;

    for (final skill in missedSkills) {
      if (skill.isEmpty) continue;
      _weakSkills[skill] = (_weakSkills[skill] ?? 0) + 1;
    }
    // Soft decay for skills they got right enough to clear with 3★.
    if (stars >= 3 && level.skillTag.isNotEmpty) {
      _weakSkills.remove(level.skillTag);
    }

    final today = _dayKey();
    if (_lastPlayDay != today) {
      final yesterday = _dayKey(DateTime.now().subtract(const Duration(days: 1)));
      if (_lastPlayDay == yesterday) {
        _streak += 1;
      } else {
        _streak = 1;
      }
      _lastPlayDay = today;
    }

    if (isDaily && stars > 0) {
      _dailyDoneDay = today;
    }

    await _persist();
    await _syncProgressToServer();
    return PathAttemptResult(
      stars: stars,
      bestStars: best,
      improved: stars > previous,
      xpGained: appliedXp > 0 ? appliedXp : (stars > 0 ? xpGained : 0),
      streak: _streak,
    );
  }

  Future<void> _syncProgressToServer() async {
    final phone = await AuthSessionStore.loadSessionPhone();
    if (phone == null || phone.isEmpty) return;
    final current = currentLevel;
    await PathProgressApi.instance.upsert(
      phone: phone,
      currentLevelId: current?.id ?? '',
      currentLevelNumber: current?.number ?? 0,
      currentLevelTitle: current?.title ?? '',
      clearedCount: clearedCount,
      totalStars: totalStars,
      streak: _streak,
      xp: _xp,
      stars: Map<String, int>.from(_stars),
      weakSkills: Map<String, int>.from(_weakSkills),
      dailyDoneDay: _dailyDoneDay,
    );
  }
}

class PathAttemptResult {
  const PathAttemptResult({
    required this.stars,
    required this.bestStars,
    required this.improved,
    required this.xpGained,
    required this.streak,
  });

  final int stars;
  final int bestStars;
  final bool improved;
  final int xpGained;
  final int streak;
}
