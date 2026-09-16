import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/home_text_styles.dart';
import '../../data/points_badges.dart';

class ProfileBadge {
  const ProfileBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    this.iconOnly = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  /// Rank medals render as icon-only; milestone chips keep text.
  final bool iconOnly;
}

(Color color, Color background, IconData icon) pointsRankStyle(
  PointsRankTier tier,
) {
  switch (tier) {
    case PointsRankTier.rookie:
      return (
        AppColors.accentText,
        AppColors.accentSoft,
        Icons.school_rounded,
      );
    case PointsRankTier.bronze:
      return (AppColors.bronze, AppColors.bronzeBg, Icons.military_tech_rounded);
    case PointsRankTier.silver:
      return (
        AppColors.silver,
        AppColors.accentSoft,
        Icons.military_tech_rounded,
      );
    case PointsRankTier.gold:
      return (AppColors.gold, AppColors.goldBg, Icons.emoji_events_rounded);
    case PointsRankTier.platinum:
      return (
        AppColors.info,
        AppColors.infoSoft,
        Icons.workspace_premium_rounded,
      );
    case PointsRankTier.diamond:
      return (
        AppColors.teal,
        AppColors.tealSoft,
        Icons.diamond_rounded,
      );
  }
}

ProfileBadge pointsRankBadge(int points) {
  final info = pointsRankFor(points);
  final style = pointsRankStyle(info.tier);
  return ProfileBadge(
    icon: style.$3,
    label: info.label,
    color: style.$1,
    background: style.$2,
    iconOnly: true,
  );
}

List<ProfileBadge> pointsMilestoneProfileBadges(int points) {
  return [
    for (final m in unlockedPointsMilestones(points))
      ProfileBadge(
        icon: Icons.star_rounded,
        label: m.label,
        color: AppColors.amber,
        background: AppColors.amberSoft,
      ),
  ];
}

List<ProfileBadge> pointsAchievementBadges(int points) {
  return [
    pointsRankBadge(points),
    ...pointsMilestoneProfileBadges(points),
  ];
}

/// Circular rank medal (icon only — no Silver / Gold text).
class PointsTierPill extends StatelessWidget {
  const PointsTierPill({
    super.key,
    required this.points,
    this.compact = true,
  });

  final int points;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final info = pointsRankFor(points);
    final style = pointsRankStyle(info.tier);
    final size = compact ? 22.0 : 28.0;
    final iconSize = compact ? 13.0 : 16.0;

    return Tooltip(
      message: info.label,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: style.$2,
          border: Border.all(
            color: style.$1.withValues(alpha: 0.55),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: style.$1.withValues(alpha: 0.28),
              blurRadius: compact ? 4 : 6,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Icon(style.$3, size: iconSize, color: style.$1),
      ),
    );
  }
}

class ProfileBadgeChip extends StatelessWidget {
  const ProfileBadgeChip({
    super.key,
    required this.badge,
    this.compact = false,
  });

  final ProfileBadge badge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (badge.iconOnly) {
      final size = compact ? 22.0 : 28.0;
      final iconSize = compact ? 13.0 : 16.0;
      return Tooltip(
        message: badge.label,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: badge.background,
            border: Border.all(
              color: badge.color.withValues(alpha: 0.55),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: badge.color.withValues(alpha: 0.28),
                blurRadius: compact ? 4 : 6,
              ),
            ],
          ),
          child: Icon(badge.icon, size: iconSize, color: badge.color),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: badge.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: badge.color.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badge.icon, size: compact ? 12 : 16, color: badge.color),
          SizedBox(width: compact ? 4 : 6),
          Text(
            badge.label,
            style: HomeTextStyles.badge.copyWith(
              color: badge.color,
              fontSize: compact ? 10 : 11,
            ),
          ),
        ],
      ),
    );
  }
}
