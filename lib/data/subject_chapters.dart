import 'content/content_store.dart';

class SubjectChapter {
  const SubjectChapter({
    required this.id,
    required this.title,
    required this.subtitle,
    this.order = 0,
    this.progress,
  });

  final String id;
  final String title;
  final String subtitle;
  final int order;
  final double? progress;
}

/// CMS chapters for the selected grade. Empty means not authored yet.
List<SubjectChapter> chaptersForSubject(
  String subjectName, {
  String? gradeLabel,
}) {
  final store = ContentStore.instance;
  if (!store.isLoaded) return const [];
  if (gradeLabel == null || gradeLabel.isEmpty) return const [];
  return store.chaptersForSubject(
    subjectName,
    gradeLabel: gradeLabel,
  );
}
