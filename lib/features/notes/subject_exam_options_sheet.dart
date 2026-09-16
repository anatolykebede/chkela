import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/home_layout.dart';
import '../../core/theme/home_text_styles.dart';
import '../../data/exam_data.dart';
import '../../data/exam_questions.dart';
import '../../data/exam_type.dart';
import '../../data/study_progress_store.dart';
import '../../data/study_subjects.dart';
import '../../data/subject_chapters.dart';
import 'subject_chapters_sheet.dart';

class SubjectExamOptionsSheet extends ConsumerStatefulWidget {
  const SubjectExamOptionsSheet({
    super.key,
    required this.subject,
    this.showBackButton = false,
    this.initialType,
  });

  final StudySubject subject;
  final bool showBackButton;
  final ExamType? initialType;

  static void open(
    BuildContext context,
    StudySubject subject, {
    bool showBackButton = true,
    ExamType? initialType,
  }) {
    final base = SubjectChaptersSheet.examsRouteFor(subject);
    final uri = initialType == null
        ? base
        : Uri.parse(base).replace(queryParameters: {
            'type': initialType.name,
          }).toString();
    context.push(uri);
  }

  @override
  ConsumerState<SubjectExamOptionsSheet> createState() =>
      _SubjectExamOptionsSheetState();
}

