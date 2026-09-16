import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/home_layout.dart';
import '../../core/theme/home_text_styles.dart';
import '../../data/leaderboard_data.dart';
import '../../data/leaderboard_store.dart';
import '../../data/path_progress_store.dart';
import '../../data/study_progress_store.dart';
import '../auth/auth_provider.dart';
import '../../widgets/common/points_badge_chips.dart';
import '../../widgets/leaderboard/leaderboard_row.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authProvider);
      LeaderboardStore.instance.configure(
        phoneE164: auth.phoneE164,
        fullName: auth.fullName,
        grade: auth.grade,
      );
      LeaderboardStore.instance.refresh(forceUpsert: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final grade = auth.grade;

    return ListenableBuilder(
      listenable: LeaderboardStore.instance,
      builder: (context, _) {
        final path = PathProgressStore.instance;
        final study = StudyProgressStore.instance;
        final entries = LeaderboardStore.instance.entries;
        final loading = LeaderboardStore.instance.loading;
        final you = entries.where((e) => e.isCurrentUser).firstOrNull ??
            (entries.isEmpty ? null : entries.first);
        final classmateCount =
            entries.where((e) => !e.isCurrentUser).length;

        return Scaffold(
          backgroundColor: AppColors.bgBase,
          appBar: AppBar(
            backgroundColor: AppColors.bgSurface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () => context.pop(),
            ),
            title: Text('Leaderboard', style: AppTextStyles.headingMedium),
            actions: [
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            ],
          ),
          body: RefreshIndicator(
            color: AppColors.accentText,
            onRefresh: () =>
                LeaderboardStore.instance.refresh(forceUpsert: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (grade != null && grade.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      grade.trim(),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentText,
                      ),
                    ),
                  ),
                if (you != null) ...[
                  _YourRankCard(entry: you),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Your points',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                _PointsBreakdown(path: path, study: study),
                const SizedBox(height: 20),
                Text(
                  classmateCount > 0
                      ? 'Rankings · ${entries.length} students'
                      : 'Rankings',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius:
                        BorderRadius.circular(HomeLayout.leaderboardRadius),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < entries.length; i++)
                        LeaderboardRow(
                          entry: entries[i],
                          isLast: i == entries.length - 1 && classmateCount > 0,
                          onTap: () {},
                        ),
                      if (classmateCount == 0)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                          child: Text(
                            'No classmates on this board yet. When other ${grade ?? 'students'} sync their scores, they will appear here.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              height: 1.4,
                              color: AppColors.textMuted,
                            ),
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
}

class _PointsBreakdown extends StatelessWidget {
  const _PointsBreakdown({
    required this.path,
    required this.study,
  });

  final PathProgressStore path;
  final StudyProgressStore study;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Path XP', path.xpWallet),
      ('Stars', path.totalStars * 40),
      ('Notes', study.notesCompleted * 35),
      ('Flashcards', study.decksCompleted * 45),
      ('Chapter exams', study.chapterExamsCompleted * 80),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 16, color: AppColors.border),
            Row(
              children: [
                Expanded(
                  child: Text(
                    rows[i].$1,
                    style: HomeTextStyles.cardTitle,
                  ),
                ),
                Text(
                  '${formatLeaderboardPoints(rows[i].$2)} pts',
                  style: HomeTextStyles.points,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _YourRankCard extends StatelessWidget {
  const _YourRankCard({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentSoft.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              '#${entry.rank}',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.accentText,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your rank',
                  style: HomeTextStyles.cardSub,
                ),
                Text(
                  entry.name,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                PointsTierPill(points: entry.points, compact: false),
              ],
            ),
          ),
          Text(
            '${formatLeaderboardPoints(entry.points)} pts',
            style: HomeTextStyles.points.copyWith(fontSize: 15),
          ),
        ],
      ),
    );
  }
}
