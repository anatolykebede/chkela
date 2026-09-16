import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/home_layout.dart';
import '../../core/theme/home_text_styles.dart';
import '../../core/router/app_router.dart';
import '../../data/home_mock_data.dart';
import '../auth/auth_provider.dart';
import '../referral/referral_purchase_store.dart';

/// Quick account menu from the Home avatar.
Future<void> showAccountOptionsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => const _AccountOptionsSheet(),
  );
}

class _AccountOptionsSheet extends ConsumerWidget {
  const _AccountOptionsSheet();

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.bgElevated,
          title: Text(
            'Delete account?',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          content: Text(
            'This permanently deletes your Chkela account. You can register again with the same number as a new student.',
            style: HomeTextStyles.bodySmall.copyWith(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    try {
      await ReferralPurchaseStore.clear();
      await ref.read(authProvider.notifier).deleteAccount();
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      final nav = rootNavigatorKey.currentContext;
      if (nav != null && nav.mounted) {
        GoRouter.of(nav).go('/login');
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Could not delete account. Check your connection and try again.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.bgElevated,
        ),
      );
    }
  }

  void _go(BuildContext context, String route) {
    Navigator.of(context).pop();
    context.push(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final phone = auth.phoneE164;
    final grade = auth.grade ?? enrolledGrade;
    final phoneLabel =
        phone == null ? 'Not signed in' : AuthNotifier.displayPhone(phone);
    final fullName = auth.fullName?.trim();
    final displayName =
        (fullName != null && fullName.isNotEmpty) ? fullName : 'Student';
    final initials = _initialsFromName(displayName);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(HomeLayout.cardRadius + 4),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: HomeTextStyles.avatarLarge.copyWith(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '$grade · $phoneLabel',
                          style: HomeTextStyles.bodySmall.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SheetTile(
                icon: Icons.person_add_alt_1_rounded,
                title: 'Invite friends',
                onTap: () => _go(context, '/invite'),
              ),
              _SheetTile(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Feedback',
                onTap: () => _go(context, '/account/feedback'),
              ),
              _SheetTile(
                icon: Icons.support_agent_rounded,
                title: 'Support',
                onTap: () => _go(context, '/account/support'),
              ),
              _SheetTile(
                icon: Icons.share_outlined,
                title: 'Social media',
                onTap: () => _go(context, '/account/social'),
              ),
              _SheetTile(
                icon: Icons.description_outlined,
                title: 'Terms & Conditions',
                onTap: () => _go(context, '/account/terms'),
              ),
              _SheetTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () => _go(context, '/account/privacy'),
              ),
              _SheetTile(
                icon: Icons.manage_accounts_outlined,
                title: 'Open full profile',
                onTap: () => _go(context, '/profile'),
              ),
              const SizedBox(height: 6),
              _SheetTile(
                icon: Icons.logout_rounded,
                title: 'Sign out',
                onTap: () async {
                  await ref.read(authProvider.notifier).signOut();
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }
                  final nav = rootNavigatorKey.currentContext;
                  if (nav != null && nav.mounted) {
                    GoRouter.of(nav).go('/login');
                  }
                },
              ),
              _SheetTile(
                icon: Icons.delete_outline_rounded,
                title: 'Delete account',
                danger: true,
                onTap: () => _deleteAccount(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _initialsFromName(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final w = parts.first;
    return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: danger
                    ? AppColors.danger.withValues(alpha: 0.35)
                    : AppColors.border,
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: danger ? AppColors.danger : AppColors.accentText),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted.withValues(alpha: 0.85),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
