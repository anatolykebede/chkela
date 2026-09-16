import 'package:flutter/material.dart';

import 'content/content_store.dart';
import 'exam_data.dart';
import 'exam_type.dart';
import 'home_mock_data.dart';

enum MatricExamScope { whole, byGradeChapter }

enum ChapterExamMode { practice, matric }

extension ChapterExamModeDisplay on ChapterExamMode {
  String get title {
    switch (this) {
      case ChapterExamMode.practice:
        return 'Practice';
      case ChapterExamMode.matric:
        return 'Matric';
    }
  }

  String get subtitle {
    switch (this) {
      case ChapterExamMode.practice:
        return 'Mixed chapter questions';
      case ChapterExamMode.matric:
        return 'Past matric questions in this chapter';
    }
  }

  IconData get icon {
    switch (this) {
      case ChapterExamMode.practice:
        return Icons.menu_book_outlined;
      case ChapterExamMode.matric:
        return Icons.school_outlined;
    }
  }
}

extension MatricExamScopeDisplay on MatricExamScope {
  String get title {
    switch (this) {
      case MatricExamScope.whole:
        return 'Take full exam';
      case MatricExamScope.byGradeChapter:
        return 'By grade & chapter';
    }
  }

  String get subtitle {
    switch (this) {
      case MatricExamScope.whole:
        return 'Complete paper with all questions';
      case MatricExamScope.byGradeChapter:
        return 'Focus on a specific grade and chapter';
    }
  }

  IconData get icon {
    switch (this) {
      case MatricExamScope.whole:
        return Icons.fact_check_outlined;
      case MatricExamScope.byGradeChapter:
        return Icons.filter_list_outlined;
    }
  }
}

enum ExamAnswerRevealMode { immediate, atEnd }

extension ExamAnswerRevealModeDisplay on ExamAnswerRevealMode {
  String get title {
    switch (this) {
      case ExamAnswerRevealMode.immediate:
        return 'Right away';
      case ExamAnswerRevealMode.atEnd:
        return 'At the end';
    }
  }

  String get subtitle {
    switch (this) {
      case ExamAnswerRevealMode.immediate:
        return 'See the correct answer after each question';
      case ExamAnswerRevealMode.atEnd:
        return 'Review all answers when you finish';
    }
  }

  IconData get icon {
    switch (this) {
      case ExamAnswerRevealMode.immediate:
        return Icons.visibility_outlined;
      case ExamAnswerRevealMode.atEnd:
        return Icons.inventory_outlined;
    }
  }
}

class ExamSessionArgs {
  const ExamSessionArgs({
    required this.subjectName,
    required this.examType,
    required this.examTitle,
    this.examId,
    this.matricScope,
    this.grade,
    this.chapterId,
    this.chapterTitle,
    this.matricPaperTitle,
    this.noteId,
    this.noteTitle,
  });

  final String subjectName;
  final ExamType examType;
  final String examTitle;
  /// CMS exam id when available.
  final String? examId;
  final MatricExamScope? matricScope;
  final String? grade;
  final String? chapterId;
  final String? chapterTitle;
  final String? matricPaperTitle;
  final String? noteId;
  final String? noteTitle;

  String get displaySubtitle {
    if (examType == ExamType.noteQuiz && noteTitle != null) {
      return noteTitle!;
    }
    if (matricScope == MatricExamScope.byGradeChapter &&
        grade != null &&
        chapterTitle != null) {
      final short = chapterTitle!.contains(':')
          ? chapterTitle!.split(':').last.trim()
          : chapterTitle!;
      return '$grade · $short';
    }
    if (matricScope == MatricExamScope.whole) {
      return 'Full exam';
    }
    if (examType == ExamType.chapterExam &&
        chapterTitle != null &&
        matricPaperTitle != null) {
      return '${matricYearFromTitle(matricPaperTitle!)} matric · $chapterTitle';
    }
    if (examType == ExamType.chapterExam && chapterTitle != null) {
      final short = chapterTitle!.contains(':')
          ? chapterTitle!.split(':').last.trim()
          : chapterTitle!;
      return short;
    }
    return examType.title;
  }

  bool get needsMatricSetup =>
      examType == ExamType.matricExam && matricScope == null;

  bool get isChapterMatricPick =>
      examType == ExamType.chapterExam && chapterId != null;

