import 'home_mock_data.dart';

class StudyContinueSession {
  const StudyContinueSession({
    required this.subjectName,
    required this.chapterLabel,
    required this.topicTitle,
    required this.progress,
    required this.chapterId,
  });

  final String subjectName;
  final String chapterLabel;
  final String topicTitle;
  final double progress;
  final String chapterId;
}

StudyContinueSession continueSessionForGrade(String gradeSelection) {
  final stream = gradeStream(gradeSelection);
  if (stream == 'Social') {
    return const StudyContinueSession(
      subjectName: 'Geography',
      chapterLabel: 'Ch.3',
      topicTitle: 'Population & settlement',
      progress: 0.54,
      chapterId: 'geo-ch3',
    );
  }
  if (stream == 'Natural') {
    return const StudyContinueSession(
      subjectName: 'Chemistry',
      chapterLabel: 'Ch.7',
      topicTitle: 'Organic chemistry',
      progress: 0.42,
      chapterId: 'chem-ch7',
    );
  }
  return const StudyContinueSession(
    subjectName: 'Mathematics',
    chapterLabel: 'Ch.5',
    topicTitle: 'Quadratic equations',
    progress: 0.68,
    chapterId: 'maths-ch5',
  );
}
