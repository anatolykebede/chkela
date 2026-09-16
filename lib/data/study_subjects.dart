import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'chapter_content_items.dart';
import 'content_access.dart';
import 'home_mock_data.dart';

class StudySubject {
  const StudySubject({
    required this.name,
    required this.shortCode,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.topicCount,
    required this.baseProgress,
    this.watermarkIcon,
    this.badgeLabel,
    this.lottieAsset,
    this.isLocked = false,
  });

  final String name;
  final String shortCode;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final int topicCount;
  final double baseProgress;
  /// Large faint background mark — defaults to [icon] when null.
  final IconData? watermarkIcon;
  /// Optional letter mark instead of [icon] (e.g. English "A").
  final String? badgeLabel;
  /// Optional Lottie animation for subject cards / badges.
  final String? lottieAsset;
  final bool isLocked;

  IconData get resolvedWatermark => watermarkIcon ?? icon;

  StudySubject copyWith({bool? isLocked}) {
    return StudySubject(
      name: name,
      shortCode: shortCode,
      icon: icon,
      iconBg: iconBg,
      iconColor: iconColor,
      topicCount: topicCount,
      baseProgress: baseProgress,
      watermarkIcon: watermarkIcon,
      badgeLabel: badgeLabel,
      lottieAsset: lottieAsset,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}

class StudyGradeStats {
  const StudyGradeStats({
    required this.completed,
    required this.inProgress,
  });

  final int completed;
  final int inProgress;
}

const studyStatsByGrade = {
  'Grade 9': StudyGradeStats(completed: 10, inProgress: 4),
  'Grade 10': StudyGradeStats(completed: 18, inProgress: 7),
  'Grade 11': StudyGradeStats(completed: 24, inProgress: 5),
  'Grade 12': StudyGradeStats(completed: 31, inProgress: 3),
};

/// Subjects shown on the Study screen, in display order.
const studyScreenSubjectNames = [
  'Biology',
  'Chemistry',
  'Physics',
  'Geography',
  'History',
  'Economics',
  'Mathematics',
  'English',
  'SAT',
];

/// Grade 9–10 (and any selection without a stream).
const lowerSecondarySubjectNames = [
  'Biology',
  'Chemistry',
  'Physics',
  'Geography',
  'History',
  'Economics',
  'Mathematics',
  'English',
];

/// Ethiopian Grade 11–12 Natural science stream.
const naturalStreamSubjectNames = [
  'Biology',
  'Chemistry',
  'Physics',
  'Mathematics',
  'English',
];

/// Ethiopian Grade 11–12 Social science stream.
const socialStreamSubjectNames = [
  'Geography',
  'History',
  'Economics',
  'Mathematics',
  'English',
];

List<String> subjectNamesForGradeSelection(String gradeSelection) {
  switch (gradeStream(gradeSelection)) {
    case 'Natural':
      return naturalStreamSubjectNames;
    case 'Social':
      return socialStreamSubjectNames;
    default:
      return lowerSecondarySubjectNames;
  }
}

const studySubjects = [
  StudySubject(
    name: 'Biology',
    shortCode: 'BIO',
    icon: Icons.eco_rounded,
    watermarkIcon: Icons.biotech_outlined,
    lottieAsset: 'assets/lottie/biology.json',
    iconBg: Color(0xFF0C2A1C),
    iconColor: Color(0xFF3DDC84),
    topicCount: 28,
    baseProgress: 0.72,
  ),
  StudySubject(
    name: 'Chemistry',
    shortCode: 'CHE',
    icon: Icons.science_rounded,
    watermarkIcon: Icons.hub_outlined,
    lottieAsset: 'assets/lottie/chemistry.json',
    iconBg: Color(0xFF0A2430),
    iconColor: Color(0xFF22D3EE),
    topicCount: 22,
    baseProgress: 0.38,
  ),
  StudySubject(
    name: 'Physics',
    shortCode: 'PHY',
    icon: Icons.blur_on_rounded,
    watermarkIcon: Icons.graphic_eq_rounded,
    lottieAsset: 'assets/lottie/physics.json',
    iconBg: Color(0xFF12183A),
    iconColor: Color(0xFF5B7CFF),
    topicCount: 19,
    baseProgress: 0.22,
  ),
  StudySubject(
    name: 'Geography',
    shortCode: 'GEO',
    icon: Icons.public_rounded,
    watermarkIcon: Icons.map_outlined,
    lottieAsset: 'assets/lottie/geography.json',
    iconBg: Color(0xFF241A40),
    iconColor: Color(0xFFC4B5FD),
    topicCount: 16,
    baseProgress: 0.63,
    isLocked: true,
  ),
  StudySubject(
    name: 'History',
    shortCode: 'HIS',
    icon: Icons.account_balance_rounded,
    watermarkIcon: Icons.account_balance_outlined,
    lottieAsset: 'assets/lottie/history.json',
    iconBg: Color(0xFF2E1E0A),
    iconColor: Color(0xFFF0A03A),
    topicCount: 20,
    baseProgress: 0.35,
    isLocked: true,
  ),
  StudySubject(
    name: 'Economics',
    shortCode: 'ECO',
    icon: Icons.bar_chart_rounded,
    watermarkIcon: Icons.show_chart_rounded,
    lottieAsset: 'assets/lottie/economics.json',
    iconBg: Color(0xFF0A2432),
    iconColor: Color(0xFF4FC3F7),
    topicCount: 18,
    baseProgress: 0.29,
    isLocked: true,
  ),
  StudySubject(
    name: 'Mathematics',
    shortCode: 'MAT',
    icon: Icons.functions_rounded,
    watermarkIcon: Icons.calculate_outlined,
    lottieAsset: 'assets/lottie/calculator.json',
    iconBg: Color(0xFF221A48),
    iconColor: Color(0xFF8B7CFF),
    topicCount: 34,
    baseProgress: 0.68,
  ),
  StudySubject(
    name: 'English',
    shortCode: 'ENG',
    icon: Icons.sort_by_alpha_rounded,
    watermarkIcon: Icons.menu_book_outlined,
    badgeLabel: 'A',
    lottieAsset: 'assets/lottie/english.json',
    iconBg: Color(0xFF2A2A2E),
    iconColor: Color(0xFFB0B4BC),
    topicCount: 24,
    baseProgress: 0.55,
    isLocked: true,
  ),
  StudySubject(
    name: 'SAT',
    shortCode: 'SAT',
    icon: Icons.school_outlined,
    iconBg: AppColors.accentSoft,
    iconColor: AppColors.accentText,
    topicCount: 12,
    baseProgress: 0.18,
    isLocked: true,
  ),
];

List<StudySubject> studySubjectsForScreen([
  String? gradeSelection,
  bool fullAccess = false,
]) {
  final names = gradeSelection == null
      ? studyScreenSubjectNames
      : [
          ...subjectNamesForGradeSelection(gradeSelection),
          if (!gradeHasStreamOptions(gradeSelection)) 'SAT',
        ];
  return [
    for (final name in names)
      if (studySubjectByName(name) != null)
        resolveSubjectLock(
          studySubjectByName(name)!,
          gradeSelection: gradeSelection,
          fullAccess: fullAccess,
        ),
  ];
}

/// Freemium locks: Biology & Geography stay open; everything else locked until
/// [fullAccess]. CMS `locked` is ignored for this product rule.
StudySubject resolveSubjectLock(
  StudySubject subject, {
  String? gradeSelection,
  bool fullAccess = false,
}) {
  return subject.copyWith(
    isLocked: ContentAccess.isSubjectLocked(
      subject.name,
      fullAccess: fullAccess,
    ),
  );
}

/// Home subject grid uses the same freemium locks as Study.
List<StudySubject> homeSubjectsForScreen([
  String? gradeSelection,
  bool fullAccess = false,
]) {
  final names = gradeSelection == null
      ? lowerSecondarySubjectNames
      : subjectNamesForGradeSelection(gradeSelection);
  return [
    for (final name in names)
      if (studySubjectByName(name) != null)
        resolveSubjectLock(
          studySubjectByName(name)!,
          gradeSelection: gradeSelection,
          fullAccess: fullAccess,
        ),
  ];
}

StudySubject? studySubjectByName(String name) {
  for (final subject in studySubjects) {
    if (subject.name == name) return subject;
  }
  return null;
}

int topicCountForGrade(StudySubject subject, String gradeSelection) {
  final gradeIndex =
      grades.indexOf(gradeBase(gradeSelection));
  final offset = gradeIndex >= 0 ? gradeIndex * 2 : 0;
  return subject.topicCount + offset;
}

double progressForGrade(StudySubject subject, String gradeSelection) {
  return subjectStudyProgress(subject.name, gradeSelection);
}
