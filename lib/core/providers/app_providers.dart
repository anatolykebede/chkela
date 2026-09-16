import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/battle_setup_data.dart';
import '../../data/home_mock_data.dart';
import '../../features/referral/referral_unlock_store.dart';
import '../../features/subscription/subscription_access_store.dart';
import '../../widgets/navigation/app_bottom_nav.dart';

class GuiderAnchor {
  const GuiderAnchor({required this.x, required this.y});

  final double x;
  final double y;

  static const squadTabIndex = 4;
  static const tabCount = 5;
  static const navHorizontalMargin = AppBottomNav.horizontalMargin;
  static const navBottomMargin = AppBottomNav.bottomMargin;
  static const navHeight = AppBottomNav.barHeight;
  static const gapAboveNav = 10.0;
  static const edgeInset = 8.0;

  static Rect draggableBounds(
    Size size,
    EdgeInsets padding, {
    double buttonSize = 52,
  }) {
    return Rect.fromLTRB(
      padding.left + edgeInset,
      padding.top + edgeInset,
      size.width - padding.right - buttonSize - edgeInset,
      size.height - padding.bottom - buttonSize - edgeInset,
    );
  }

  /// Default launch position — centered above the Squad bottom-nav tab.
  static GuiderAnchor aboveSquadNav(
    Size size,
    EdgeInsets padding, {
    double buttonSize = 52,
  }) {
    final navWidth = size.width - navHorizontalMargin * 2;
    final squadCenterX =
        navHorizontalMargin + (squadTabIndex + 0.5) / tabCount * navWidth;
    final buttonLeft = squadCenterX - buttonSize / 2;

    final navTopY =
        size.height - padding.bottom - navBottomMargin - navHeight;
    final buttonTop = navTopY - gapAboveNav - buttonSize;

    final bounds = draggableBounds(size, padding, buttonSize: buttonSize);
    return GuiderAnchor(
      x: ((buttonLeft - bounds.left) / bounds.width).clamp(0.0, 1.0),
      y: ((buttonTop - bounds.top) / bounds.height).clamp(0.0, 1.0),
    );
  }
}

final selectedSubjectProvider = StateProvider<String>((ref) => 'All');

final selectedGradeProvider =
    StateProvider<String>((ref) => enrolledGrade);

final pendingStudySubjectProvider = StateProvider<String?>((ref) => null);

final pendingBattleLaunchProvider = StateProvider<BattleSetup?>((ref) => null);

final guiderVisibleProvider = StateProvider<bool>((ref) => true);

/// Screens that must not show the floating AI guider (e.g. subscription flow).
final guiderSuppressCountProvider = StateProvider<int>((ref) => 0);

/// Bumped after referral unlock is granted so study screens refresh locks.
final referralUnlockEpochProvider = StateProvider<int>((ref) => 0);

/// Bumped after subscription becomes active so locks / FREE chrome refresh.
final subscriptionAccessEpochProvider = StateProvider<int>((ref) => 0);

/// Whether the local referral free-period is currently active.
final referralUnlockActiveProvider = FutureProvider<bool>((ref) async {
  ref.watch(referralUnlockEpochProvider);
  return ReferralUnlockStore.isActive();
});

/// Whether the user has any active paid subscription (any grade).
final subscriptionActiveProvider = FutureProvider<bool>((ref) async {
  ref.watch(subscriptionAccessEpochProvider);
  return SubscriptionAccessStore.syncFromServer();
});

/// Full content access for the currently selected grade.
final fullContentAccessProvider = FutureProvider<bool>((ref) async {
  ref.watch(subscriptionAccessEpochProvider);
  final grade = ref.watch(selectedGradeProvider);
  if (await ref.watch(referralUnlockActiveProvider.future)) return true;
  await SubscriptionAccessStore.syncFromServer();
  return SubscriptionAccessStore.hasAccessForGrade(grade);
});

/// Adjust guider suppression outside widget build/dispose lifecycles.
abstract final class GuiderVisibility {
  static void suppress(WidgetRef ref) {
    ref.read(guiderSuppressCountProvider.notifier).update((count) => count + 1);
  }

  static void unsuppress(WidgetRef ref) {
    ref.read(guiderSuppressCountProvider.notifier).update(
          (count) => count > 0 ? count - 1 : 0,
        );
  }

  static void suppressAfterBuild(
    WidgetRef ref,
    bool Function() isMounted,
    VoidCallback onSuppressed,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isMounted()) return;
      suppress(ref);
      onSuppressed();
    });
  }

  static void unsuppressSoon(WidgetRef ref) {
    Future.microtask(() => unsuppress(ref));
  }
}

final aiSheetOpenProvider = StateProvider<bool>((ref) => false);

final guiderAnchorProvider = StateProvider<GuiderAnchor>((ref) {
  return const GuiderAnchor(x: 0.92, y: 0.88);
});
