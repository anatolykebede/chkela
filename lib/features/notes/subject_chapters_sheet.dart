import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/home_text_styles.dart';
import '../../data/chapter_content_items.dart';
import '../../data/content_access.dart';
import '../../data/note_assets.dart';
import '../../data/exam_questions.dart';
import '../../data/exam_type.dart';
import '../../data/flashcard_data.dart';
import '../../data/study_mode.dart';
import '../../data/content/content_store.dart';
import '../../data/study_progress_store.dart';
import '../../data/study_subjects.dart';
import '../../data/subject_chapters.dart';
import '../../widgets/common/free_content_badge.dart';
import '../../widgets/common/grade_selector.dart';
import '../../widgets/common/subject_lottie_icon.dart';
import '../auth/auth_provider.dart';
import '../subscription/subscription_flow.dart';

class SubjectChaptersSheet extends ConsumerStatefulWidget {
  const SubjectChaptersSheet({
    super.key,
    required this.subject,
    this.isChapterExam = false,
  });

  final StudySubject subject;
  final bool isChapterExam;

  static String routeFor(
    StudySubject subject, {
    bool chapterExam = false,
  }) {
    final encoded = Uri.encodeComponent(subject.name);
    if (chapterExam) return '/study/subject/$encoded?mode=chapter-exam';
    return '/study/subject/$encoded';
  }

  static String examsRouteFor(StudySubject subject) =>
      '${routeFor(subject)}/exams';

  static void open(BuildContext context, StudySubject subject) {
    context.push(routeFor(subject));
  }

  static void openChapterExamPicker(BuildContext context, StudySubject subject) {
    context.push(routeFor(subject, chapterExam: true));
  }

  @override
  ConsumerState<SubjectChaptersSheet> createState() =>
      _SubjectChaptersSheetState();
}

