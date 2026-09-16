import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/home_layout.dart';
import '../../core/theme/home_text_styles.dart';
import '../../data/exam_type.dart';
import '../../data/study_subjects.dart';
import '../../widgets/common/grade_selector.dart';
import '../../widgets/common/subject_lottie_icon.dart';
import '../auth/auth_provider.dart';
import '../notes/subject_exam_options_sheet.dart';
import '../subscription/subscription_flow.dart';

/// Bottom-nav Exam tab — pick type first, then a subject.
class ExamsHubScreen extends ConsumerWidget {
  const ExamsHubScreen({super.key});

  static const _types = [
    (
      ExamType.matricExam,
      'Matric',
      'National exam papers',
      Icons.school_rounded,
      AppColors.amber,
    ),
    (
      ExamType.midExam,
      'Mid',
      'Mid-year exams',
      Icons.assignment_outlined,
      AppColors.info,
    ),
    (
      ExamType.finalExam,
      'Final',
      'End-of-year finals',
      Icons.workspace_premium_outlined,
      AppColors.accentText,
    ),
  ];

  Future<void> _openSubjectsForType(
    BuildContext context,
    WidgetRef ref,
    ExamType type,
    String typeLabel,
    Color color,
  ) async {
    final subjects = homeSubjectsForScreen(
      ref.read(selectedGradeProvider),
      ref.read(fullContentAccessProvider).valueOrNull ?? false,
    );
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _ExamSubjectsSheet(
          type: type,
          typeLabel: typeLabel,
          color: color,
          subjects: subjects,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGrade = ref.watch(selectedGradeProvider);

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
              Text(
                'Exams',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose an exam type, then pick a subject.',
                style: HomeTextStyles.bodySmall.copyWith(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
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
              Text('EXAM TYPE', style: HomeTextStyles.sectionLabel),
              const SizedBox(height: 10),
              for (final entry in _types) ...[
                _ExamTypeOption(
                  title: entry.$2,
                  subtitle: entry.$3,
                  icon: entry.$4,
                  color: entry.$5,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _openSubjectsForType(
                      context,
                      ref,
                      entry.$1,
                      entry.$2,
                      entry.$5,
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamTypeOption extends StatelessWidget {
  const _ExamTypeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: HomeTextStyles.cardTitle),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: HomeTextStyles.cardSub.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textMuted.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamSubjectsSheet extends StatelessWidget {
  const _ExamSubjectsSheet({
    required this.type,
    required this.typeLabel,
    required this.color,
    required this.subjects,
  });

  final ExamType type;
  final String typeLabel;
  final Color color;
  final List<StudySubject> subjects;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    switch (type) {
                      ExamType.matricExam => Icons.school_rounded,
                      ExamType.midExam => Icons.assignment_outlined,
                      ExamType.finalExam => Icons.workspace_premium_outlined,
                      _ => Icons.quiz_outlined,
                    },
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        typeLabel,
                        style: HomeTextStyles.cardTitle.copyWith(
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Choose a subject',
                        style: HomeTextStyles.cardSub.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + bottom),
              itemCount: subjects.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final subject = subjects[index];
                return _ExamSubjectRow(
                  subject: subject,
                  examTypeLabel: typeLabel,
                  onTap: () {
                    if (subject.isLocked) {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                      openSubscriptionFlow(context);
                      return;
                    }
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                    SubjectExamOptionsSheet.open(
                      context,
                      subject,
                      initialType: type,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamSubjectRow extends StatelessWidget {
  const _ExamSubjectRow({
    required this.subject,
    required this.examTypeLabel,
    required this.onTap,
  });

  final StudySubject subject;
  final String examTypeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: subject.isLocked ? 0.6 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
          child: Ink(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.bgBase,
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
                      Text(subject.name, style: HomeTextStyles.cardTitle),
                      const SizedBox(height: 2),
                      Text(
                        '$examTypeLabel papers',
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
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textMuted.withValues(alpha: 0.7),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
