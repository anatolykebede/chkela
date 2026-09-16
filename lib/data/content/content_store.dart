import 'dart:async';

import 'package:flutter/foundation.dart';

import '../chapter_content_items.dart';
import '../exam_data.dart';
import '../exam_questions.dart';
import '../exam_type.dart';
import '../flashcard_data.dart';
import '../subject_chapters.dart';
import 'content_api.dart';
import 'content_local_cache.dart';

/// In-memory CMS catalog used by study / exam lookups.
///
/// Cold start is local-first (device cache, then bundled seed) so Study works
/// immediately. A background CMS sync replaces the catalog when online.
class ContentStore extends ChangeNotifier {
  ContentStore._();

  static final ContentStore instance = ContentStore._();

  ContentCatalog? _catalog;
  bool _loaded = false;
  bool _fromCache = false;
  bool _fromNetwork = false;
  bool _syncInFlight = false;

  bool get isLoaded => _loaded;
  ContentCatalog? get catalog => _catalog;
  bool get loadedFromCache => _fromCache;
  bool get loadedFromNetwork => _fromNetwork;
  bool get syncInFlight => _syncInFlight;

  /// Fast path: cache → bundled asset, then kick a background CMS sync.
  Future<void> load({bool forceRefresh = false}) async {
    if (!forceRefresh && _loaded && _catalog != null) {
      unawaited(syncFromNetwork());
      return;
    }

    await _loadLocal();
    _loaded = true;
    notifyListeners();
    unawaited(syncFromNetwork());
  }

  /// Device cache first, then the packaged `assets/content/data.json` seed.
  Future<void> _loadLocal() async {
    _fromCache = false;
    _fromNetwork = false;

    try {
      final cached = await ContentLocalCache.instance.load();
      if (cached != null) {
        _catalog = ContentCatalog.fromJson(cached);
        _fromCache = true;
        return;
      }
    } catch (_) {}

    try {
      _catalog = await ContentApi.loadBundledCatalog();
    } catch (_) {
      _catalog = null;
    }
  }

  /// Pull live CMS. On success, replaces memory + device cache.
  Future<bool> syncFromNetwork() async {
    if (_syncInFlight) return false;
    _syncInFlight = true;
    try {
      final remote = await ContentApi().fetchCatalogFromNetwork();
      if (remote == null) return false;
      _catalog = remote.catalog;
      _fromNetwork = true;
      _fromCache = false;
      _loaded = true;
      await ContentLocalCache.instance.save(remote.json);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    } finally {
      _syncInFlight = false;
    }
  }

  /// Force a network sync (keeps local catalog if the request fails).
  Future<void> refresh() async {
    final ok = await syncFromNetwork();
    if (!ok && !_loaded) {
      await _loadLocal();
      _loaded = true;
      notifyListeners();
    }
  }

  void replaceCatalog(ContentCatalog catalog) {
    _catalog = catalog;
    _loaded = true;
    notifyListeners();
  }

  List<SubjectChapter> chaptersForSubject(
    String subjectName, {
    required String gradeLabel,
  }) {
    final catalog = _catalog;
    if (catalog == null) return const [];

    final subject = catalog.subjectFor(
      subjectName: subjectName,
      gradeLabel: gradeLabel,
    );
    if (subject == null) return const [];

    final chapters = catalog.chapters
        .where((c) => c.subjectId == subject.id)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return chapters
        .map(
          (c) => SubjectChapter(
            id: c.id,
            title: c.title,
            subtitle: c.subtitle.isEmpty ? 'Chapter ${c.order}' : c.subtitle,
            order: c.order,
          ),
        )
        .toList();
  }

