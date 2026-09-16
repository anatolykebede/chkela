import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';

/// Small FREE pill used on preview subjects / lessons.
class FreeContentTag extends StatelessWidget {
  const FreeContentTag({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.teal.withValues(alpha: 0.55),
          width: 0.5,
        ),
      ),
      child: Text(
        'FREE',
        style: GoogleFonts.inter(
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: AppColors.teal,
          height: 1.1,
        ),
      ),
    );
  }
}
