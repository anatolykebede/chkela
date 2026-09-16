import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Background layers — pure black base, former bgBase (#1C1C1C) for gray UI
  static const Color bgBase = Color(0xFF000000);
  static const Color bgSurface = Color(0xFF1C1C1C);
  static const Color bgElevated = Color(0xFF242424);
  static const Color bgOverlay = Color(0xFF2C2C2C);
  static const Color border = Color(0xFF3A3A3A);
  static const Color borderStrong = Color(0xFF4A4A4A);

  // Accent
  static const Color accent = Color(0xFF6C63FF);
  static const Color brandPurple = Color(0xFF6A4CFF);
  static const Color accentPress = Color(0xFF5A52E0);
  static const Color accentSoft = Color(0xFF2D2A5E);
  static const Color accentSubtle = Color(0xFF1A1840);
  static const Color accentText = Color(0xFFA89EFF);

  // Content type semantic colors
  static const Color teal = Color(0xFF00C896);
  static const Color tealSoft = Color(0xFF0A2E26);
  static const Color amber = Color(0xFFF5A623);
  static const Color amberSoft = Color(0xFF2E2000);
  static const Color info = Color(0xFF378ADD);
  static const Color infoSoft = Color(0xFF0A1E35);

  // Legacy aliases
  static const Color success = teal;
  static const Color successSoft = tealSoft;
  static const Color warning = amber;
  static const Color warningSoft = amberSoft;
  static const Color danger = Color(0xFFE25555);
  static const Color dangerSoft = Color(0xFF2E0A0A);

  /// High-engagement map action (Battle challenge).
  static const Color battleCoral = Color(0xFFFF5C39);
  static const Color onlineGreen = Color(0xFF4ADE80);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF999999);
  static const Color textMuted = Color(0xFF666666);

  // Community / social accents
  static const Color verified = Color(0xFF0095F6);
  static const Color fabPink = Color(0xFFFF0069);
  static const Color iconMuted = Color(0xFFB0B0B0);

  // Leaderboard medals
  static const Color gold = Color(0xFFFFD700);
  static const Color goldBg = Color(0xFF332B00);
  static const Color silver = Color(0xFFC0C0C0);
  static const Color bronze = Color(0xFFCD7F32);
  static const Color bronzeBg = Color(0xFF2E1A0A);
}
