import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/home_text_styles.dart';
import '../../core/router/app_router.dart';
import '../../data/map_activity.dart';
import '../../data/map_profile_store.dart';
import '../../data/path_progress_store.dart';
import '../../data/points_badges.dart';
import '../../data/study_progress_store.dart';
import '../../widgets/common/points_badge_chips.dart';
import '../auth/auth_provider.dart';
import '../referral/referral_purchase_store.dart';
import 'full_profile_chrome.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _tab = 1;

  static const _tabs = ['Activity', 'Progress', 'Friends', 'Account'];

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
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

    if (confirmed != true || !mounted) return;
    HapticFeedback.mediumImpact();
    try {
      await ReferralPurchaseStore.clear();
      await ref.read(authProvider.notifier).deleteAccount();
      final nav = rootNavigatorKey.currentContext;
      if (nav != null && nav.mounted) {
        GoRouter.of(nav).go('/login');
      } else if (mounted) {
        context.go('/login');
      }
    } catch (_) {
      if (!mounted) return;
      _showSnack('Could not delete account. Check your connection and try again.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.bgElevated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final phone = auth.phoneE164;
    final phoneLabel = phone == null
        ? 'Not signed in'
        : AuthNotifier.displayPhone(phone);

    return ListenableBuilder(
      listenable: Listenable.merge([
        MapProfileStore.instance,
        StudyProgressStore.instance,
        PathProgressStore.instance,
      ]),
      builder: (context, _) {
        final store = MapProfileStore.instance;
        final me = store.me;
        final name = me.name;
        final initials = me.initials;
        final username = FullProfileChrome.usernameFromName(name);
        final bio = (store.bio?.trim().isNotEmpty ?? false)
            ? store.bio!.trim()
            : (me.bio?.trim().isNotEmpty ?? false)
                ? me.bio!.trim()
                : 'Studying on Chkela · ${me.grade}';
        final status = me.isOnline
            ? 'online'
            : '${me.grade} · ${me.school}';
        final friends = store.friendsFor(me);
        final study = StudyProgressStore.instance;
        final path = PathProgressStore.instance;
        final activities = store.activitiesFor(me);

        return Scaffold(
          backgroundColor: AppColors.bgBase,
          body: SafeArea(
            child: Column(
              children: [
                ProfileTopBar(
                  onBack: () => context.pop(),
                  onEdit: () => context.push('/map/edit-profile'),
                ),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      const SizedBox(height: 8),
                      Center(
                        child: ProfileAvatarHero(
                          initials: initials,
                          isOnline: me.isOnline,
                          rankBadge: PointsTierPill(
                            points: me.points,
                            compact: false,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        pointsRankFor(me.points).label,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ProfileActionStrip(
                        actions: [
                          ProfileActionSpec(
                            icon: Icons.chat_bubble_outline_rounded,
                            label: 'Message',
                            onTap: () => context.push('/chats'),
                          ),
                          ProfileActionSpec(
                            icon: Icons.map_outlined,
                            label: 'Map',
                            onTap: () => context.go('/map'),
                          ),
                          ProfileActionSpec(
                            icon: Icons.person_add_alt_1_rounded,
                            label: 'Invite',
                            onTap: () => context.push('/invite'),
                          ),
                          ProfileActionSpec(
                            icon: Icons.route_rounded,
                            label: 'Path',
                            onTap: () => context.push('/path'),
                          ),
                          ProfileActionSpec(
                            icon: Icons.more_horiz_rounded,
                            label: 'More',
                            onTap: () => setState(() => _tab = 3),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ProfileInfoCard(
                        rows: [
                          ProfileInfoRow(
                            label: 'mobile',
                            value: phoneLabel,
                            valueColor: FullProfileChrome.actionBlue,
                          ),
                          ProfileInfoRow(
                            label: 'username',
                            value: username,
                            valueColor: FullProfileChrome.actionBlue,
                            trailing: Icon(
                              Icons.qr_code_2_rounded,
                              size: 22,
                              color: FullProfileChrome.actionBlue
                                  .withValues(alpha: 0.9),
                            ),
                            onTap: () => _showSnack('Chkela ID: $username'),
                          ),
                          ProfileInfoRow(
                            label: 'bio',
                            value: bio,
                            onTap: () => context.push('/map/edit-profile'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      ProfileContentTabs(
                        tabs: _tabs,
                        selectedIndex: _tab,
                        onChanged: (i) => setState(() => _tab = i),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _tabContent(
                          tab: _tab,
                          activities: activities,
                          friendsCount: friends.length,
                          points: me.points,
                          streak: me.streak,
                          pathXp: path.xpWallet,
                          notesDone: study.notesCompleted,
                          decksDone: study.decksCompleted,
                          examsDone: study.chapterExamsCompleted,
                          subjects: me.subjects,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tabContent({
    required int tab,
    required List<MapActivityItem> activities,
    required int friendsCount,
    required int points,
    required int streak,
    required int pathXp,
    required int notesDone,
    required int decksDone,
    required int examsDone,
    required List<String> subjects,
  }) {
    switch (tab) {
      case 0:
        if (activities.isEmpty) {
          return const _EmptyPane(
            title: 'No activity yet',
            subtitle: 'Finish notes, Path levels, or exams to fill this feed.',
          );
        }
        return Column(
          children: [
            for (final item in activities.take(8))
              _ActivityCard(
                title: item.title,
                subtitle: item.subtitle,
                onTap: () {
                  final route = item.ctaRoute;
                  if (route != null && route.isNotEmpty) {
                    context.push(route);
                  }
                },
              ),
          ],
        );
      case 1:
        final rank = pointsRankFor(points);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatMini(label: 'Points', value: '$points'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatMini(label: 'Streak', value: '${streak}d'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatMini(label: 'Path XP', value: '$pathXp'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('RANK BADGE', style: HomeTextStyles.sectionLabel),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FullProfileChrome.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      PointsTierPill(points: points, compact: false),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rank.label,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pointsNextRankHint(points),
                              style: HomeTextStyles.cardSub.copyWith(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < pointsRankCatalog.length; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          _RankTierSlot(
                            info: pointsRankCatalog[i],
                            unlocked: points >= pointsRankCatalog[i].minPoints,
                            isCurrent:
                                pointsRankCatalog[i].tier == rank.tier,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('POINT MILESTONES', style: HomeTextStyles.sectionLabel),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in pointsMilestoneCatalog)
                  Opacity(
                    opacity: points >= m.minPoints ? 1 : 0.4,
                    child: ProfileBadgeChip(
                      badge: ProfileBadge(
                        icon: points >= m.minPoints
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        label: m.label,
                        color: points >= m.minPoints
                            ? AppColors.amber
                            : AppColors.textMuted,
                        background: points >= m.minPoints
                            ? AppColors.amberSoft
                            : AppColors.bgElevated,
                      ),
                      compact: true,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _ProgressLine(label: 'Notes finished', value: notesDone, max: 12),
            _ProgressLine(label: 'Flashcard decks', value: decksDone, max: 8),
            _ProgressLine(label: 'Chapter exams', value: examsDone, max: 6),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('FOCUS SUBJECTS', style: HomeTextStyles.sectionLabel),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in subjects)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: FullProfileChrome.cardBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      s,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      case 2:
        return Column(
          children: [
            ProfileSettingsTile(
              icon: Icons.people_outline_rounded,
              title: 'Friends',
              subtitle: '$friendsCount classmates connected',
              onTap: () => context.push(
                '/student/${MapProfileStore.currentUserId}/full',
              ),
            ),
            ProfileSettingsTile(
              icon: Icons.map_outlined,
              title: 'Open student map',
              subtitle: 'Find classmates near you',
              onTap: () => context.go('/map'),
            ),
            ProfileSettingsTile(
              icon: Icons.person_add_alt_1_rounded,
              title: 'Invite friends',
              subtitle: 'Share your code · earn CP',
              onTap: () => context.push('/invite'),
            ),
          ],
        );
      default:
        return Column(
          children: [
            ProfileSettingsTile(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Feedback',
              subtitle: 'Tell us what to improve',
              onTap: () => context.push('/account/feedback'),
            ),
            ProfileSettingsTile(
              icon: Icons.support_agent_rounded,
              title: 'Support',
              subtitle: 'Telegram, email, or phone',
              onTap: () => context.push('/account/support'),
            ),
            ProfileSettingsTile(
              icon: Icons.share_outlined,
              title: 'Social media',
              subtitle: 'Follow Chkela online',
              onTap: () => context.push('/account/social'),
            ),
            ProfileSettingsTile(
              icon: Icons.description_outlined,
              title: 'Terms & Conditions',
              subtitle: 'Rules for using Chkela',
              onTap: () => context.push('/account/terms'),
            ),
            ProfileSettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'How we handle your data',
              onTap: () => context.push('/account/privacy'),
            ),
            ProfileSettingsTile(
              icon: Icons.logout_rounded,
              title: 'Sign out',
              subtitle: 'Keep your profile on this device',
              onTap: () async {
                HapticFeedback.selectionClick();
                await ref.read(authProvider.notifier).signOut();
                if (!mounted) return;
                context.go('/login');
              },
            ),
            ProfileSettingsTile(
              icon: Icons.delete_outline_rounded,
              title: 'Delete account',
              subtitle: 'Remove local profile and sign out',
              danger: true,
              onTap: _confirmDelete,
            ),
            const SizedBox(height: 12),
            Text(
              '© Chkela',
              textAlign: TextAlign.center,
              style: HomeTextStyles.bodySmall.copyWith(fontSize: 11),
            ),
          ],
        );
    }
  }
}

class _EmptyPane extends StatelessWidget {
  const _EmptyPane({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FullProfileChrome.cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: HomeTextStyles.bodySmall.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FullProfileChrome.cardBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: HomeTextStyles.bodySmall.copyWith(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  const _StatMini({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: FullProfileChrome.cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: HomeTextStyles.bodySmall.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({
    required this.label,
    required this.value,
    required this.max,
  });

  final String label;
  final int value;
  final int max;

  @override
  Widget build(BuildContext context) {
    final p = (value / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FullProfileChrome.cardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '$value',
                  style: HomeTextStyles.bodySmall.copyWith(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: p,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                color: FullProfileChrome.actionBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankTierSlot extends StatelessWidget {
  const _RankTierSlot({
    required this.info,
    required this.unlocked,
    required this.isCurrent,
  });

  final PointsRankTierInfo info;
  final bool unlocked;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final style = pointsRankStyle(info.tier);
    return Tooltip(
      message: '${info.label} · ${info.minPoints} pts',
      child: Opacity(
        opacity: unlocked ? 1 : 0.35,
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: style.$2,
                border: Border.all(
                  color: isCurrent
                      ? style.$1
                      : style.$1.withValues(alpha: unlocked ? 0.55 : 0.25),
                  width: isCurrent ? 2 : 1.2,
                ),
              ),
              child: Icon(style.$3, size: 18, color: style.$1),
            ),
            const SizedBox(height: 4),
            Text(
              info.label,
              style: HomeTextStyles.badge.copyWith(
                fontSize: 9,
                color: unlocked ? style.$1 : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
