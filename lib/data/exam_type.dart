import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

enum ExamType {
  midExam,
  finalExam,
  matricExam,
  chapterExam,
  noteQuiz,
}

extension ExamTypeDisplay on ExamType {
  String get title {
    switch (this) {
      case ExamType.midExam:
        return 'Mid exam';
      case ExamType.finalExam:
        return 'Final exam';
      case ExamType.matricExam:
        return 'Matric exam';
      case ExamType.chapterExam:
        return 'Chapter exam';
      case ExamType.noteQuiz:
        return 'Note quiz';
    }
  }

  String get subtitle {
    switch (this) {
      case ExamType.midExam:
        return 'Practice mid-term style papers';
      case ExamType.finalExam:
        return 'Full end-of-term exam prep';
      case ExamType.matricExam:
        return 'Matriculation exam simulations';
      case ExamType.chapterExam:
        return 'Test yourself chapter by chapter';
      case ExamType.noteQuiz:
        return 'Quick quiz after each short note';
    }
  }

  IconData get icon {
    switch (this) {
      case ExamType.midExam:
        return Icons.assignment_outlined;
      case ExamType.finalExam:
        return Icons.fact_check_outlined;
      case ExamType.matricExam:
        return Icons.school_outlined;
      case ExamType.chapterExam:
        return Icons.menu_book_outlined;
      case ExamType.noteQuiz:
        return Icons.quiz_outlined;
    }
  }

  Color get iconColor {
    switch (this) {
      case ExamType.midExam:
        return AppColors.info;
      case ExamType.finalExam:
        return AppColors.accentText;
      case ExamType.matricExam:
        return AppColors.amber;
      case ExamType.chapterExam:
        return AppColors.teal;
      case ExamType.noteQuiz:
        return AppColors.info;
    }
  }

  Color get iconBg {
    switch (this) {
      case ExamType.midExam:
        return AppColors.infoSoft;
      case ExamType.finalExam:
        return AppColors.accentSoft;
      case ExamType.matricExam:
        return AppColors.amberSoft;
      case ExamType.chapterExam:
        return AppColors.tealSoft;
      case ExamType.noteQuiz:
        return AppColors.infoSoft;
    }
  }
}
