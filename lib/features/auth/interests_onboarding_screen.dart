import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import 'auth_provider.dart';
import 'onboarding_widgets.dart';

class _Interest {
  const _Interest(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}

const _interests = [
  _Interest('education', 'Education', Icons.school_outlined),
  _Interest('fashion', 'Fashion', Icons.checkroom_outlined),
  _Interest('fitness', 'Fitness', Icons.fitness_center_outlined),
  _Interest('food', 'Food', Icons.restaurant_outlined),
  _Interest('gaming', 'Gaming', Icons.sports_esports_outlined),
  _Interest('music', 'Music', Icons.music_note_outlined),
  _Interest('news', 'News', Icons.newspaper_outlined),
  _Interest('sports', 'Sports', Icons.sports_basketball_outlined),
  _Interest('technology', 'Technology', Icons.laptop_mac_outlined),
  _Interest('travel', 'Travel', Icons.flight_outlined),
];

class InterestsOnboardingScreen extends ConsumerStatefulWidget {
  const InterestsOnboardingScreen({super.key});

  @override
  ConsumerState<InterestsOnboardingScreen> createState() =>
      _InterestsOnboardingScreenState();
}

class _InterestsOnboardingScreenState
    extends ConsumerState<InterestsOnboardingScreen> {
  final Set<String> _selected = {};

  static const _min = 1;

  void _toggle(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  Future<void> _finish() async {
    if (_selected.length < _min) return;
    HapticFeedback.lightImpact();
    final grade = ref.read(authProvider).grade;
    final inviteReward =
        await ref.read(authProvider.notifier).completeOnboarding(Set.of(_selected));
    if (!mounted) return;
    if (inviteReward > 0) {
      ref.read(referralUnlockEpochProvider.notifier).state++;
    }
    if (grade != null) {
      ref.read(selectedGradeProvider.notifier).state = grade;
    }
    context.go('/home');
    if (inviteReward > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite applied — 50 CP + 10% off purchases'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _selected.length >= _min;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingProgress(step: 4, total: 4),
            const SizedBox(height: 36),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'CHOOSE YOUR INTERESTS',
                textAlign: TextAlign.center,
                style: onboardingTitleStyle().copyWith(fontSize: 30),
              ),
            ),
            const SizedBox(height: 36),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Wrap(
                  spacing: 28,
                  runSpacing: 22,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final interest in _interests)
                      _InterestChip(
                        label: interest.label,
                        icon: interest.icon,
                        selected: _selected.contains(interest.id),
                        onTap: () => _toggle(interest.id),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Text(
                '${_selected.length} of $_min minimum selected',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: OnboardingPillButton(
                label: 'Get Started',
                enabled: canContinue,
                onPressed: _finish,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? OnboardingColors.accent : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