class _SubjectExamOptionsSheetState
    extends ConsumerState<SubjectExamOptionsSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  ExamType? _expandedType;

  static const _allExamTypes = [
    ExamType.matricExam,
    ExamType.midExam,
    ExamType.finalExam,
  ];

  /// When opened from Exam tab with a type, lock to that type only.
  bool get _lockedToType => widget.initialType != null;

  List<ExamType> get _examTypes =>
      _lockedToType ? [widget.initialType!] : _allExamTypes;

  String get _typeShortLabel {
    final type = widget.initialType;
    if (type == null) return 'Exams';
    return switch (type) {
      ExamType.matricExam => 'Matric',
      ExamType.midExam => 'Mid',
      ExamType.finalExam => 'Final',
      _ => type.title,
    };
  }

  @override
  void initState() {
    super.initState();
    _expandedType = widget.initialType;
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Animation<double> _stagger(int index, {double span = 0.2}) {
    final start = 0.06 + (index * 0.09);
    final end = (start + span).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _entranceController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  void _toggleType(ExamType type) {
    if (_lockedToType) return;
    setState(() {
      _expandedType = _expandedType == type ? null : type;
    });
  }

  void _openExam(ExamType type, ExamItem exam) {
    context.push(
      '/content/exam',
      extra: ExamSessionArgs(
        subjectName: widget.subject.name,
        examType: type,
        examTitle: exam.title,
        examId: exam.id,
        grade: ref.read(selectedGradeProvider),
      ),
    );
  }

  void _goBack() => context.pop();

  @override
  Widget build(BuildContext context) {
    final lockedType = widget.initialType;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StaggeredEntrance(
                    animation: _stagger(0, span: 0.15),
                    child: Row(
                      children: [
                        if (widget.showBackButton)
                          IconButton(
                            onPressed: _goBack,
                            icon: const Icon(
                              Icons.arrow_back,
                              color: AppColors.textSecondary,
                              size: 22,
                            ),
                          ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: lockedType?.iconBg ?? widget.subject.iconBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            lockedType?.icon ?? Icons.fact_check_outlined,
                            color:
                                lockedType?.iconColor ?? widget.subject.iconColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _lockedToType
                                    ? '${widget.subject.name} · $_typeShortLabel'
                                    : '${widget.subject.name} · Exams',
                                style: GoogleFonts.inter(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                _lockedToType
                                    ? '$_typeShortLabel exam papers'
                                    : 'Matric, mid and final papers',
                                style: HomeTextStyles.bodySmall
                                    .copyWith(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _StaggeredEntrance(
                    animation: _stagger(2, span: 0.16),
                    child: Text(
                      _lockedToType ? 'PAPERS' : 'EXAM TYPES',
                      style: HomeTextStyles.sectionLabel,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            Expanded(
              child: _lockedToType
                  ? _LockedTypePapersList(
                      type: lockedType!,
                      subject: widget.subject,
                      stagger: _stagger,
                      gradeLabel: ref.watch(selectedGradeProvider),
                      onExamTap: (exam) => _openExam(lockedType, exam),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: _examTypes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final type = _examTypes[index];
                        return _StaggeredEntrance(
                          animation: _stagger(index + 3),
                          child: _ExpandableExamTypeTile(
                            type: type,
                            subject: widget.subject,
                            gradeLabel: ref.watch(selectedGradeProvider),
                            isExpanded: _expandedType == type,
                            onToggle: () => _toggleType(type),
                            onExamTap: (exam) => _openExam(type, exam),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedTypePapersList extends StatelessWidget {
  const _LockedTypePapersList({
    required this.type,
    required this.subject,
    required this.stagger,
    required this.onExamTap,
    required this.gradeLabel,
  });

  final ExamType type;
  final StudySubject subject;
  final Animation<double> Function(int index, {double span}) stagger;
  final ValueChanged<ExamItem> onExamTap;
  final String gradeLabel;

  @override
  Widget build(BuildContext context) {
    final exams = examsForSubject(
      subject.name,
      type,
      gradeLabel: gradeLabel,
    );

    if (exams.isEmpty) {
      return Center(
        child: Text(
          'No ${type.title.toLowerCase()} papers yet',
          style: HomeTextStyles.bodySmall,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: exams.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final exam = exams[index];
        return _StaggeredEntrance(
          animation: stagger(index + 3),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onExamTap(exam),
              borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
              child: Ink(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: type.iconBg,
                        borderRadius:
                            BorderRadius.circular(HomeLayout.iconBoxRadius),
                      ),
                      child: Icon(type.icon, size: 22, color: type.iconColor),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exam.title,
                            style:
                                HomeTextStyles.cardTitle.copyWith(fontSize: 14),
                          ),
                          const SizedBox(height: 3),
                          Text(exam.subtitle, style: HomeTextStyles.cardSub),
                          const SizedBox(height: 4),
                          Text(
                            '${exam.questionCount} questions · ${exam.durationMinutes} min',
                            style: HomeTextStyles.bodySmall
                                .copyWith(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    if (exam.isCompleted)
                      Text(
                        'DONE',
                        style: HomeTextStyles.badge.copyWith(
                          color: AppColors.teal,
                          fontSize: 9,
                        ),
                      )
                    else
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.textMuted,
                        size: 18,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ExpandableExamTypeTile extends StatelessWidget {
  const _ExpandableExamTypeTile({
    required this.type,
    required this.subject,
    required this.isExpanded,
    required this.onToggle,
    required this.onExamTap,
    required this.gradeLabel,
  });

  final ExamType type;
  final StudySubject subject;
  final bool isExpanded;
  final VoidCallback onToggle;
  final ValueChanged<ExamItem> onExamTap;
  final String gradeLabel;

  @override
  Widget build(BuildContext context) {
    final exams = type == ExamType.chapterExam
        ? null
        : examsForSubject(subject.name, type, gradeLabel: gradeLabel);
    final chapters = type == ExamType.chapterExam
        ? chaptersForSubject(subject.name, gradeLabel: gradeLabel)
        : null;
    final subCount = exams?.length ?? chapters?.length ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
        border: Border.all(
          color: isExpanded
              ? type.iconColor.withValues(alpha: 0.45)
              : AppColors.border,
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: type.iconBg,
                      borderRadius:
                          BorderRadius.circular(HomeLayout.iconBoxRadius),
                    ),
                    child: Icon(type.icon, size: 22, color: type.iconColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type.title,
                          style: HomeTextStyles.cardTitle.copyWith(fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$subCount available',
                          style: HomeTextStyles.cardSub,
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.chevron_right,
                      color: isExpanded ? type.iconColor : AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Column(
                    children: [
                      Container(height: 0.5, color: AppColors.border),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            type == ExamType.chapterExam
                                ? 'CHAPTERS'
                                : 'PAPERS',
                            style: HomeTextStyles.sectionLabel
                                .copyWith(fontSize: 10),
                          ),
                        ),
                      ),
                      if (exams != null)
                        ...List.generate(exams.length, (index) {
                          final exam = exams[index];
                          final isLast = index == exams.length - 1;
                          return _ExamSubItem(
                            title: exam.title,
                            subtitle: exam.subtitle,
                            meta:
                                '${exam.questionCount} questions · ${exam.durationMinutes} min',
                            accent: type.iconColor,
                            isCompleted: exam.isCompleted,
                            isLast: isLast,
                            onTap: () => onExamTap(exam),
                          );
                        }),
                      if (chapters != null)
                        ...List.generate(chapters.length, (index) {
                          final chapter = chapters[index];
                          final isLast = index == chapters.length - 1;
                          return _ExamSubItem(
                            title: chapter.title,
                            subtitle: chapter.subtitle,
                            accent: type.iconColor,
                            isCompleted: StudyProgressStore.instance
                                .isChapterExamDone(chapter.id),
                            isLast: isLast,
                            onTap: () {},
                          );
                        }),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _ExamSubItem extends StatelessWidget {
  const _ExamSubItem({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.isLast,
    required this.onTap,
    this.meta,
    this.isCompleted = false,
  });

  final String title;
  final String subtitle;
  final String? meta;
  final Color accent;
  final bool isCompleted;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: AppColors.border, width: 0.5),
                ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: HomeTextStyles.cardTitle.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: HomeTextStyles.cardSub),
                  if (meta != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      meta!,
                      style: HomeTextStyles.bodySmall.copyWith(fontSize: 10),
                    ),
                  ],
                ],
              ),
            ),
            if (isCompleted)
              Text(
                'DONE',
                style: HomeTextStyles.badge.copyWith(
                  color: AppColors.teal,
                  fontSize: 9,
                ),
              )
            else
              Icon(Icons.chevron_right, color: AppColors.textMuted, size: 16),
          ],
        ),
      ),
    );
  }
}

class _StaggeredEntrance extends StatelessWidget {
  const _StaggeredEntrance({
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final value = animation.value;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
