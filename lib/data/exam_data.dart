import 'content/content_store.dart';
import 'exam_type.dart';
import 'home_mock_data.dart';

class ExamItem {
  const ExamItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.questionCount,
    required this.durationMinutes,
    this.isCompleted = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final int questionCount;
  final int durationMinutes;
  final bool isCompleted;
}

List<ExamItem> examsForSubject(
  String subjectName,
  ExamType type, {
  String? gradeLabel,
}) {
  final store = ContentStore.instance;
  final grade = gradeLabel ?? enrolledGrade;
  if (!store.isLoaded) return const [];
  // Trust CMS only: never invent Mid / Final / Matric paper shells.
  return store.examsForSubject(
    subjectName,
    type,
    gradeLabel: grade,
  );
}

String? matricExamIdForPaper(String subjectName, String paperTitle) {
  for (final exam in examsForSubject(subjectName, ExamType.matricExam)) {
    if (exam.title == paperTitle) return exam.id;
  }
  return null;
}

String matricYearFromTitle(String paperTitle) {
  final match = RegExp(r'(20\d{2})').firstMatch(paperTitle);
  return match?.group(1) ?? '2025';
}

class MatricPaperChapterStat {
  const MatricPaperChapterStat({
    required this.examId,
    required this.title,
    required this.year,
    required this.questionCount,
  });

  final String examId;
  final String title;
  final String year;
  final int questionCount;
}

List<MatricPaperChapterStat> matricPapersForChapter({
  required String subjectName,
  required String chapterId,
}) {
  return examsForSubject(subjectName, ExamType.matricExam)
      .map(
        (paper) => MatricPaperChapterStat(
          examId: paper.id,
          title: paper.title,
          year: matricYearFromTitle(paper.title),
          questionCount: matricChapterQuestionCount(
            examId: paper.id,
            chapterId: chapterId,
            subjectName: subjectName,
          ),
        ),
      )
      .where((paper) => paper.questionCount > 0)
      .toList();
}

int matricChapterQuestionCount({
  required String examId,
  required String chapterId,
  required String subjectName,
}) {
  final store = ContentStore.instance;
  if (store.isLoaded) {
    final exam = store.subjectExamById(examId);
    if (exam != null) {
      final tagged = exam.questions
          .where((q) => q.chapterId == chapterId && q.prompt.trim().isNotEmpty)
          .length;
      if (tagged > 0) return tagged;
    }
  }

  // No invented chapter tallies when CMS has no tagged questions.
  return 0;
}
