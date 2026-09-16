import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class HomeTextStyles {
  HomeTextStyles._();

  static final displayName = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );

  static final sectionLabel = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.06,
    color: AppColors.textMuted,
  );

  static final cardTitle = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static final cardSub = GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static final statValue = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static final streakNum = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.amber,
  );

  static final bodySmall = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static final badge = GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w600,
  );

  static final navLabel = GoogleFonts.inter(
    fontSize: 9,
    fontWeight: FontWeight.w500,
  );

  static final seeAll = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.accentText,
  );

  static final points = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.accentText,
  );

  static final rankNum = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w700,
  );

  static final avatarInitials = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );

  static final pillLabel = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  static final avatarLarge = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.accentText,
  );
}
