import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import 'auth_provider.dart';
import 'onboarding_widgets.dart';

class NameOnboardingScreen extends ConsumerStatefulWidget {
  const NameOnboardingScreen({super.key});

  @override
  ConsumerState<NameOnboardingScreen> createState() =>
      _NameOnboardingScreenState();
}

class _NameOnboardingScreenState extends ConsumerState<NameOnboardingScreen> {
  late final TextEditingController _controller;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(authProvider).fullName ?? '',
    );
    _controller.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _trimmed => _controller.text.trim().replaceAll(RegExp(r'\s+'), ' ');

  bool get _canContinue => _trimmed.length >= 2;

  Future<void> _continue() async {
    if (!_canContinue) return;
    HapticFeedback.selectionClick();
    await ref.read(authProvider.notifier).setFullName(_trimmed);
    if (!mounted) return;
    context.push('/onboarding/grade');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingProgress(step: 1, total: 4),
            const SizedBox(height: 36),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'WHAT\'S YOUR FULL NAME?',
                textAlign: TextAlign.center,
                style: onboardingTitleStyle().copyWith(fontSize: 28),
              ),
            ),
            const SizedBox(height: 36),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _continue(),
                maxLength: 80,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                cursorColor: OnboardingColors.accentLabel,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'e.g. Selam Tadesse',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor: AppColors.bgElevated,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: OnboardingColors.accent,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
              child: OnboardingPillButton(
                label: 'Continue',
                enabled: _canContinue,
                onPressed: _continue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
