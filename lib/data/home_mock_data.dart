import 'package:flutter/material.dart';

import '../core/models/content_type.dart';
import '../core/theme/app_colors.dart';

const studentName = 'Selam Tadesse';
const studentInitials = 'ST';
/// Fallback when the profile grade is not loaded yet.
const enrolledGrade = 'Grade 9';
const streakCount = 14;

class HomeAnnouncement {
  const HomeAnnouncement({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.icon,
    required this.accent,
    required this.accentSoft,
  });

  final String tag;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final IconData icon;
  final Color accent;
  final Color accentSoft;
}

/// Push-style promo shown above subjects on Home (challenges, events, etc.).
const homeAnnouncement = HomeAnnouncement(
  tag: 'PATH',
  title: 'The Path',
  subtitle: 'Connected levels · clear the trail',
  ctaLabel: 'Play',
  icon: Icons.route_rounded,
  accent: AppColors.accent,
  accentSoft: AppColors.accentSoft,
);

const topicsStudied = 42;
const avgScore = '87%';

const grades = ['Grade 9', 'Grade 10', 'Grade 11', 'Grade 12'];

/// Home / Learn grade picker values. Grades 11–12 require a stream.
const selectableGrades = [
  'Grade 9',
  'Grade 10',
  'Grade 11 · Natural',
  'Grade 11 · Social',
  'Grade 12 · Natural',
  'Grade 12 · Social',
];

const gradeStreams = ['Natural', 'Social'];

/// Strips stream suffix: `Grade 11 · Natural` → `Grade 11`.
String gradeBase(String selection) {
  if (selection.startsWith('Grade 11')) return 'Grade 11';
  if (selection.startsWith('Grade 12')) return 'Grade 12';
  return selection;
}

/// `Natural` / `Social` for grades 11–12, otherwise null.
String? gradeStream(String selection) {
  if (selection.endsWith('Natural')) return 'Natural';
  if (selection.endsWith('Social')) return 'Social';
  return null;
}

bool gradeHasStreamOptions(String gradeOrSelection) {
  final base = gradeBase(gradeOrSelection);
  return base == 'Grade 11' || base == 'Grade 12';
}

String gradeWithStream(String baseGrade, String stream) =>
    '$baseGrade · $stream';

/// Base grades (9–12) with [preferred] first when it matches a known grade.
List<String> gradesPreferring(String? preferred) {
  final prefer = preferred == null || preferred.trim().isEmpty
      ? null
      : gradeBase(preferred);
  if (prefer == null || !grades.contains(prefer)) {
    return List<String>.from(grades);
  }
  return [
    prefer,
    for (final g in grades)
      if (g != prefer) g,
  ];
}

/// Full selectable labels (with streams) preferring the registered selection.
List<String> selectableGradesPreferring(String? preferred) {
  if (preferred == null || preferred.trim().isEmpty) {
    return List<String>.from(selectableGrades);
  }
  final prefer = preferred.trim();
  final preferBase = gradeBase(prefer);
  final exact = <String>[];
  final sameBase = <String>[];
  final rest = <String>[];
  for (final g in selectableGrades) {
    if (g == prefer) {
      exact.add(g);
    } else if (gradeBase(g) == preferBase) {
      sameBase.add(g);
    } else {
      rest.add(g);
    }
  }
  // If profile stored "Grade 11" without stream, pin Natural first then Social.
  if (exact.isEmpty && sameBase.isNotEmpty) {
    return [...sameBase, ...rest];
  }
  return [...exact, ...sameBase, ...rest];
}

/// Natural / Social order with the registered stream first when relevant.
List<String> gradeStreamsPreferring(
  String? preferredSelection,
  String baseGrade,
) {
  final stream = preferredSelection != null &&
          gradeBase(preferredSelection) == baseGrade
      ? gradeStream(preferredSelection)
      : null;
  if (stream == null || !gradeStreams.contains(stream)) {
    return List<String>.from(gradeStreams);
  }
  return [
    stream,
    for (final s in gradeStreams)
      if (s != stream) s,
  ];
}

