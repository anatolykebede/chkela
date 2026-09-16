import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/home_text_styles.dart';
import '../../data/leaderboard_data.dart';
import '../common/points_badge_chips.dart';

class LeaderboardRow extends StatelessWidget {
  const LeaderboardRow({
    super.key,
    required this.entry,
    required this.isLast,
    required this.onTap,
  });

  final LeaderboardEntry entry;
  final bool isLast;
  final VoidCallback onTap;

  Color get _rankColor {
    switch (entry.rank) {
      case 1:
        return AppColors.gold;
      case 2:
        return AppColors.silver;
      case 3:
        return AppColors.bronze;
      default:
        return AppColors.textMuted;
    }
  }

  (Color bg, Color fg) get _avatarColors {
    switch (entry.rank) {
      case 1:
        return (AppColors.goldBg, AppColors.gold);
      case 2:
        return (AppColors.accentSoft, AppColors.accentText);
      case 3:
        return (AppColors.bronzeBg, AppColors.bronze);
      default:
        return (AppColors.tealSoft, AppColors.teal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _avatarColors;
    final showMedal = entry.rank <= 3;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: entry.isCurrentUser
              ? AppColors.accentSoft.withValues(alpha: 0.3)
              : null,
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: AppColors.border, width: 0.5),
                ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: Text(
                '${entry.rank}',
                style: HomeTextStyles.rankNum.copyWith(color: _rankColor),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: avatar.$1,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  entry.initials,
                  style: HomeTextStyles.avatarInitials.copyWith(
                    color: avatar.$2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.name, style: HomeTextStyles.cardTitle),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.grade,
                          style: HomeTextStyles.cardSub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      PointsTierPill(points: entry.points),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '${formatLeaderboardPoints(entry.points)} pts',
              style: HomeTextStyles.points,
            ),
            if (showMedal) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.emoji_events_rounded,
                size: 16,
                color: _rankColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