  List<ChapterContentItem> notesForChapter(String chapterId) {
    final catalog = _catalog;
    if (catalog == null) return const [];

    final lessonsById = {
      for (final l in catalog.lessons.where((l) => l.chapterId == chapterId))
        l.id: l,
    };

    final notes = catalog.notes
        .where((n) => n.chapterId == chapterId && n.isPublished)
        .toList()
      ..sort((a, b) {
        final ao = lessonsById[a.lessonId]?.order ?? 999;
        final bo = lessonsById[b.lessonId]?.order ?? 999;
        final byOrder = ao.compareTo(bo);
        if (byOrder != 0) return byOrder;
        return a.title.compareTo(b.title);
      });

    return notes
        .map(
          (n) {
            final lesson = n.lessonId == null ? null : lessonsById[n.lessonId];
            return ChapterContentItem(
              id: n.id,
              title: n.title,
              subtitle: lesson?.title ?? 'Note',
            );
          },
        )
        .toList();
  }

  ContentNote? noteById(String noteId) {
    final catalog = _catalog;
    if (catalog == null) return null;
    for (final n in catalog.notes) {
      if (n.id == noteId) return n;
    }
    return null;
  }

  ContentChapter? chapterById(String chapterId) {
    final catalog = _catalog;
    if (catalog == null) return null;
    for (final c in catalog.chapters) {
      if (c.id == chapterId) return c;
    }
    return null;
  }

  ContentLesson? lessonById(String lessonId) {
    final catalog = _catalog;
    if (catalog == null) return null;
    for (final l in catalog.lessons) {
      if (l.id == lessonId) return l;
    }
    return null;
  }

  List<ChapterContentItem> flashcardDecksForChapter(String chapterId) {
    final catalog = _catalog;
    if (catalog == null) return const [];
    final decks = catalog.flashcardDecks
        .where((d) => d.chapterId == chapterId && d.isPublished)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return decks.map((d) {
      final count = catalog.flashcards
          .where(
            (f) =>
                f.deckId == d.id &&
                f.isPublished &&
                f.front.trim().isNotEmpty,
          )
          .length;
      return ChapterContentItem(
        id: d.id,
        title: d.title,
        subtitle: count == 1 ? '1 card' : '$count cards',
      );
    }).toList();
  }

  List<FlashCard> flashcardsForChapter(
    String chapterId, {
    String? deckId,
  }) {
    final catalog = _catalog;
    if (catalog == null) return const [];

    final cards = catalog.flashcards
        .where((f) {
          if (!f.isPublished || f.front.trim().isEmpty) return false;
          if (deckId != null && deckId.isNotEmpty) return f.deckId == deckId;
          return f.chapterId == chapterId;
        })
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return cards
        .map((f) => FlashCard(question: f.front, answer: f.back))
        .toList();
  }

  String _cmsExamType(ExamType type) {
    switch (type) {
      case ExamType.midExam:
        return 'mid';
      case ExamType.finalExam:
        return 'final';
      case ExamType.matricExam:
        return 'matric';
      case ExamType.chapterExam:
      case ExamType.noteQuiz:
        return '';
    }
  }

  List<ExamItem> examsForSubject(
    String subjectName,
    ExamType type, {
    required String gradeLabel,
  }) {
    final catalog = _catalog;
    if (catalog == null) return const [];
    final cmsType = _cmsExamType(type);
    if (cmsType.isEmpty) return const [];

    final subject = catalog.subjectFor(
      subjectName: subjectName,
      gradeLabel: gradeLabel,
    );
    final subjectIds = catalog.subjects
        .where((s) => s.name == subjectName)
        .map((s) => s.id)
        .toSet();

    Iterable<ContentSubjectExam> matches = catalog.exams.where(
      (e) => e.type == cmsType && e.isPublished,
    );
    if (subject != null) {
      final exact = matches.where((e) => e.subjectId == subject.id).toList();
      if (exact.isNotEmpty) {
        matches = exact;
      } else {
        matches = matches.where((e) => subjectIds.contains(e.subjectId));
      }
    } else {
      matches = matches.where((e) => subjectIds.contains(e.subjectId));
    }

    return matches
        .where(
          (e) => e.questions.any((q) => q.prompt.trim().isNotEmpty),
        )
        .map(
          (e) => ExamItem(
            id: e.id,
            title: e.title,
            subtitle: e.subtitle.isEmpty
                ? (e.year != null ? 'Year ${e.year}' : type.title)
                : e.subtitle,
            questionCount: e.questions
                .where((q) => q.prompt.trim().isNotEmpty)
                .length,
            durationMinutes: e.durationMinutes,
          ),
        )
        .toList();
  }

