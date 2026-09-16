import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/map_profile_store.dart';
import '../../data/map_students.dart';
import '../../widgets/common/points_badge_chips.dart';

export '../../widgets/common/points_badge_chips.dart'
    show ProfileBadge, ProfileBadgeChip;

class StudentProfileStyle {
  const StudentProfileStyle({
    required this.accent,
    required this.accentSoft,
    required this.personaTitle,
    required this.highlight,
  });

  final Color accent;
  final Color accentSoft;
  final String personaTitle;
  final String highlight;
}

int mapStudentRegionRank(MapStudent student) {
  final pool = MapProfileStore.instance.students;
  final sorted = [...pool]..sort((a, b) => b.points.compareTo(a.points));
  final index = sorted.indexWhere((s) => s.id == student.id);
  return index < 0 ? pool.length : index + 1;
}

StudentProfileStyle profileStyleFor(
  MapStudent student, {
  String? customTagline,
}) {
  final rank = mapStudentRegionRank(student);
  final accent = student.isCurrentUser ? AppColors.teal : AppColors.accentText;
  final accentSoft =
      student.isCurrentUser ? AppColors.tealSoft : AppColors.accentSoft;

  final personaTitle = () {
    if (student.isCurrentUser) return 'Your journey';
    if (student.streak >= 21) return 'Streak legend';
    if (student.avgScore >= 92) return 'High achiever';
    if (rank == 1) return 'Region leader';
    if (rank <= 3) return 'Top scholar';
    if (student.streak >= 14) return 'Consistent learner';
    return 'Rising student';
  }();

  final highlight = () {
    if (customTagline != null && customTagline.trim().isNotEmpty) {
      return customTagline.trim();
    }
    if (student.isCurrentUser) {
      return 'Add a tagline in Edit profile so classmates know what you are about.';
    }
    if (rank == 1) {
      return '${student.name.split(' ').first} leads the region. ${student.streak} days of showing up and counting.';
    }
    if (student.streak >= 21) {
      return '${student.streak}-day streak. That kind of discipline is rare.';
    }
    if (student.avgScore >= 90) {
      return 'Averaging ${student.avgScore}%. Excellence built one exam at a time.';
    }
    final focus = student.subjects.isNotEmpty
        ? student.subjects.first
        : student.grade;
    return 'Studying $focus and more. Always room to grow, always moving forward.';
  }();

  return StudentProfileStyle(
    accent: accent,
    accentSoft: accentSoft,
    personaTitle: personaTitle,
    highlight: highlight,
  );
}

List<ProfileBadge> profileBadgesFor(MapStudent student) {
  final rank = mapStudentRegionRank(student);
  final badges = <ProfileBadge>[];

  if (student.isCurrentUser) {
    badges.add(
      const ProfileBadge(
        icon: Icons.star_outline,
        label: 'That\'s you',
        color: AppColors.teal,
        background: AppColors.tealSoft,
      ),
    );
  }

  // Pts tier first among achievements, then unlocked milestones.
  badges.add(pointsRankBadge(student.points));
  badges.addAll(pointsMilestoneProfileBadges(student.points));

  if (rank == 1) {
    badges.add(
      const ProfileBadge(
        icon: Icons.emoji_events_outlined,
        label: '#1 Region',
        color: AppColors.gold,
        background: AppColors.goldBg,
      ),
    );
  } else if (rank <= 3) {
    badges.add(
      ProfileBadge(
        icon: Icons.military_tech_outlined,
        label: 'Top $rank',
        color: rank == 2 ? AppColors.silver : AppColors.bronze,
        background: rank == 2 ? AppColors.accentSoft : AppColors.bronzeBg,
      ),
    );
  }

  if (student.streak >= 14) {
    badges.add(
      ProfileBadge(
        icon: Icons.local_fire_department_outlined,
        label: '${student.streak}d streak',
        color: AppColors.teal,
        background: AppColors.tealSoft,
      ),
    );
  }

  if (student.avgScore >= 90) {
    badges.add(
      ProfileBadge(
        icon: Icons.auto_awesome_outlined,
        label: '${student.avgScore}% avg',
        color: AppColors.amber,
        background: AppColors.amberSoft,
      ),
    );
  }

  if (student.isOnline) {
    badges.add(
      const ProfileBadge(
        icon: Icons.circle,
        label: 'Online now',
        color: AppColors.teal,
        background: AppColors.tealSoft,
      ),
    );
  }

  return badges;
}

IconData subjectIcon(String subject) {
  switch (subject) {
    case 'Mathematics':
      return Icons.calculate_outlined;
    case 'Physics':
      return Icons.bolt_outlined;
    case 'Chemistry':
      return Icons.science_outlined;
    case 'Biology':
      return Icons.biotech_outlined;
    case 'English':
      return Icons.menu_book_outlined;
    default:
      return Icons.book_outlined;
  }
}

Color subjectColor(String subject) {
  switch (subject) {
    case 'Mathematics':
      return AppColors.accentText;
    case 'Physics':
      return AppColors.info;
    case 'Chemistry':
      return AppColors.amber;
    case 'Biology':
      return AppColors.teal;
    case 'English':
      return AppColors.silver;
    default:
      return AppColors.textSecondary;
  }
}

Color subjectBackground(String subject) {
  switch (subject) {
    case 'Mathematics':
      return AppColors.accentSoft;
    case 'Physics':
      return AppColors.infoSoft;
    case 'Chemistry':
      return AppColors.amberSoft;
    case 'Biology':
      return AppColors.tealSoft;
    case 'English':
      return AppColors.bgSurface;
    default:
      return AppColors.bgSurface;
  }
}