  static ExamSessionArgs? fromExtra(Object? extra) {
    if (extra is ExamSessionArgs) return extra;
    if (extra is! String) return null;

    final parts = extra.split(' · ');
    if (parts.length < 3) return null;

    final typeTitle = parts[1];
    ExamType? examType;
    for (final type in ExamType.values) {
      if (type.title == typeTitle) {
        examType = type;
        break;
      }
    }
    if (examType == null) return null;

    return ExamSessionArgs(
      subjectName: parts[0],
      examType: examType,
      examTitle: parts.sublist(2).join(' · '),
    );
  }
}

class ExamQuestion {
  const ExamQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explanation,
  });

  final String question;
  final List<String> options;
  final int correctIndex;
  final String? explanation;

  String get correctAnswerText {
    const labels = ['A', 'B', 'C', 'D'];
    return '${labels[correctIndex]}. ${options[correctIndex]}';
  }

  String get descriptionText =>
      explanation ?? 'The correct answer is $correctAnswerText.';
}

class ExamAnswerResult {
  const ExamAnswerResult({
    required this.question,
    required this.selectedIndex,
    required this.questionNumber,
    this.flagged = false,
  });

  final ExamQuestion question;
  final int? selectedIndex;
  final int questionNumber;
  final bool flagged;

  bool get isSkipped => selectedIndex == null;
  bool get isCorrect =>
      selectedIndex != null && selectedIndex == question.correctIndex;
}

List<ExamQuestion> questionsForSession(ExamSessionArgs args) {
  final store = ContentStore.instance;
  if (!store.isLoaded) return const [];

  if (args.examType == ExamType.noteQuiz && args.noteId != null) {
    return store.questionsForNoteQuiz(args.noteId!);
  }

  if (args.examType == ExamType.chapterExam &&
      args.chapterId != null &&
      args.matricPaperTitle == null) {
    return store.questionsForChapterExam(args.chapterId!);
  }

  if (args.examType == ExamType.chapterExam &&
      args.chapterId != null &&
      args.matricPaperTitle != null) {
    final exam = args.examId != null
        ? store.subjectExamById(args.examId!)
        : store.subjectExamByTitle(
            subjectName: args.subjectName,
            gradeLabel: args.grade ?? enrolledGrade,
            type: ExamType.matricExam,
            title: args.matricPaperTitle!,
          );
    if (exam == null) return const [];
    return store.questionsForSubjectExam(
      exam,
      chapterId: args.chapterId,
    );
  }

  if (args.examType == ExamType.midExam ||
      args.examType == ExamType.finalExam ||
      args.examType == ExamType.matricExam) {
    final exam = args.examId != null
        ? store.subjectExamById(args.examId!)
        : store.subjectExamByTitle(
            subjectName: args.subjectName,
            gradeLabel: args.grade ?? enrolledGrade,
            type: args.examType,
            title: args.examTitle,
          );
    if (exam == null) return const [];
    return store.questionsForSubjectExam(
      exam,
      gradeLabel: args.matricScope == MatricExamScope.byGradeChapter
          ? args.grade
          : null,
      chapterId: args.matricScope == MatricExamScope.byGradeChapter
          ? args.chapterId
          : null,
    );
  }

  return const [];
}

int sessionQuestionCount(ExamSessionArgs args) {
  return questionsForSession(args).length;
}

int sessionDurationMinutes(ExamSessionArgs args) {
  if (args.examType == ExamType.noteQuiz) return 5;
  if (args.matricScope == MatricExamScope.byGradeChapter) return 15;
  if (args.examType == ExamType.chapterExam &&
      args.chapterId != null &&
      args.matricPaperTitle != null) {
    final count = questionsForSession(args).length;
    return (count * 0.75).ceil().clamp(5, 30);
  }
  if (args.examType == ExamType.chapterExam) {
    final count = questionsForSession(args).length;
    if (count > 0) return (count * 2).clamp(5, 120);
    return 15;
  }

  if (args.examId != null) {
    final minutes = ContentStore.instance.durationForExamId(args.examId!);
    if (minutes != null && minutes > 0) return minutes;
  }

  final exams = examsForSubject(
    args.subjectName,
    args.examType,
    gradeLabel: args.grade,
  );
  for (final exam in exams) {
    if (exam.title == args.examTitle || exam.id == args.examId) {
      return exam.durationMinutes;
    }
  }
  return 30;
}