class HomeContentItem {
  const HomeContentItem({
    required this.title,
    required this.subtitle,
    required this.type,
    required this.badgeLabel,
    this.progress,
  });

  final String title;
  final String subtitle;
  final ContentType type;
  final String badgeLabel;
  final double? progress;
}

final continueLearningByGrade = <String, List<HomeContentItem>>{
  'Grade 9': [
    const HomeContentItem(
      title: 'Introduction to Algebra',
      subtitle: 'Chapter 2 · 8 pages',
      type: ContentType.notes,
      badgeLabel: 'Note',
      progress: 0.35,
    ),
    const HomeContentItem(
      title: 'Cell Biology Basics',
      subtitle: 'Flashcards · 12 cards',
      type: ContentType.flashcard,
      badgeLabel: 'Cards',
      progress: 0.6,
    ),
    const HomeContentItem(
      title: 'Grade 9 Math Exam',
      subtitle: '30 questions',
      type: ContentType.exam,
      badgeLabel: 'Exam',
    ),
  ],
  'Grade 10': [
    const HomeContentItem(
      title: 'Quadratic Equations',
      subtitle: 'Chapter 4 · 12 pages',
      type: ContentType.notes,
      badgeLabel: 'Note',
      progress: 0.72,
    ),
    const HomeContentItem(
      title: 'Newton\'s Laws of Motion',
      subtitle: 'Flashcards · 15 cards',
      type: ContentType.flashcard,
      badgeLabel: 'Cards',
      progress: 0.45,
    ),
    const HomeContentItem(
      title: '2024 Chemistry Exam',
      subtitle: '40 questions',
      type: ContentType.exam,
      badgeLabel: 'Exam',
    ),
  ],
  'Grade 11': [
    const HomeContentItem(
      title: 'Organic Chemistry',
      subtitle: 'Chapter 7 · 20 pages',
      type: ContentType.notes,
      badgeLabel: 'Note',
      progress: 0.2,
    ),
    const HomeContentItem(
      title: 'Wave Optics',
      subtitle: 'Flashcards · 18 cards',
      type: ContentType.flashcard,
      badgeLabel: 'Cards',
    ),
    const HomeContentItem(
      title: 'AI Study Session',
      subtitle: 'Calculus review',
      type: ContentType.ai,
      badgeLabel: 'AI',
    ),
  ],
  'Grade 12': [
    const HomeContentItem(
      title: 'National Exam Prep',
      subtitle: 'Chapter 12 · 35 pages',
      type: ContentType.notes,
      badgeLabel: 'Note',
      progress: 0.55,
    ),
    const HomeContentItem(
      title: 'Exam Strategy Guide',
      subtitle: 'Flashcards · 40 cards',
      type: ContentType.flashcard,
      badgeLabel: 'Cards',
    ),
    const HomeContentItem(
      title: '2025 Mock Exam',
      subtitle: '50 questions',
      type: ContentType.exam,
      badgeLabel: 'Exam',
    ),
  ],
};

extension HomeContentTypeStyle on ContentType {
  IconData get homeIcon {
    switch (this) {
      case ContentType.notes:
        return Icons.menu_book_outlined;
      case ContentType.flashcard:
        return Icons.style_outlined;
      case ContentType.exam:
        return Icons.description_outlined;
      case ContentType.ai:
        return Icons.auto_awesome_outlined;
    }
  }

  Color get homeIconBg {
    switch (this) {
      case ContentType.notes:
        return AppColors.accentSoft;
      case ContentType.flashcard:
        return AppColors.tealSoft;
      case ContentType.exam:
        return AppColors.amberSoft;
      case ContentType.ai:
        return AppColors.infoSoft;
    }
  }

  Color get homeIconColor {
    switch (this) {
      case ContentType.notes:
        return AppColors.accentText;
      case ContentType.flashcard:
        return AppColors.teal;
      case ContentType.exam:
        return AppColors.amber;
      case ContentType.ai:
        return AppColors.info;
    }
  }
}
