import 'content/content_store.dart';
import 'path_levels.dart';

/// Freemium rules: Biology & Geography Chapter 1, first two lessons free.
abstract final class ContentAccess {
  static const freePreviewSubjects = {'Biology', 'Geography'};

  /// First N exam questions are free; the rest require subscription.
  static const freeExamQuestionCount = 5;

  /// First N flashcards are free; the rest require subscription.
  static const freeFlashcardCount = 3;

  /// Only the first Path gate per grade is free; later gates need subscribe.
  static const freePathGateCount = 1;

  /// Subjects that show FREE tag + traveling border before subscribe.
  static bool isFreePreviewSubject(String subjectName) =>
      freePreviewSubjects.contains(subjectName.trim());

  /// 0-based question index: Q1–Q5 free.
  static bool isExamQuestionFree(
    int questionIndex, {
    required bool fullAccess,
  }) {
    if (fullAccess) return true;
    return questionIndex >= 0 && questionIndex < freeExamQuestionCount;
  }

  static bool isExamQuestionPaywalled(
    int questionIndex, {
    required bool fullAccess,
  }) =>
      !isExamQuestionFree(questionIndex, fullAccess: fullAccess);

  /// 0-based flashcard index: cards 1–3 free.
  static bool isFlashcardFree(
    int cardIndex, {
    required bool fullAccess,
  }) {
    if (fullAccess) return true;
    return cardIndex >= 0 && cardIndex < freeFlashcardCount;
  }

  static bool isFlashcardPaywalled(
    int cardIndex, {
    required bool fullAccess,
  }) =>
      !isFlashcardFree(cardIndex, fullAccess: fullAccess);

  /// 0-based index among published gates in the same grade.
  static int pathGateIndex(
    PathLevel level, {
    required List<PathLevel> sameGradeLevels,
  }) {
    final index = sameGradeLevels.indexWhere((l) => l.id == level.id);
    if (index >= 0) return index;
    return level.number - 1;
  }

  /// Daily streak gate stays free as a retention hook.
  static bool isPathLevelFree(
    PathLevel level, {
    required bool fullAccess,
    required List<PathLevel> sameGradeLevels,
  }) {
    if (fullAccess) return true;
    if (level.id == kPathDailyId) return true;
    return pathGateIndex(level, sameGradeLevels: sameGradeLevels) <
        freePathGateCount;
  }

  static bool isPathLevelPaywalled(
    PathLevel level, {
    required bool fullAccess,
    required List<PathLevel> sameGradeLevels,
  }) =>
      !isPathLevelFree(
        level,
        fullAccess: fullAccess,
        sameGradeLevels: sameGradeLevels,
      );

  /// Subject tiles locked for free users (everything except Bio / Geography).
  static bool isSubjectLocked(
    String subjectName, {
    required bool fullAccess,
  }) {
    if (fullAccess) return false;
    return !isFreePreviewSubject(subjectName);
  }

  /// Whether to show FREE marketing chrome on Bio / Geography.
  static bool showFreeSubjectHighlight(
    String subjectName, {
    required bool fullAccess,
  }) {
    if (fullAccess) return false;
    return isFreePreviewSubject(subjectName);
  }

  /// Chapter 1 only (CMS `order == 1`, or first sorted chapter if orders missing).
  static bool isFreePreviewChapter({
    required String subjectName,
    required int chapterOrder,
    required bool fullAccess,
  }) {
    if (fullAccess) return true;
    if (!isFreePreviewSubject(subjectName)) return false;
    return chapterOrder == 1;
  }

  /// Two free lessons in Chapter 1: lesson `order` 1 and 2.
  /// Overview (`order` 0) stays free so the chapter opener is readable.
  static bool isFreePreviewLesson({
    required String subjectName,
    required int chapterOrder,
    required int lessonOrder,
    required bool fullAccess,
  }) {
    if (fullAccess) return true;
    if (!isFreePreviewSubject(subjectName)) return false;
    if (chapterOrder != 1) return false;
    return lessonOrder == 0 || lessonOrder == 1 || lessonOrder == 2;
  }

  /// Resolve free access for a published note row.
  static bool isNoteFree({
    required String subjectName,
    required String chapterId,
    required String noteId,
    required bool fullAccess,
  }) {
    if (fullAccess) return true;
    if (!isFreePreviewSubject(subjectName)) return false;

    final store = ContentStore.instance;
    final chapter = store.chapterById(chapterId);
    if (chapter == null || chapter.order != 1) return false;

    final note = store.noteById(noteId);
    if (note == null) return false;
    final lessonId = note.lessonId;
    if (lessonId == null || lessonId.isEmpty) {
      // Notes without a lesson link in ch1: treat as locked except we allow none.
      return false;
    }
    final lesson = store.lessonById(lessonId);
    if (lesson == null) return false;
    return lesson.order == 0 || lesson.order == 1 || lesson.order == 2;
  }
}
