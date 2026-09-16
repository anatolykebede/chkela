import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/models/content_item.dart';
import '../../core/models/content_type.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../common/progress_bar.dart';

class ContentCard extends StatelessWidget {
  const ContentCard({
    super.key,
    required this.item,
    this.showProgress = false,
    this.onTap,
  });

  final ContentItem item;
  final bool showProgress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            _ContentIcon(type: item.type),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: AppTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(item.subtitle, style: AppTextStyles.bodySmall),
                  if (showProgress && item.progress != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppProgressBar(progress: item.progress!),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              item.isBookmarked ? LucideIcons.bookmark : LucideIcons.chevronRight,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentIcon extends StatelessWidget {
  const _ContentIcon({required this.type});

  final ContentType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: type.backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Icon(
        type.icon,
        color: type.iconColor,
        size: 20,
      ),
    );
  }
}
