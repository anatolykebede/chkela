import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../data/home_mock_data.dart';
import 'auth_provider.dart';
import 'auth_session_store.dart';
import 'onboarding_widgets.dart';

class GradeOnboardingScreen extends ConsumerStatefulWidget {
  const GradeOnboardingScreen({super.key});

  @override
  ConsumerState<GradeOnboardingScreen> createState() =>
      _GradeOnboardingScreenState();
}

class _GradeOnboardingScreenState extends ConsumerState<GradeOnboardingScreen> {
  String? _selected;
  final _inviteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = ref.read(authProvider).grade;
    _hydrateInvite();
  }

  Future<void> _hydrateInvite() async {
    final pending = await AuthSessionStore.loadPendingReferralCode();
    if (!mounted || pending == null) return;
    _inviteController.text = pending;
  }

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final grade = _selected;
    if (grade == null) return;
    HapticFeedback.selectionClick();
    await AuthSessionStore.savePendingReferralCode(_inviteController.text);
    await ref.read(authProvider.notifier).setGrade(grade);
    ref.read(selectedGradeProvider.notifier).state = grade;
    if (!mounted) return;
    context.push('/onboarding/birthdate');
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _selected != null;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingProgress(step: 2, total: 4),
            const SizedBox(height: 36),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'WHAT\'S YOUR GRADE?',
                textAlign: TextAlign.center,
                style: onboardingTitleStyle().copyWith(fontSize: 30),
              ),
            ),
            const SizedBox(height: 28),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                children: [
                  for (var i = 0; i < selectableGrades.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _GradeOption(
                      label: selectableGrades[i],
                      selected: _selected == selectableGrades[i],
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selected = selectableGrades[i]);
                      },
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text(
                    'Have an invite code?',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _inviteController,
                    textCapitalization: TextCapitalization.characters,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: 1,
                    ),
                    decoration: InputDecoration(
                      hintText: 'CHK-XXXXXX',
                      hintStyle: GoogleFonts.inter(
                        color: AppColors.textMuted,
                        letterSpacing: 0,
                      ),
                      filled: true,
                      fillColor: AppColors.bgElevated,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                          width: 0.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                          width: 0.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.accent.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Optional · 50 CP + 10% off purchases',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: OnboardingPillButton(
                label: 'Continue',
                emphasized: true,
                enabled: canContinue,
                onPressed: _continue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradeOption extends StatelessWidget {
  const _GradeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? OnboardingColors.accentDeep.withValues(alpha: 0.9)
                : AppColors.bgElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? OnboardingColors.accent.withValues(alpha: 0.55)
                  : AppColors.border,
              width: selected ? 1 : 0.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? OnboardingColors.accentLabel
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                size: 22,
                color: selected
                    ? OnboardingColors.accent
                    : AppColors.textMuted.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
