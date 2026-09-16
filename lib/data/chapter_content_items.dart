import 'study_mode.dart';
import 'content/content_store.dart';
import 'study_progress_store.dart';
import 'subject_chapters.dart';

class ChapterContentItem {
  const ChapterContentItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.isCompleted = false,
    this.thumbnailUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final bool isCompleted;
  final String? thumbnailUrl;
}

double contentItemsProgress(List<ChapterContentItem> items) {
  if (items.isEmpty) return 0;
  return items.where((item) => item.isCompleted).length / items.length;
}

double chapterContentProgress(String chapterId) {
  return chapterProgressValue(chapterId);
}

/// Real on-device chapter progress (notes + cards + exam).
double chapterProgressValue(String chapterId, {double? storedProgress}) {
  final progress = StudyProgressStore.instance;
  final notes = rawItemsForChapter(chapterId, SubjectStudyMode.notes);
  final decks = rawItemsForChapter(chapterId, SubjectStudyMode.flashcards);

  var earned = 0.0;
  var total = 0.0;

  if (notes.isNotEmpty) {
    total += 1;
    final done = notes.where((n) => progress.isNoteDone(n.id)).length;
    earned += done / notes.length;
  }

  if (decks.isNotEmpty) {
    total += 1;
    final done = decks
        .where((d) => progress.isDeckDoneForChapter(chapterId, d.id))
        .length;
    earned += done / decks.length;
  }

  if (notes.isNotEmpty || decks.isNotEmpty) {
    total += 1;
    if (progress.isChapterExamDone(chapterId)) earned += 1;
  }

  if (total <= 0) return 0;
  return (earned / total).clamp(0.0, 1.0);
}

/// Average chapter progress for a subject in the selected grade.
double subjectStudyProgress(String subjectName, String gradeLabel) {
  final chapters = chaptersForSubject(subjectName, gradeLabel: gradeLabel);
  if (chapters.isEmpty) return 0;
  var sum = 0.0;
  for (final chapter in chapters) {
    sum += chapterProgressValue(chapter.id);
  }
  return (sum / chapters.length).clamp(0.0, 1.0);
}

ChapterContentItem _withProgress(
  ChapterContentItem item, {
  required String chapterId,
  required SubjectStudyMode mode,
}) {
  final progress = StudyProgressStore.instance;
  final done = switch (mode) {
    SubjectStudyMode.notes => progress.isNoteDone(item.id),
    SubjectStudyMode.flashcards =>
      progress.isDeckDoneForChapter(chapterId, item.id),
  };
  if (done == item.isCompleted) return item;
  return ChapterContentItem(
    id: item.id,
    title: item.title,
    subtitle: item.subtitle,
    isCompleted: done,
    thumbnailUrl: item.thumbnailUrl,
  );
}

/// Catalog items without local completion flags (for progress math).
List<ChapterContentItem> rawItemsForChapter(
  String chapterId,
  SubjectStudyMode mode,
) {
  final store = ContentStore.instance;
  switch (mode) {
    case SubjectStudyMode.notes:
      if (!store.isLoaded) return const [];
      // Trust CMS: empty means "not ready", never invent placeholder notes.
      return store.notesForChapter(chapterId);
    case SubjectStudyMode.flashcards:
      if (!store.isLoaded) return const [];
      final decks = store.flashcardDecksForChapter(chapterId);
      if (decks.isNotEmpty) return decks;
      final cards = store.flashcardsForChapter(chapterId);
      if (cards.isNotEmpty) {
        return [
          ChapterContentItem(
            id: '$chapterId-flash-deck',
            title: 'Chapter flashcards',
            subtitle: '${cards.length} cards',
          ),
        ];
      }
      return const [];
  }
}

List<ChapterContentItem> itemsForChapter(
  String chapterId,
  SubjectStudyMode mode,
) {
  return [
    for (final item in rawItemsForChapter(chapterId, mode))
      _withProgress(item, chapterId: chapterId, mode: mode),
  ];
}

String contentSectionLabel(SubjectStudyMode mode) {
  switch (mode) {
    case SubjectStudyMode.notes:
      return 'Notes';
    case SubjectStudyMode.flashcards:
      return 'Flashcards';
  }
}

String contentExpandHint(SubjectStudyMode mode) {
  switch (mode) {
    case SubjectStudyMode.notes:
      return 'Tap a chapter to browse notes';
    case SubjectStudyMode.flashcards:
      return 'Tap a chapter to open flashcards';
  }
}