class _SubjectChaptersSheetState extends ConsumerState<SubjectChaptersSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  String? _openChapterId;
  SubjectStudyMode? _activeMode;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    StudyProgressStore.instance.load();
  }

  List<SubjectChapter> get _chapters {
    final grade = ref.watch(selectedGradeProvider);
    return chaptersForSubject(widget.subject.name, gradeLabel: grade);
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Animation<double> _stagger(int index, {double span = 0.18}) {
    final start = 0.06 + (index * 0.1);
    final end = (start + span).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _entranceController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  Future<void> _changeGrade() async {
    HapticFeedback.selectionClick();
    final current = ref.read(selectedGradeProvider);
    final next = await showGradePickerSheet(
      context,
      activeGrade: current,
      preferredGrade: ref.read(authProvider).grade,
    );
    if (!mounted || next == null || next == current) return;

    ref.read(selectedGradeProvider.notifier).state = next;

    final available = subjectNamesForGradeSelection(next);
    if (!available.contains(widget.subject.name)) {
      final label = widget.subject.name;
      context.pop();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$label isn’t in $next. Pick another subject.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  bool get _fullAccess =>
      ref.watch(fullContentAccessProvider).valueOrNull ?? false;

  void _requireSubscription() {
    HapticFeedback.lightImpact();
    openSubscriptionFlow(context);
  }

  void _toggleMode(SubjectChapter chapter, SubjectStudyMode mode) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_openChapterId == chapter.id && _activeMode == mode) {
        _openChapterId = null;
        _activeMode = null;
      } else {
        _openChapterId = chapter.id;
        _activeMode = mode;
      }
    });
  }

  void _openContent(
    SubjectChapter chapter,
    ChapterContentItem item,
    SubjectStudyMode mode,
  ) {
    final free = ContentAccess.isNoteFree(
      subjectName: widget.subject.name,
      chapterId: chapter.id,
      noteId: item.id,
      fullAccess: _fullAccess,
    );
    if (!free) {
      _requireSubscription();
      return;
    }

    if (mode == SubjectStudyMode.notes) {
      context.push(
        '/content/notes',
        extra: NoteSessionArgs(
          subjectName: widget.subject.name,
          chapterTitle: chapter.title,
          chapterId: chapter.id,
          noteId: item.id,
          noteTitle: item.title,
        ),
      );
      return;
    }

    context.push(
      '/content/${mode.name}',
      extra: '${widget.subject.name} · ${chapter.title} · ${item.title}',
    );
  }

  void _openFlashcards(
    SubjectChapter chapter, {
    ChapterContentItem? deck,
  }) {
    context.push(
      '/content/flashcards',
      extra: FlashcardSessionArgs(
        subjectName: widget.subject.name,
        chapterTitle: chapter.title,
        chapterId: chapter.id,
        deckId: deck?.id,
        deckTitle: deck?.title,
      ),
    );
  }

  void _openChapterExam(SubjectChapter chapter) {
    context.push(
      '/content/exam',
      extra: ExamSessionArgs(
        subjectName: widget.subject.name,
        examType: ExamType.chapterExam,
        examTitle: chapter.title,
        chapterId: chapter.id,
        chapterTitle: chapter.title,
        grade: ref.read(selectedGradeProvider),
      ),
    );
  }

  void _openNoteQuiz(SubjectChapter chapter, ChapterContentItem item) {
    final free = ContentAccess.isNoteFree(
      subjectName: widget.subject.name,
      chapterId: chapter.id,
      noteId: item.id,
      fullAccess: _fullAccess,
    );
    if (!free) {
      _requireSubscription();
      return;
    }
    context.push(
      '/content/exam',
      extra: ExamSessionArgs(
        subjectName: widget.subject.name,
        examType: ExamType.noteQuiz,
        examTitle: item.title,
        chapterId: chapter.id,
        chapterTitle: chapter.title,
        noteId: item.id,
        grade: ref.read(selectedGradeProvider),
      ),
    );
  }

  void _goBack() => context.pop();

  @override
  Widget build(BuildContext context) {
    final isExamPicker = widget.isChapterExam;
    final activeGrade = ref.watch(selectedGradeProvider);
    final accent = widget.subject.iconColor;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StaggeredEntrance(
                    animation: _stagger(0, span: 0.15),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _goBack,
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: AppColors.textSecondary,
                            size: 22,
                          ),
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: widget.subject.iconBg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          clipBehavior: Clip.antiAlias,
                          alignment: Alignment.center,
                          child: isExamPicker
                              ? Icon(
                                  Icons.quiz_rounded,
                                  color: accent,
                                  size: 22,
                                )
                              : SubjectLottieIcon(
                                  subject: widget.subject,
                                  size: widget.subject.lottieAsset != null
                                      ? 36
                                      : 22,
                                  fallbackColor: accent,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.subject.name,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isExamPicker
                                    ? 'Pick a chapter exam'
                                    : 'Notes, cards, or exam for each chapter',
                                style: HomeTextStyles.cardSub.copyWith(
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _SubjectGradeChip(
                          gradeLabel: activeGrade,
                          onTap: _changeGrade,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _StaggeredEntrance(
                    animation: _stagger(2, span: 0.16),
                    child: Row(
                      children: [
                        Text(
                          isExamPicker ? 'EXAMS' : 'CHAPTERS',
                          style: HomeTextStyles.sectionLabel,
                        ),
                        const Spacer(),
                        Text(
                          '${_chapters.length}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  StudyProgressStore.instance,
                  ContentStore.instance,
                ]),
                builder: (context, _) {
                  return _chapters.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              isExamPicker
                                  ? 'No chapter exams published for this subject yet.'
                                  : 'No chapters published for this subject yet.',
                              textAlign: TextAlign.center,
                              style: HomeTextStyles.cardSub.copyWith(
                                fontSize: 14,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    itemCount: _chapters.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final chapter = _chapters[index];
                      return _StaggeredEntrance(
                        animation: _stagger(index + 4),
                        child: isExamPicker
                            ? _ExamChapterTile(
                                chapter: chapter,
                                subject: widget.subject,
                                chapterNumber: index + 1,
                                onTap: () => _openChapterExam(chapter),
                              )
                            : _ChapterAccordion(
                                chapter: chapter,
                                subject: widget.subject,
                                chapterNumber: index + 1,
                                fullAccess: _fullAccess,
                                notesOpen: _openChapterId == chapter.id &&
                                    _activeMode == SubjectStudyMode.notes,
                                onNotesTap: () => _toggleMode(
                                  chapter,
                                  SubjectStudyMode.notes,
                                ),
                                onCardsTap: () {
                                  HapticFeedback.lightImpact();
                                  _openFlashcards(chapter);
                                },
                                onExamTap: () {
                                  HapticFeedback.lightImpact();
                                  _openChapterExam(chapter);
                                },
                                onItemTap: (item) {
                                  _openContent(
                                    chapter,
                                    item,
                                    SubjectStudyMode.notes,
                                  );
                                },
                                onNoteQuizTap: (item) =>
                                    _openNoteQuiz(chapter, item),
                              ),
                      );
                    },
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

class _SubjectGradeChip extends StatelessWidget {
  const _SubjectGradeChip({
    required this.gradeLabel,
    required this.onTap,
  });

  final String gradeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.school_rounded,
                size: 13,
                color: AppColors.accentText.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 5),
              Text(
                gradeLabel.replaceFirst('Grade ', 'G'),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudyProgressBar extends StatelessWidget {
  const _StudyProgressBar({
    required this.progress,
    required this.color,
    this.height = 4,
  });

  final double progress;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          children: [
            Container(color: AppColors.border.withValues(alpha: 0.65)),
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(color: color),
            ),
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
            offset: Offset(0, 14 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Chapter section with compact Notes / Cards / Exam actions.
class _ChapterAccordion extends StatelessWidget {
  const _ChapterAccordion({
    required this.chapter,
    required this.subject,
    required this.chapterNumber,
    required this.fullAccess,
    required this.notesOpen,
    required this.onNotesTap,
    required this.onCardsTap,
    required this.onExamTap,
    required this.onItemTap,
    required this.onNoteQuizTap,
  });

  final SubjectChapter chapter;
  final StudySubject subject;
  final int chapterNumber;
  final bool fullAccess;
  final bool notesOpen;
  final VoidCallback onNotesTap;
  final VoidCallback onCardsTap;
  final VoidCallback onExamTap;
  final ValueChanged<ChapterContentItem> onItemTap;
  final ValueChanged<ChapterContentItem> onNoteQuizTap;

  @override
  Widget build(BuildContext context) {
    final progress = chapterProgressValue(
      chapter.id,
      storedProgress: chapter.progress,
    );
    final percent = (progress * 100).round();
    final accent = subject.iconColor;
    final notes = itemsForChapter(chapter.id, SubjectStudyMode.notes);
    final freeChapter = ContentAccess.isFreePreviewChapter(
      subjectName: subject.name,
      chapterOrder: chapter.order,
      fullAccess: fullAccess,
    );
    final locked = !fullAccess && !freeChapter;
    final titleColor =
        locked ? AppColors.textMuted : AppColors.textPrimary;
    final subtitleColor =
        locked ? AppColors.textMuted.withValues(alpha: 0.75) : null;
    final ringColor = locked ? AppColors.textMuted : accent;
    final surfaceColor = locked
        ? AppColors.bgElevated.withValues(alpha: 0.55)
        : AppColors.bgSurface;
    final borderColor = notesOpen && !locked
        ? AppColors.accent.withValues(alpha: 0.5)
        : locked
            ? AppColors.border.withValues(alpha: 0.45)
            : AppColors.border;

    return Opacity(
      opacity: locked ? 0.62 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: borderColor,
            width: notesOpen && !locked ? 1 : 0.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 46,
                        height: 46,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 46,
                              height: 46,
                              child: CircularProgressIndicator(
                                value: locked
                                    ? 0
                                    : progress.clamp(0.05, 1.0),
                                strokeWidth: 3,
                                backgroundColor: AppColors.border
                                    .withValues(alpha: locked ? 0.35 : 0.55),
                                color: ringColor,
                              ),
                            ),
                            if (locked)
                              const Icon(
                                Icons.lock_rounded,
                                size: 16,
                                color: AppColors.textMuted,
                              )
                            else
                              Text(
                                '$chapterNumber',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: titleColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chapter.title,
                              style: HomeTextStyles.cardTitle.copyWith(
                                fontSize: 14,
                                height: 1.25,
                                color: titleColor,
                              ),
                            ),
                            if (freeChapter && !fullAccess) ...[
                              const SizedBox(height: 6),
                              const FreeContentTag(compact: true),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              locked
                                  ? 'Locked · Subscribe to unlock'
                                  : progress >= 1.0
                                      ? 'Complete · ${chapter.subtitle}'
                                      : freeChapter && !fullAccess
                                          ? '2 lessons free · ${chapter.subtitle}'
                                          : '$percent% · ${chapter.subtitle}',
                              style: HomeTextStyles.cardSub.copyWith(
                                fontSize: 11,
                                color: subtitleColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (!locked && progress >= 1.0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.tealSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Done',
                            style: HomeTextStyles.badge.copyWith(
                              color: AppColors.teal,
                              fontSize: 10,
                            ),
                          ),
                        )
                      else if (locked)
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 16,
                          color: AppColors.textMuted.withValues(alpha: 0.9),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SmallActionChip(
                          label: 'Notes',
                          icon: Icons.menu_book_rounded,
                          selected: notesOpen && !locked,
                          muted: locked,
                          onTap: onNotesTap,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _SmallActionChip(
                          label: 'Cards',
                          icon: Icons.style_rounded,
                          selected: false,
                          muted: locked,
                          onTap: onCardsTap,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _SmallActionChip(
                          label: 'Exam',
                          icon: Icons.quiz_rounded,
                          selected: false,
                          muted: locked,
                          onTap: onExamTap,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: notesOpen
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.accentSubtle.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.55),
                            width: 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: 1 / 3,
                                child: Container(
                                  height: 2,
                                  margin:
                                      const EdgeInsets.only(left: 8, right: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentText
                                        .withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                            _ContentList(
                              mode: SubjectStudyMode.notes,
                              items: notes,
                              subjectName: subject.name,
                              chapterId: chapter.id,
                              fullAccess: fullAccess,
                              accentColor: AppColors.accentText,
                              accentBg: AppColors.accentSoft,
                              onItemTap: onItemTap,
                              onNoteQuizTap: onNoteQuizTap,
                              nested: true,
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallActionChip extends StatelessWidget {
  const _SmallActionChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.muted = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final borderColor = muted
        ? AppColors.border.withValues(alpha: 0.7)
        : selected
            ? AppColors.accentText.withValues(alpha: 0.85)
            : AppColors.accent.withValues(alpha: 0.65);
    final fg = muted
        ? AppColors.textMuted
        : selected
            ? AppColors.accentText.withValues(alpha: 0.95)
            : AppColors.accentText.withValues(alpha: 0.7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: muted
                ? AppColors.bgOverlay.withValues(alpha: 0.35)
                : selected
                    ? AppColors.accentSoft.withValues(alpha: 0.55)
                    : AppColors.accentSubtle.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: borderColor,
              width: selected && !muted ? 1.15 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContentList extends StatelessWidget {
  const _ContentList({
    required this.mode,
    required this.items,
    required this.subjectName,
    required this.chapterId,
    required this.fullAccess,
    required this.accentColor,
    required this.accentBg,
    required this.onItemTap,
    this.onNoteQuizTap,
    this.nested = false,
  });

  final SubjectStudyMode mode;
  final List<ChapterContentItem> items;
  final String subjectName;
  final String chapterId;
  final bool fullAccess;
  final Color accentColor;
  final Color accentBg;
  final ValueChanged<ChapterContentItem> onItemTap;
  final ValueChanged<ChapterContentItem>? onNoteQuizTap;
  final bool nested;

  @override
  Widget build(BuildContext context) {
    final modeColor = mode == SubjectStudyMode.notes
        ? AppColors.teal
        : AppColors.amber;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: nested ? AppColors.bgBase.withValues(alpha: 0.55) : AppColors.bgBase,
        border: nested
            ? const Border(
                top: BorderSide(color: AppColors.border, width: 0.5),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!nested)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Text(
                mode == SubjectStudyMode.notes ? 'Lessons' : 'Decks',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: modeColor,
                ),
              ),
            ),
          if (items.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16, nested ? 12 : 8, 16, 16),
              child: Text(
                mode == SubjectStudyMode.notes
                    ? 'No notes published for this chapter yet.'
                    : 'No flashcard decks for this chapter yet.',
                style: HomeTextStyles.cardSub.copyWith(fontSize: 12),
              ),
            )
          else
            ...List.generate(items.length, (index) {
              final item = items[index];
              final isFree = mode == SubjectStudyMode.notes &&
                  ContentAccess.isNoteFree(
                    subjectName: subjectName,
                    chapterId: chapterId,
                    noteId: item.id,
                    fullAccess: fullAccess,
                  );
              final locked = !fullAccess && !isFree;
              return _ContentItemRow(
                index: index + 1,
                item: item,
                accentColor: accentColor,
                accentBg: accentBg,
                modeColor: modeColor,
                isLast: index == items.length - 1,
                isFree: isFree && !fullAccess,
                isLocked: locked,
                onTap: () => onItemTap(item),
                onQuizTap: onNoteQuizTap != null && !locked
                    ? () => onNoteQuizTap!(item)
                    : null,
              );
            }),
        ],
      ),
    );
  }
}

class _ExamChapterTile extends StatelessWidget {
  const _ExamChapterTile({
    required this.chapter,
    required this.subject,
    required this.chapterNumber,
    required this.onTap,
  });

  final SubjectChapter chapter;
  final StudySubject subject;
  final int chapterNumber;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = chapterProgressValue(
      chapter.id,
      storedProgress: chapter.progress,
    );
    final percent = (progress * 100).round();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: subject.iconBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$chapterNumber',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: subject.iconColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chapter.title,
                      style: HomeTextStyles.cardTitle.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(chapter.subtitle, style: HomeTextStyles.cardSub),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _StudyProgressBar(
                            progress: progress,
                            color: subject.iconColor,
                            height: 4,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          progress >= 1.0 ? 'Ready' : '$percent%',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.infoSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.info,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContentItemRow extends StatelessWidget {
  const _ContentItemRow({
    required this.index,
    required this.item,
    required this.accentColor,
    required this.accentBg,
    required this.modeColor,
    required this.isLast,
    required this.isFree,
    required this.isLocked,
    required this.onTap,
    this.onQuizTap,
  });

  final int index;
  final ChapterContentItem item;
  final Color accentColor;
  final Color accentBg;
  final Color modeColor;
  final bool isLast;
  final bool isFree;
  final bool isLocked;
  final VoidCallback onTap;
  final VoidCallback? onQuizTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : const Border(
                    bottom: BorderSide(color: AppColors.border, width: 0.5),
                  ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
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
                            item.title,
                            style: HomeTextStyles.cardTitle.copyWith(
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (isFree) ...[
                          const SizedBox(width: 6),
                          const FreeContentTag(compact: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(item.subtitle, style: HomeTextStyles.cardSub),
                  ],
                ),
              ),
              if (isLocked)
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                )
              else if (item.isCompleted) ...[
                const Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: AppColors.teal,
                ),
                const SizedBox(width: 8),
              ],
              if (onQuizTap != null) ...[
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onQuizTap,
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.infoSoft,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: AppColors.info.withValues(alpha: 0.35),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        'Quiz',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.info,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (!isLocked)
                Icon(
                  Icons.chevron_right_rounded,
                  color: modeColor.withValues(alpha: 0.8),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

