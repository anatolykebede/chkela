import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/home_layout.dart';
import '../../core/theme/home_text_styles.dart';
import '../../data/map_activity.dart';
import '../../data/map_profile_store.dart';
import '../../data/map_students.dart';
import 'student_profile_helpers.dart';

class MapStudentMarker extends StatelessWidget {
  const MapStudentMarker({
    super.key,
    required this.student,
    required this.isSelected,
    required this.onTap,
  });

  final MapStudent student;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ringColor =
        student.isCurrentUser ? AppColors.teal : AppColors.accentText;

    return GestureDetector(
      onTap: onTap,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? ringColor : AppColors.borderStrong,
                  width: isSelected ? 2 : 1.5,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Center(
                    child: Text(
                      student.initials,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ringColor,
                      ),
                    ),
                  ),
                  if (student.isOnline)
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.teal,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.bgElevated,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isSelected ? ringColor : AppColors.bgElevated,
                border: Border.all(color: ringColor, width: 1.5),
                borderRadius: BorderRadius.circular(2),
              ),
              transform: Matrix4.rotationZ(0.785398),
            ),
          ],
        ),
      ),
    );
  }
}

class MapStudentPreviewSheet extends StatelessWidget {
  const MapStudentPreviewSheet({
    super.key,
    required this.student,
    required this.onViewProfile,
  });

  final MapStudent student;
  final VoidCallback onViewProfile;

  @override
  Widget build(BuildContext context) {
    final store = MapProfileStore.instance;
    final live = store.resolveStudent(student);
    final style = profileStyleFor(
      live,
      customTagline: live.isCurrentUser
          ? MapProfileStore.instance.myTagline
          : null,
    );
    final badges = profileBadgesFor(live).take(3).toList();
    final rank = mapStudentRegionRank(live);
    final mood = store.moodFor(live);
    final friendCount = store.friendsFor(live).length;
    final activity = store.activitiesFor(live).firstOrNull;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgOverlay,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: style.accent.withValues(alpha: 0.35),
          width: 0.5,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: style.accent.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (live.isCurrentUser)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '✦  THAT\'S YOU  ✦',
                    textAlign: TextAlign.center,
                    style: HomeTextStyles.badge.copyWith(
                      color: style.accent,
                      fontSize: 10,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PreviewAvatar(student: live, style: style),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          style.personaTitle.toUpperCase(),
                          style: HomeTextStyles.badge.copyWith(
                            color: style.accent,
                            fontSize: 9,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          live.name,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${live.gradeShort} · ${live.school}',
                          style: HomeTextStyles.bodySmall.copyWith(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _HeroPill(
                              icon: Icons.leaderboard_outlined,
                              label: '#$rank in region',
                              color: rank <= 3 ? AppColors.gold : style.accent,
                              background: rank <= 3
                                  ? AppColors.goldBg
                                  : style.accentSoft.withValues(alpha: 0.6),
                            ),
                            _HeroPill(
                              icon: Icons.mood_outlined,
                              label: '${mood.emoji} ${mood.label}',
                              color: style.accent,
                              background: style.accentSoft.withValues(alpha: 0.6),
                            ),
                            if (friendCount > 0)
                              _HeroPill(
                                icon: Icons.people_outline,
                                label: '$friendCount friends',
                                color: AppColors.textSecondary,
                                background: AppColors.bgElevated,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: style.accentSoft.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
                  border: Border.all(
                    color: style.accent.withValues(alpha: 0.22),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  style.highlight,
                  style: HomeTextStyles.bodySmall.copyWith(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (activity != null) ...[
                const SizedBox(height: 12),
                _PreviewActivityTeaser(activity: activity, accent: style.accent),
              ],
              if (badges.isNotEmpty) ...[
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < badges.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        _PreviewBadge(badge: badges[i]),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              GestureDetector(
                onTap: onViewProfile,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: style.accentSoft.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
                    border: Border.all(
                      color: style.accent.withValues(alpha: 0.4),
                      width: 0.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      live.isCurrentUser
                          ? 'Open your profile'
                          : 'View full profile',
                      style: HomeTextStyles.badge.copyWith(
                        color: style.accent,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewActivityTeaser extends StatelessWidget {
  const _PreviewActivityTeaser({
    required this.activity,
    required this.accent,
  });

  final MapActivityItem activity;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: activity.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(activity.icon, size: 17, color: activity.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LATEST ACTIVITY',
                  style: HomeTextStyles.sectionLabel.copyWith(fontSize: 9),
                ),
                const SizedBox(height: 3),
                Text(
                  activity.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HomeTextStyles.cardTitle.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            activity.timeLabel,
            style: HomeTextStyles.bodySmall.copyWith(
              fontSize: 10,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewAvatar extends StatelessWidget {
  const _PreviewAvatar({
    required this.student,
    required this.style,
  });

  final MapStudent student;
  final StudentProfileStyle style;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: style.accent.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
        ),
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: style.accentSoft,
            shape: BoxShape.circle,
            border: Border.all(
              color: style.accent.withValues(alpha: 0.45),
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  student.initials,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: style.accent,
                  ),
                ),
              ),
              if (student.isOnline)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.teal,
                      shape: BoxShape.circle,
                      border: Border.all(color: style.accentSoft, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: HomeTextStyles.badge.copyWith(color: color, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge({required this.badge});

  final ProfileBadge badge;

  @override
  Widget build(BuildContext context) {
    return ProfileBadgeChip(badge: badge, compact: true);
  }
}

class MapStudentAvatar extends StatelessWidget {
  const MapStudentAvatar({
    super.key,
    required this.student,
    this.size = 64,
  });

  final MapStudent student;
  final double size;

  @override
  Widget build(BuildContext context) => _Avatar(student: student, size: size);
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.student, required this.size});

  final MapStudent student;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color =
        student.isCurrentUser ? AppColors.teal : AppColors.accentText;
    final bg =
        student.isCurrentUser ? AppColors.tealSoft : AppColors.accentSoft;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              student.initials,
              style: GoogleFonts.inter(
                fontSize: size * 0.32,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          if (student.isOnline)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: size * 0.22,
                height: size * 0.22,
                decoration: BoxDecoration(
                  color: AppColors.teal,
                  shape: BoxShape.circle,
                  border: Border.all(color: bg, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
