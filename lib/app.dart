import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/providers/app_providers.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/home_layout.dart';
import '../core/theme/home_text_styles.dart';
import '../core/theme/app_theme.dart';
import 'features/auth/auth_provider.dart';
import 'features/notifications/push_notification_service.dart';
import 'features/subscription/subscription_access_store.dart';
import 'widgets/common/ai_guider_button.dart';

class ChkelaApp extends ConsumerStatefulWidget {
  const ChkelaApp({super.key});

  @override
  ConsumerState<ChkelaApp> createState() => _ChkelaAppState();
}

class _ChkelaAppState extends ConsumerState<ChkelaApp> {
  StreamSubscription? _paymentApprovedSub;
  bool _paymentDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _paymentApprovedSub =
        PushNotificationService.instance.onPaymentApproved.listen((_) {
      unawaited(_handlePaymentApproved());
    });
  }

  @override
  void dispose() {
    _paymentApprovedSub?.cancel();
    super.dispose();
  }

  Future<void> _handlePaymentApproved() async {
    await SubscriptionAccessStore.syncFromServer();
    if (!mounted) return;
    ref.read(subscriptionAccessEpochProvider.notifier).state++;

    if (_paymentDialogOpen) return;
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;

    _paymentDialogOpen = true;
    try {
      await showDialog<void>(
        context: navContext,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: AppColors.bgElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
            ),
            title: Text(
              'Payment approved',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            content: Text(
              'Your subscription is active. Every subject is unlocked — start studying now.',
              style: HomeTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'Later',
                  style: HomeTextStyles.badge.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  final routerContext = rootNavigatorKey.currentContext;
                  if (routerContext != null && routerContext.mounted) {
                    GoRouter.of(routerContext).go('/study');
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                ),
                child: Text(
                  'Study subjects',
                  style: HomeTextStyles.badge.copyWith(color: Colors.white),
                ),
              ),
            ],
          );
        },
      );
    } finally {
      _paymentDialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated && next.phoneE164 != null) {
        PushNotificationService.instance.syncTokenForPhone(next.phoneE164);
      }
    });

    return MaterialApp.router(
      title: 'Chkela',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const AiGuiderOverlay(),
          ],
        );
      },
    );
  }
}