  ContentSubjectExam? subjectExamById(String id) {
    final catalog = _catalog;
    if (catalog == null) return null;
    for (final e in catalog.exams) {
      if (e.id == id) return e;
    }
    return null;
  }

  ContentSubjectExam? subjectExamByTitle({
    required String subjectName,
    required String gradeLabel,
    required ExamType type,
    required String title,
  }) {
    final exams = examsForSubject(
      subjectName,
      type,
      gradeLabel: gradeLabel,
    );
    for (final item in exams) {
      if (item.title == title) {
        return subjectExamById(item.id);
      }
    }
    // Also search unpublished / all subjects with same name for matric papers
    // sitting on a different subject row.
    final catalog = _catalog;
    if (catalog == null) return null;
    final cmsType = _cmsExamType(type);
    for (final e in catalog.exams) {
      if (e.type == cmsType && e.title == title && e.isPublished) {
        final subject = catalog.subjects.where((s) => s.id == e.subjectId);
        if (subject.any((s) => s.name == subjectName)) return e;
      }
    }
    return null;
  }

  List<ExamQuestion> questionsForSubjectExam(
    ContentSubjectExam exam, {
    String? gradeLabel,
    String? chapterId,
  }) {
    var questions = exam.questions.where((q) => q.prompt.trim().isNotEmpty);
    if (chapterId != null && chapterId.isNotEmpty) {
      questions = questions.where((q) => q.chapterId == chapterId);
    }
    if (gradeLabel != null && gradeLabel.isNotEmpty) {
      final grade = _catalog?.gradeByLabel(gradeLabel);
      if (grade != null) {
        questions = questions.where(
          (q) => q.gradeId == null || q.gradeId == grade.id,
        );
      }
    }
    return questions
        .map(
          (q) => ExamQuestion(
            question: q.prompt,
            options: q.options,
            correctIndex: q.correctIndex.clamp(0, q.options.length - 1),
            explanation: q.explanation.isEmpty ? null : q.explanation,
          ),
        )
        .toList();
  }

  List<ExamQuestion> questionsForChapterExam(String chapterId) {
    final catalog = _catalog;
    if (catalog == null) return const [];
    final exams = catalog.chapterExams
        .where((e) => e.chapterId == chapterId && e.isPublished)
        .toList();
    if (exams.isEmpty) return const [];
    final questions = exams.first.questions
        .where((q) => q.prompt.trim().isNotEmpty)
        .toList();
    return questions
        .map(
          (q) => ExamQuestion(
            question: q.prompt,
            options: q.options,
            correctIndex: q.correctIndex.clamp(0, q.options.length - 1),
            explanation: q.explanation.isEmpty ? null : q.explanation,
          ),
        )
        .toList();
  }

  List<ExamQuestion> questionsForNoteQuiz(String noteId) {
    final catalog = _catalog;
    if (catalog == null) return const [];
    final quizzes = catalog.quizzes
        .where(
          (q) =>
              q.isPublished &&
              (q.noteId == noteId ||
                  (q.noteId == null &&
                      catalog.notes.any(
                        (n) => n.id == noteId && n.chapterId == q.chapterId,
                      ))),
        )
        .toList();
    if (quizzes.isEmpty) return const [];
    // Prefer quiz linked to this note.
    final preferred = quizzes.where((q) => q.noteId == noteId).toList();
    final quiz = preferred.isNotEmpty ? preferred.first : quizzes.first;
    return quiz.questions
        .where((q) => q.prompt.trim().isNotEmpty)
        .map(
          (q) => ExamQuestion(
            question: q.prompt,
            options: q.options,
            correctIndex: q.correctIndex.clamp(0, q.options.length - 1),
            explanation: q.explanation.isEmpty ? null : q.explanation,
          ),
        )
        .toList();
  }

  int? durationForExamId(String examId) {
    return subjectExamById(examId)?.durationMinutes;
  }
}
