import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';

/// Accent used on post-OTP onboarding (Chkela purple).
abstract final class OnboardingColors {
  static const accent = AppColors.accent;
  static const accentDeep = AppColors.accentSoft;
  static const accentMuted = AppColors.accentSubtle;
  static const accentLabel = AppColors.accentText;
  static const track = Color(0xFF2A2A2A);
  static const buttonDisabled = Color(0xFF1A1A1A);
  static const buttonDisabledText = Color(0xFF666666);
}

class OnboardingProgress extends StatelessWidget {
  const OnboardingProgress({super.key, required this.step, this.total = 3});

  /// 1-based step index.
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: List.generate(total, (i) {
          final filled = i < step;
          return Expanded(
            child: Container(
              height: 3,
              margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
              decoration: BoxDecoration(
                color: filled ? OnboardingColors.accent : OnboardingColors.track,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

TextStyle onboardingTitleStyle() => GoogleFonts.inter(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
      letterSpacing: -0.8,
      height: 1.05,
    );

TextStyle onboardingSubtitleStyle() => GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
      height: 1.45,
    );

class OnboardingPillButton extends StatelessWidget {
  const OnboardingPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.emphasized = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  /// Soft purple fill + accent label (Continue on birthdate).
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final bg = !enabled
        ? OnboardingColors.buttonDisabled
        : emphasized
            ? OnboardingColors.accentMuted
            : OnboardingColors.accent;
    final fg = !enabled
        ? OnboardingColors.buttonDisabledText
        : emphasized
            ? OnboardingColors.accentLabel
            : Colors.white;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(28),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
