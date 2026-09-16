import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/home_layout.dart';
import '../../core/theme/home_text_styles.dart';
import '../../data/home_mock_data.dart';
import '../../data/study_subjects.dart';
import '../../data/subscription_data.dart';
import 'subscription_flow.dart';
import 'subscription_prefs.dart';

/// Soft, dismissible unlock prompt on Home (not a hard paywall).
class HomeUnlockNudge extends ConsumerStatefulWidget {
  const HomeUnlockNudge({super.key});

  @override
  ConsumerState<HomeUnlockNudge> createState() => _HomeUnlockNudgeState();
}

class _HomeUnlockNudgeState extends ConsumerState<HomeUnlockNudge> {
  bool? _visible;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final show = await SubscriptionPrefs.shouldShowHomeNudge();
    if (!mounted) return;
    setState(() => _visible = show);
  }

  Future<void> _dismiss() async {
    HapticFeedback.selectionClick();
    await SubscriptionPrefs.dismissHomeNudge();
    if (!mounted) return;
    setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_visible != true) return const SizedBox.shrink();

    final activeGrade = ref.watch(selectedGradeProvider);
    final fullAccess =
        ref.watch(fullContentAccessProvider).valueOrNull ?? false;
    final subjects = homeSubjectsForScreen(activeGrade, fullAccess);
    final referralUnlocked =
        ref.watch(referralUnlockActiveProvider).valueOrNull ?? false;
    if (fullAccess || referralUnlocked) return const SizedBox.shrink();

    final hasLocked = subjects.any((s) => s.isLocked);
    if (!hasLocked) return const SizedBox.shrink();

    final gradeLabel = gradeBase(activeGrade);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            openSubscriptionFlow(context);
          },
          borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              color: AppColors.accentSoft.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.35),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.lock_open_rounded,
                    color: AppColors.accentText,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unlock $gradeLabel',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'From ${formatPrice(gradeMonthlyPrice)}/mo · notes, exams & more',
                        style: HomeTextStyles.cardSub.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _dismiss,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textMuted.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
