import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/home_layout.dart';
import '../../core/theme/home_text_styles.dart';
import '../../data/content/content_store.dart';
import '../../data/content_access.dart';
import '../../data/study_progress_store.dart';
import '../../data/study_subjects.dart';
import '../../widgets/common/free_content_badge.dart';
import '../../widgets/common/grade_selector.dart';
import '../../widgets/common/subject_lottie_icon.dart';
import '../subscription/subscription_flow.dart';
import '../auth/auth_provider.dart';
import 'subject_chapters_sheet.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  void _openSubject(StudySubject subject) {
    if (subject.isLocked) {
      HapticFeedback.lightImpact();
      openSubscriptionFlow(context);
      return;
    }
    HapticFeedback.lightImpact();
    SubjectChaptersSheet.open(context, subject);
  }

  void _openPendingSubject(String subjectName) {
    final subject = studySubjectByName(subjectName);
    if (subject == null) return;
    final fullAccess =
        ref.read(fullContentAccessProvider).valueOrNull ?? false;
    final resolved = resolveSubjectLock(
      subject,
      gradeSelection: ref.read(selectedGradeProvider),
      fullAccess: fullAccess,
    );
    if (resolved.isLocked) return;
    SubjectChaptersSheet.open(context, resolved);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(pendingStudySubjectProvider, (previous, next) {
      if (next == null) return;
      ref.read(pendingStudySubjectProvider.notifier).state = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openPendingSubject(next);
      });
    });

    final activeGrade = ref.watch(selectedGradeProvider);
    final fullAccess =
        ref.watch(fullContentAccessProvider).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _StudyHeader(),
              const SizedBox(height: 14),
              GradeSelector(
                activeGrade: activeGrade,
                preferredGrade: ref.watch(authProvider).grade,
                onGradeSelected: (grade) {
                  HapticFeedback.selectionClick();
                  ref.read(selectedGradeProvider.notifier).state = grade;
                },
              ),
              const SizedBox(height: 18),
              Text('SUBJECTS', style: HomeTextStyles.sectionLabel),
              const SizedBox(height: 10),
              ListenableBuilder(
                listenable: Listenable.merge([
                  StudyProgressStore.instance,
                  ContentStore.instance,
                ]),
                builder: (context, _) {
                  final subjects = studySubjectsForScreen(
                    activeGrade,
                    fullAccess,
                  );
                  return Column(
                    children: [
                      for (final subject in subjects)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _SubjectRow(
                            subject: subject,
                            activeGrade: activeGrade,
                            fullAccess: fullAccess,
                            progress: progressForGrade(subject, activeGrade),
                            onTap: () => _openSubject(subject),
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (!fullAccess) ...[
                const SizedBox(height: 12),
                _UpgradeBanner(
                  onTap: () => openSubscriptionFlow(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StudyHeader extends StatelessWidget {
  const _StudyHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Study',
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Notes, flashcards & quizzes — pick a subject to start.',
          style: HomeTextStyles.bodySmall.copyWith(
            fontSize: 13,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({
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
    final opacity = subject.isLocked ? 0.6 : 1.0;
    final topicCount = topicCountForGrade(subject, activeGrade);
    final showFree = ContentAccess.showFreeSubjectHighlight(
      subject.name,
      fullAccess: fullAccess,
    );

    final row = Opacity(
      opacity: opacity,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: subject.iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: Center(
                  child: SubjectLottieIcon(
                    subject: subject,
                    size: subject.lottieAsset != null ? 34 : 22,
                    fallbackColor: subject.iconColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            subject.name,
                            style: HomeTextStyles.cardTitle,
                          ),
                        ),
                        if (showFree) ...[
                          const SizedBox(width: 8),
                          const FreeContentTag(compact: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      showFree
                          ? 'Chapter 1 · 2 lessons free'
                          : subject.isLocked
                              ? 'Subscribe to unlock'
                              : '$topicCount topics · Tap to open chapters',
                      style: HomeTextStyles.cardSub.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (subject.isLocked)
                const Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: AppColors.textMuted,
                )
              else ...[
                _SubjectProgressRing(
                  progress: progress,
                  color: subject.iconColor,
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textMuted.withValues(alpha: 0.7),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return row;
  }
}

class _SubjectProgressRing extends StatelessWidget {
  const _SubjectProgressRing({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();

    return SizedBox(
      width: 38,
      height: 38,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            '$percent%',
            style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpgradeBanner extends StatelessWidget {
  const _UpgradeBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lock_open_rounded,
              size: 20,
              color: AppColors.accentText,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unlock all subjects',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'History, English, SAT & more — from 79 ETB/month',
                  style: HomeTextStyles.bodySmall.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'View plans',
              style: HomeTextStyles.badge.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
