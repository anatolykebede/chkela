import 'package:flutter/material.dart';

import '../../core/router/app_router.dart';
import 'subscription_prefs.dart';
import 'subscription_screen.dart';
import 'subscription_walkthrough_screen.dart';

/// Opens pricing — walkthrough once, then straight to plans.
Future<void> openSubscriptionFlow(BuildContext context) async {
  final navContext = rootNavigatorKey.currentContext ?? context;
  final seen = await SubscriptionPrefs.hasSeenWalkthrough();
  if (!navContext.mounted) return;

  if (seen) {
    openSubscriptionPlans(navContext);
    return;
  }

  await SubscriptionPrefs.markWalkthroughSeen();
  if (!navContext.mounted) return;
  return SubscriptionWalkthroughScreen.openEntry(navContext);
}

void openSubscriptionPlans(BuildContext context) {
  final navContext = rootNavigatorKey.currentContext ?? context;
  Navigator.of(navContext).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => const SubscriptionScreen(),
    ),
  );
}
