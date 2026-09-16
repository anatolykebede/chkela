import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../../core/providers/app_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/home_layout.dart';
import '../../core/theme/home_text_styles.dart';
import '../../data/content_access.dart';
import '../../data/home_mock_data.dart';
import '../../data/leaderboard_data.dart';
import '../../data/leaderboard_store.dart';
import '../../data/path_progress_store.dart';
import '../../data/study_progress_store.dart';
import '../../data/study_subjects.dart';
import '../../features/notes/subject_chapters_sheet.dart';
import '../../features/subscription/home_unlock_nudge.dart';
import '../../features/subscription/subscription_flow.dart';
import '../../features/profile/account_options_sheet.dart';
import '../../features/auth/auth_provider.dart';
import '../../widgets/common/free_content_badge.dart';
import '../../widgets/common/grade_selector.dart';
import '../../widgets/common/subject_lottie_icon.dart';
import '../../widgets/common/traveling_border.dart';
import '../../widgets/home/subject_watermarks.dart';
import '../../widgets/leaderboard/leaderboard_row.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _openLeaderboard(BuildContext context) {
    HapticFeedback.selectionClick();
    final nav = rootNavigatorKey.currentContext;
    if (nav != null && nav.mounted) {
      GoRouter.of(nav).push('/home/leaderboard');
      return;
    }
    context.push('/home/leaderboard');
  }

  String _hookLine() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Fresh mind. One win at a time.';
    if (hour < 17) return 'Stay locked in. Keep building.';
    return 'Night session. Finish strong.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGrade = ref.watch(selectedGradeProvider);
    final fullAccess =
        ref.watch(fullContentAccessProvider).valueOrNull ?? false;
    final subjects = homeSubjectsForScreen(activeGrade, fullAccess);
    final fullName = ref.watch(authProvider).fullName?.trim();
    final displayName = _homeFirstName(fullName);
    final initialsSource =
        (fullName != null && fullName.isNotEmpty) ? fullName : displayName;
    final auth = ref.watch(authProvider);
    LeaderboardStore.instance.configure(
      phoneE164: auth.phoneE164,
      fullName: auth.fullName,
      grade: auth.grade ?? activeGrade,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.bgSurface,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              HomeLayout.screenPadding,
              0,
              HomeLayout.screenPadding,
              MediaQuery.paddingOf(context).bottom + 100,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _TopBar(
                  hookLine: _hookLine(),
                  displayName: displayName,
                  initials: _initialsFromName(initialsSource),
                  onNotificationTap: () => context.push('/notifications'),
                  onProfileTap: () => showAccountOptionsSheet(context),
                ),
                const SizedBox(height: 22),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: GradeSelector(
                          activeGrade: activeGrade,
                          preferredGrade: ref.watch(authProvider).grade,
                          onGradeSelected: (grade) => ref
                              .read(selectedGradeProvider.notifier)
                              .state = grade,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: const _StreakCard(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const HomeUnlockNudge(),
                _SubjectsSection(
                  subjects: subjects,
                  activeGrade: activeGrade,
                  fullAccess: fullAccess,
                  onSeeAll: () => context.go('/study'),
                  onAnnouncementTap: () => context.pushNamed('thePath'),
                  onSubjectTap: (subject) {
                    if (subject.isLocked) {
                      HapticFeedback.lightImpact();
                      openSubscriptionFlow(context);
                      return;
                    }
                    HapticFeedback.lightImpact();
                    SubjectChaptersSheet.open(context, subject);
                  },
                ),
                _LeaderboardSection(
                  onSeeAll: () => _openLeaderboard(context),
                  onRowTap: (_) => _openLeaderboard(context),
                ),
                const SizedBox(height: HomeLayout.sectionGap),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _homeFirstName(String? fullName) {
  final raw = fullName?.trim() ?? '';
  if (raw.isEmpty) return 'Student';
  final first = raw.split(RegExp(r'\s+')).firstWhere(
        (part) => part.isNotEmpty,
        orElse: () => 'Student',
      );
  if (first.length <= 15) return first;
  return first.substring(0, 15);
}

String _initialsFromName(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'ST';
  if (parts.length == 1) {
    final w = parts.first;
    return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.hookLine,
    required this.displayName,
    required this.initials,
    required this.onNotificationTap,
    required this.onProfileTap,
  });

  final String hookLine;
  final String displayName;
  final String initials;
  final VoidCallback onNotificationTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hookLine,
                style: HomeTextStyles.bodySmall.copyWith(
                  fontSize: 13,
                  height: 1.05,
                ),
              ),
              Text(
                displayName,
                style: HomeTextStyles.displayName.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onNotificationTap,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Center(
                  child: Icon(
                    Icons.notifications_outlined,
                    size: 22,
                    color: AppColors.textSecondary,
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 11,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bgElevated, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onProfileTap,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.55),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                initials,
                style: HomeTextStyles.avatarLarge.copyWith(fontSize: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StreakCard extends StatefulWidget {
  const _StreakCard();

  @override
  State<_StreakCard> createState() => _StreakCardState();
}

class _StreakCardState extends State<_StreakCard> {
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await PathProgressStore.instance.load();
    if (!mounted) return;
    setState(() => _streak = PathProgressStore.instance.liveStreak);
  }

  @override
  Widget build(BuildContext context) {
    final label = _streak == 1 ? '1 day' : '$_streak days';
    return GestureDetector(
      onTap: () async {
        await context.push('/streak');
        if (mounted) await _refresh();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.amberSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Lottie.asset(
                'assets/lottie/fire.json',
                fit: BoxFit.contain,
                repeat: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Daily streak',
                    style: HomeTextStyles.badge.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 9,
                    ),
                  ),
                  Text(
                    label,
                    style: HomeTextStyles.pillLabel.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardSection extends StatelessWidget {
  const _LeaderboardSection({
    required this.onSeeAll,
    required this.onRowTap,
  });

  final VoidCallback onSeeAll;
  final ValueChanged<LeaderboardEntry> onRowTap;

  static const _rowHeight = 52.0;
  static const _visibleRows = 3;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LeaderboardStore.instance,
      builder: (context, _) {
        final entries = LeaderboardStore.instance.entries;
        if (entries.isEmpty) {
          return const SizedBox.shrink();
        }
        final listHeight =
            _rowHeight * entries.length.clamp(1, _visibleRows);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            _SectionHeader(
              label: 'Leaderboard',
              onSeeAll: onSeeAll,
            ),
            const SizedBox(height: HomeLayout.itemGap),
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(HomeLayout.leaderboardRadius),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  border: Border.all(color: AppColors.border, width: 0.5),
                  borderRadius:
                      BorderRadius.circular(HomeLayout.leaderboardRadius),
                ),
                child: SizedBox(
                  height: listHeight,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    physics: entries.length > _visibleRows
                        ? const BouncingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    itemCount: entries.length,
                    itemExtent: _rowHeight,
                    itemBuilder: (context, i) {
                      return LeaderboardRow(
                        entry: entries[i],
                        isLast: i == entries.length - 1,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onRowTap(entries[i]);
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SubjectsSection extends StatelessWidget {
  const _SubjectsSection({
    required this.subjects,
    required this.activeGrade,
    required this.fullAccess,
    required this.onSeeAll,
    required this.onAnnouncementTap,
    required this.onSubjectTap,
  });

  final List<StudySubject> subjects;
  final String activeGrade;
  final bool fullAccess;
  final VoidCallback onSeeAll;
  final VoidCallback onAnnouncementTap;
  final ValueChanged<StudySubject> onSubjectTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PathPromoBanner(
          key: const ValueKey('path-promo-banner'),
          onTap: onAnnouncementTap,
        ),
        const SizedBox(height: HomeLayout.sectionGap),
        _SectionHeader(label: 'Subjects', onSeeAll: onSeeAll),
        const SizedBox(height: 12),
        _SubjectGrid(
          subjects: subjects,
          activeGrade: activeGrade,
          fullAccess: fullAccess,
          onSubjectTap: onSubjectTap,
        ),
      ],
    );
  }
}

class _SubjectGrid extends StatelessWidget {
  const _SubjectGrid({
    required this.subjects,
    required this.activeGrade,
    required this.fullAccess,
    required this.onSubjectTap,
  });

  final List<StudySubject> subjects;
  final String activeGrade;
  final bool fullAccess;
  final ValueChanged<StudySubject> onSubjectTap;

  static const _tileHeight = 156.0;
  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    // Explicit rows avoid GridView.shrinkWrap height bugs in scroll views.
    return ListenableBuilder(
      listenable: StudyProgressStore.instance,
      builder: (context, _) {
        final rows = <Widget>[];
        for (var i = 0; i < subjects.length; i += 2) {
          final left = subjects[i];
          final right = i + 1 < subjects.length ? subjects[i + 1] : null;
          rows.add(
            Padding(
              padding: EdgeInsets.only(
                bottom: i + 2 < subjects.length ? _gap : 0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: _tileHeight,
                      child: _HomeSubjectTile(
                        subject: left,
                        activeGrade: activeGrade,
                        fullAccess: fullAccess,
                        progress: progressForGrade(left, activeGrade),
                        onTap: () => onSubjectTap(left),
                      ),
                    ),
                  ),
                  const SizedBox(width: _gap),
                  Expanded(
                    child: right == null
                        ? const SizedBox(height: _tileHeight)
                        : SizedBox(
                            height: _tileHeight,
                            child: _HomeSubjectTile(
                              subject: right,
                              activeGrade: activeGrade,
                              fullAccess: fullAccess,
                              progress: progressForGrade(right, activeGrade),
                              onTap: () => onSubjectTap(right),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: rows,
        );
      },
    );
  }
}

class _PathPromoBanner extends StatelessWidget {
  const _PathPromoBanner({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final promo = homeAnnouncement;

    return TravelingBorderHighlight(
      accent: promo.accent,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.all(1.5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(HomeLayout.cardRadius - 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: promo.accentSoft,
                borderRadius:
                    BorderRadius.circular(HomeLayout.iconBoxRadius),
              ),
              child: Icon(promo.icon, size: 20, color: promo.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _LiveTag(label: promo.tag, color: promo.accent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          promo.title,
                          style: HomeTextStyles.cardTitle.copyWith(
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    promo.subtitle,
                    style: HomeTextStyles.cardSub.copyWith(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: promo.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    promo.ctaLabel,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveTag extends StatelessWidget {
  const _LiveTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: HomeTextStyles.badge.copyWith(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSubjectTile extends StatelessWidget {
  const _HomeSubjectTile({
    required this.subject,
    required this.activeGrade,
    required this.fullAccess,
    required this.progress,
    required this.onTap,
  });

  final StudySubject subject;
  final String activeGrade;
  final bool fullAccess;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locked = subject.isLocked;
    final showFree = ContentAccess.showFreeSubjectHighlight(
      subject.name,
      fullAccess: fullAccess,
    );
    final percent = (progress * 100).round();
    final topics = topicCountForGrade(subject, activeGrade);
    final accent = subject.iconColor;
    const radius = 16.0;

    final tile = Opacity(
      opacity: locked ? 0.55 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              color: AppColors.bgElevated,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
                width: 0.8,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Stack(
                children: [
                  Positioned(
                    right: -4,
                    bottom: 8,
                    child: subject.lottieAsset != null
                        ? Opacity(
                            opacity: 0.52,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: SubjectLottieIcon(
                                subject: subject,
                                size: 96,
                              ),
                            ),
                          )
                        : SubjectWatermark(
                            subjectName: subject.name,
                            color: accent,
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(13, 12, 12, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SubjectBadge(subject: subject, accent: accent),
                            const Spacer(),
                            if (showFree)
                              const FreeContentTag(compact: true)
                            else if (locked)
                              Icon(
                                Icons.lock_rounded,
                                size: 15,
                                color: AppColors.textMuted.withValues(alpha: 0.9),
                              )
                            else
                              Text(
                                '$percent%',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                  height: 1.1,
                                ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          subject.shortCode,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9,
                            color: accent,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subject.name,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.25,
                            color: Colors.white,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          showFree
                              ? 'Chapter 1 · 2 lessons free'
                              : locked
                                  ? 'Unlock to study'
                                  : '$topics topics',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF8A8F9A),
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        _SubjectProgressBar(
                          value: locked ? 0 : progress.clamp(0.0, 1.0),
                          color: accent,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return tile;
  }
}

class _SubjectBadge extends StatelessWidget {
  const _SubjectBadge({
    required this.subject,
    required this.accent,
  });

  final StudySubject subject;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final hasLottie = subject.lottieAsset != null;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: subject.iconBg,
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(
        child: SubjectLottieIcon(
          subject: subject,
          size: hasLottie ? 28 : 18,
          fallbackColor: accent,
        ),
      ),
    );
  }
}

class _SubjectProgressBar extends StatelessWidget {
  const _SubjectProgressBar({
    required this.value,
    required this.color,
  });

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Colors.white.withValues(alpha: 0.08)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value,
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.onSeeAll,
  });

  final String label;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: AppColors.textPrimary,
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onSeeAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Text(
              'See all',
              style: HomeTextStyles.seeAll.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.accentText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
