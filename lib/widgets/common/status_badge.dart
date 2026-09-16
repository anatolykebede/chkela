import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';

enum BadgeVariant { accent, success, warning, danger, info }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.accent,
    this.isChip = false,
  });

  final String label;
  final BadgeVariant variant;
  final bool isChip;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colorsForVariant(variant);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(
          isChip ? AppRadius.chip : AppRadius.badge,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.overline.copyWith(color: fg),
      ),
    );
  }

  (Color, Color) _colorsForVariant(BadgeVariant variant) {
    switch (variant) {
      case BadgeVariant.accent:
        return (AppColors.accentSoft, AppColors.accentText);
      case BadgeVariant.success:
        return (AppColors.successSoft, AppColors.success);
      case BadgeVariant.warning:
        return (AppColors.warningSoft, AppColors.warning);
      case BadgeVariant.danger:
        return (AppColors.dangerSoft, AppColors.danger);
      case BadgeVariant.info:
        return (AppColors.infoSoft, AppColors.info);
    }
  }
}
