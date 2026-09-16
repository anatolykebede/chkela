import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/app_providers.dart';
import '../../core/security/content_screenshot_guard.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/home_layout.dart';
import '../../core/theme/home_text_styles.dart';
import '../../data/ai_api.dart';
import '../../data/ai_study_context.dart';
import '../../data/content_access.dart';
import '../../data/exam_data.dart';
import '../../data/exam_questions.dart';
import '../../data/exam_type.dart';
import '../../data/home_mock_data.dart';
import '../../data/study_progress_store.dart';
import '../../data/study_subjects.dart';
import '../../data/subject_chapters.dart';
import '../../features/ai/ai_coach_sheet.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/subscription/subscription_flow.dart';
import '../../widgets/common/exam_confetti.dart';
import '../../widgets/common/exam_sad_result.dart';
import '../../widgets/math_text.dart';

class ExamScreen extends ConsumerStatefulWidget {
  const ExamScreen({
    super.key,
    required this.args,
  });

  final ExamSessionArgs args;

  @override
  ConsumerState<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends ConsumerState<ExamScreen> {
  late List<ExamQuestion> _questions;
  late int _durationMinutes;
  Timer? _timer;
  int _secondsRemaining = 0;

  bool _hasStarted = false;
  int _currentIndex = 0;
  int? _selectedIndex;
  bool _showingFeedback = false;
  bool _sessionComplete = false;
  final ExamAnswerRevealMode _revealMode = ExamAnswerRevealMode.immediate;
  final List<ExamAnswerResult> _results = [];
  final Map<int, int> _answers = {};
  final Set<int> _flaggedQuestions = {};
  DateTime _sessionStartedAt = DateTime.now();
  DateTime? _sessionEndedAt;

  MatricExamScope? _matricScope;
  late String _matricGrade;
  String? _matricChapterId;
  String? _matricChapterTitle;
  bool _showMatricClassify = false;
  String? _selectedMatricPaperTitle;
  ChapterExamMode _chapterExamMode = ChapterExamMode.practice;

  bool get _isMatricSetup => widget.args.needsMatricSetup;
  bool get _isChapterMatricPick => widget.args.isChapterMatricPick;

  ExamSessionArgs get _sessionArgs {
    if (_isMatricSetup) {
      return ExamSessionArgs(
        subjectName: widget.args.subjectName,
        examType: ExamType.matricExam,
        examTitle: widget.args.examTitle,
        matricScope: _matricScope,
        grade:
            _matricScope == MatricExamScope.byGradeChapter ? _matricGrade : null,
        chapterId: _matricScope == MatricExamScope.byGradeChapter
            ? _matricChapterId
            : null,
        chapterTitle: _matricScope == MatricExamScope.byGradeChapter
            ? _matricChapterTitle
            : null,
      );
    }

    if (_isChapterMatricPick &&
        _chapterExamMode == ChapterExamMode.matric &&
        _selectedMatricPaperTitle != null) {
      return ExamSessionArgs(
        subjectName: widget.args.subjectName,
        examType: ExamType.chapterExam,
        examTitle: widget.args.examTitle,
        chapterId: widget.args.chapterId,
        chapterTitle: widget.args.chapterTitle,
        matricPaperTitle: _selectedMatricPaperTitle,
      );
    }

    return widget.args;
  }

  bool get _canStartExam {
    if (_isMatricSetup) {
      if (_matricScope == null) return false;
      if (_matricScope == MatricExamScope.whole) {
        return _questions.isNotEmpty;
      }
      return _matricChapterId != null && _questions.isNotEmpty;
    }
    if (_isChapterMatricPick) {
      if (_chapterExamMode == ChapterExamMode.matric) {
        return _selectedMatricPaperTitle != null && _questions.isNotEmpty;
      }
      return _questions.isNotEmpty;
    }
    return _questions.isNotEmpty;
  }

  void _reloadSession() {
    _questions = questionsForSession(_sessionArgs);
    _durationMinutes = sessionDurationMinutes(_sessionArgs);
    if (!_hasStarted) {
      _secondsRemaining = _durationMinutes * 60;
    }
  }

  @override
  void initState() {
    super.initState();
    ContentScreenshotGuard.enable();
    final preferred = widget.args.grade?.trim().isNotEmpty == true
        ? widget.args.grade!
        : ref.read(selectedGradeProvider);
    _matricGrade = gradeBase(preferred);
    if (widget.args.matricScope != null) {
      _matricScope = widget.args.matricScope;
      final scoped = widget.args.grade?.trim().isNotEmpty == true
          ? widget.args.grade!
          : preferred;
      _matricGrade = gradeBase(scoped);
      _matricChapterId = widget.args.chapterId;
      _matricChapterTitle = widget.args.chapterTitle;
      _showMatricClassify =
          widget.args.matricScope == MatricExamScope.byGradeChapter;
    }
    _reloadSession();
  }

  @override
  void dispose() {
    ContentScreenshotGuard.disable();
    _timer?.cancel();
    super.dispose();
  }

  StudySubject? get _subject {
    for (final subject in studySubjects) {
      if (subject.name == widget.args.subjectName) return subject;
    }
    return null;
  }

  Color get _accent => _subject?.iconColor ?? AppColors.accentText;
  ExamType get _examType => _sessionArgs.examType;
  ExamQuestion get _currentQuestion => _questions[_currentIndex];

  bool get _fullAccess =>
      ref.watch(fullContentAccessProvider).valueOrNull ?? false;

  bool get _currentPaywalled => ContentAccess.isExamQuestionPaywalled(
        _currentIndex,
        fullAccess: _fullAccess,
      );

  bool get _freeNavigation => _revealMode == ExamAnswerRevealMode.atEnd;

  void _persistCurrentAnswer() {
    if (_selectedIndex != null) {
      _answers[_currentIndex] = _selectedIndex!;
    }
  }

  void _requireSubscription() {
    HapticFeedback.lightImpact();
    openSubscriptionFlow(context);
  }

  void _goToQuestion(int index) {
    if (index < 0 || index >= _questions.length || index == _currentIndex) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _persistCurrentAnswer();
      _currentIndex = index;
      _selectedIndex = _answers[index];
      _showingFeedback = false;
    });
  }

  void _toggleFlag() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_flaggedQuestions.contains(_currentIndex)) {
        _flaggedQuestions.remove(_currentIndex);
      } else {
        _flaggedQuestions.add(_currentIndex);
      }
    });
  }

  void _buildFinalResults() {
    _results.clear();
    for (var i = 0; i < _questions.length; i++) {
      _results.add(
        ExamAnswerResult(
          question: _questions[i],
          selectedIndex: _answers[i],
          questionNumber: i + 1,
          flagged: _flaggedQuestions.contains(i),
        ),
      );
    }
  }

  Future<void> _openQuestionNavigator(BuildContext context) async {
    _persistCurrentAnswer();
    final fullAccess = _fullAccess;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ExamQuestionNavigatorSheet(
        total: _questions.length,
        currentIndex: _currentIndex,
        answers: _answers,
        flaggedQuestions: _flaggedQuestions,
        accent: _accent,
        freeQuestionCount: fullAccess
            ? _questions.length
            : ContentAccess.freeExamQuestionCount,
        onSelect: (index) {
          Navigator.pop(context);
          _goToQuestion(index);
        },
        onFinish: () {
          Navigator.pop(context);
          _finishExam();
        },
      ),
    );
  }

  Duration get _sessionDuration {
    final end = _sessionEndedAt ?? DateTime.now();
    return end.difference(_sessionStartedAt);
  }

  void _onStartExamTap() {
    if (!_canStartExam) return;
    _reloadSession();
    if (_questions.isEmpty) {
      setState(() {});
      return;
    }
    _startExam();
  }

  void _startExam() {
    _syncAiContext();
    _sessionStartedAt = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsRemaining <= 0) {
        _finishExam();
        return;
      }
      setState(() => _secondsRemaining--);
    });
    setState(() => _hasStarted = true);
  }

  void _syncAiContext() {
    final args = _sessionArgs;
    final authGrade = ref.read(authProvider).grade?.trim() ?? '';
    final selected = ref.read(selectedGradeProvider);
    final grade = authGrade.isNotEmpty
        ? authGrade
        : (args.grade?.trim().isNotEmpty == true ? args.grade!.trim() : selected);
    ref.read(aiStudyContextProvider.notifier).state = AiStudyContext(
      grade: grade,
      subject: args.subjectName,
      chapter: args.chapterTitle ?? args.examTitle,
      note: args.noteTitle ?? args.examTitle,
    );
  }

  Future<void> _askAiWhy() async {
    final question = _currentQuestion;
    final selected = _selectedIndex;
    if (selected == null) return;
    final labels = ['A', 'B', 'C', 'D'];
    final studentAnswer =
        '${labels[selected]}. ${question.options[selected]}';
    await AiWeakSpotStore.record(
      subject: _sessionArgs.subjectName,
      chapter: _sessionArgs.chapterTitle ?? _sessionArgs.examTitle,
      question: question.question,
      studentAnswer: studentAnswer,
      correctAnswer: question.correctAnswerText,
    );
    if (!mounted) return;
    final api = AiApi();
    await showAiCoachSheet(
      context,
      title: 'Wrong-answer coach',
      load: () => api.coachWrongAnswer(
        question: question.question,
        options: question.options,
        studentAnswer: studentAnswer,
        correctAnswer: question.correctAnswerText,
        explanation: question.descriptionText,
        context: ref.read(aiStudyContextProvider),
      ),
    );
  }

  void _selectOption(int index) {
    if (_sessionComplete || _showingFeedback || _currentPaywalled) return;
    HapticFeedback.selectionClick();

    if (_freeNavigation) {
      setState(() {
        _selectedIndex = index;
        _answers[_currentIndex] = index;
      });
      return;
    }

    // Immediate mode: reveal correct/incorrect as soon as a choice is tapped.
    HapticFeedback.lightImpact();
    final result = ExamAnswerResult(
      question: _currentQuestion,
      selectedIndex: index,
      questionNumber: _currentIndex + 1,
    );
    _results.add(result);
    if (!result.isCorrect) {
      final labels = ['A', 'B', 'C', 'D'];
      unawaited(
        AiWeakSpotStore.record(
          subject: _sessionArgs.subjectName,
          chapter: _sessionArgs.chapterTitle ?? _sessionArgs.examTitle,
          question: _currentQuestion.question,
          studentAnswer: '${labels[index]}. ${_currentQuestion.options[index]}',
          correctAnswer: _currentQuestion.correctAnswerText,
        ),
      );
    }
    setState(() {
      _selectedIndex = index;
      _showingFeedback = true;
    });
  }

  void _submitAnswer() {
    if (_sessionComplete) return;
    if (_currentPaywalled) {
      _requireSubscription();
      return;
    }

    if (_showingFeedback) {
      _advanceQuestion();
      return;
    }

    if (_freeNavigation) {
      HapticFeedback.lightImpact();
      _persistCurrentAnswer();
      if (_currentIndex >= _questions.length - 1) {
        _finishExam();
        return;
      }
      setState(() {
        _currentIndex++;
        _selectedIndex = _answers[_currentIndex];
      });
      return;
    }

    // Immediate mode waits for a choice before Next is enabled.
  }

  void _advanceQuestion() {
    if (_currentIndex >= _questions.length - 1) {
      _finishExam();
      return;
    }

    setState(() {
      _currentIndex++;
      _selectedIndex = null;
      _showingFeedback = false;
    });
  }

  void _finishExam() {
    _timer?.cancel();
    if (_freeNavigation) {
      _persistCurrentAnswer();
      _buildFinalResults();
    }
    setState(() {
      _sessionComplete = true;
      _sessionEndedAt = DateTime.now();
    });
    _saveStudyProgress();
  }

  Future<void> _saveStudyProgress() async {
    final args = _sessionArgs;
    final total = _questions.length;
    if (total <= 0) return;
    final correct = _results.where((r) => r.isCorrect).length;
    final score = (correct / total * 100).round();
    final title = args.examTitle.toLowerCase();
    final isMatric = args.examType == ExamType.matricExam ||
        args.matricScope != null ||
        args.matricPaperTitle != null ||
        title.contains('matric');
    final passMark = isMatric ? 50 : 80;
    if (score < passMark) return;

    if (args.examType == ExamType.chapterExam &&
        args.chapterId != null &&
        args.chapterId!.isNotEmpty) {
      await StudyProgressStore.instance.markChapterExamDone(args.chapterId!);
    }
    if (args.examType == ExamType.noteQuiz &&
        args.noteId != null &&
        args.noteId!.isNotEmpty) {
      await StudyProgressStore.instance.markNoteDone(args.noteId!);
    }
  }

  void _retakeExam() {
    _timer?.cancel();
    setState(() {
      _hasStarted = false;
      _currentIndex = 0;
      _selectedIndex = null;
      _showingFeedback = false;
      _sessionComplete = false;
      _results.clear();
      _answers.clear();
      _flaggedQuestions.clear();
      if (_isMatricSetup) {
        _matricScope = null;
        _matricGrade = gradeBase(
          widget.args.grade ?? ref.read(selectedGradeProvider),
        );
        _matricChapterId = null;
        _matricChapterTitle = null;
        _showMatricClassify = false;
      }
      if (_isChapterMatricPick) {
        _chapterExamMode = ChapterExamMode.practice;
        _selectedMatricPaperTitle = null;
      }
      _reloadSession();
      _sessionStartedAt = DateTime.now();
      _sessionEndedAt = null;
    });
  }

  void _onMatricScopeChanged(MatricExamScope scope) {
    setState(() {
      if (scope == MatricExamScope.byGradeChapter &&
          _matricScope == MatricExamScope.byGradeChapter) {
        _showMatricClassify = !_showMatricClassify;
        return;
      }
      _matricScope = scope;
      _showMatricClassify = scope == MatricExamScope.byGradeChapter;
      if (scope == MatricExamScope.whole) {
        _matricChapterId = null;
        _matricChapterTitle = null;
      }
      _reloadSession();
    });
  }

  void _onMatricGradeChanged(String grade) {
    setState(() => _matricGrade = grade);
  }

  void _onMatricChapterSelected(SubjectChapter chapter) {
    setState(() {
      _matricChapterId = chapter.id;
      _matricChapterTitle = chapter.title;
      _reloadSession();
    });
  }

  void _onChapterMatricPaperSelected(MatricPaperChapterStat paper) {
    setState(() {
      _selectedMatricPaperTitle = paper.title;
      _reloadSession();
    });
    if (_questions.isNotEmpty) _startExam();
  }

  void _onChapterExamModeChanged(ChapterExamMode mode) {
    setState(() {
      if (_chapterExamMode == mode) return;
      _chapterExamMode = mode;
      if (mode == ChapterExamMode.practice) {
        _selectedMatricPaperTitle = null;
      }
      _reloadSession();
    });
  }

  String? get _matricExamId =>
      matricExamIdForPaper(widget.args.subjectName, widget.args.examTitle);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: _sessionComplete
            ? _ExamResultsView(
                args: _sessionArgs,
                results: _results,
                total: _questions.length,
                accent: _accent,
                examType: _examType,
                duration: _sessionDuration,
                onRetake: _retakeExam,
                onDone: () => context.pop(),
              )
            : !_hasStarted
                ? _ExamIntroView(
                    args: _sessionArgs,
                    accent: _accent,
                    examType: _examType,
                    isMatricSetup: _isMatricSetup,
                    isChapterMatricPick: _isChapterMatricPick,
                    matricScope: _matricScope,
                    matricGrade: _matricGrade,
                    matricChapterId: _matricChapterId,
                    showMatricClassify: _showMatricClassify,
                    matricExamId: _matricExamId,
                    chapterId: widget.args.chapterId,
                    chapterExamMode: _chapterExamMode,
                    subjectName: widget.args.subjectName,
                    onMatricScopeChanged: _onMatricScopeChanged,
                    onMatricGradeChanged: _onMatricGradeChanged,
                    onMatricChapterSelected: _onMatricChapterSelected,
                    onChapterMatricPaperSelected: _onChapterMatricPaperSelected,
                    onChapterExamModeChanged: _onChapterExamModeChanged,
                    canStart: _canStartExam,
                    hasQuestions: _questions.isNotEmpty,
                    onStart: _onStartExamTap,
                    onBack: () => context.pop(),
                  )
                : _ExamQuestionView(
                    args: _sessionArgs,
                    question: _currentQuestion,
                    questionIndex: _currentIndex,
                    total: _questions.length,
                    selectedIndex: _selectedIndex,
                    showingFeedback: _showingFeedback,
                    secondsRemaining: _secondsRemaining,
                    accent: _accent,
                    examType: _examType,
                    freeNavigation: _freeNavigation,
                    paywalled: _currentPaywalled,
                    isFlagged: _flaggedQuestions.contains(_currentIndex),
                    onToggleFlag: _freeNavigation ? _toggleFlag : null,
                    onOpenNavigator: _freeNavigation
                        ? () => _openQuestionNavigator(context)
                        : null,
                    onSelect: _selectOption,
                    onSubmit: _submitAnswer,
                    onBack: () => _showExitDialog(context),
                    onAskAiWhy: _askAiWhy,
                    onSubscribe: _requireSubscription,
                  ),
      ),
    );
  }

  Future<void> _showExitDialog(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: Text(
          'Leave exam?',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Your progress will be lost.',
          style: HomeTextStyles.bodySmall.copyWith(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true && context.mounted) context.pop();
  }
}

class _ExamIntroView extends StatelessWidget {
  const _ExamIntroView({
    required this.args,
    required this.accent,
    required this.examType,
    required this.isMatricSetup,
    required this.isChapterMatricPick,
    required this.matricScope,
    required this.matricGrade,
    required this.matricChapterId,
    required this.showMatricClassify,
    required this.matricExamId,
    required this.chapterId,
    required this.chapterExamMode,
    required this.subjectName,
    required this.onMatricScopeChanged,
    required this.onMatricGradeChanged,
    required this.onMatricChapterSelected,
    required this.onChapterMatricPaperSelected,
    required this.onChapterExamModeChanged,
    required this.canStart,
    required this.hasQuestions,
    required this.onStart,
    required this.onBack,
  });

  final ExamSessionArgs args;
  final Color accent;
  final ExamType examType;
  final bool isMatricSetup;
  final bool isChapterMatricPick;
  final MatricExamScope? matricScope;
  final String matricGrade;
  final String? matricChapterId;
  final bool showMatricClassify;
  final String? matricExamId;
  final String? chapterId;
  final ChapterExamMode chapterExamMode;
  final String subjectName;
  final ValueChanged<MatricExamScope> onMatricScopeChanged;
  final ValueChanged<String> onMatricGradeChanged;
  final ValueChanged<SubjectChapter> onMatricChapterSelected;
  final ValueChanged<MatricPaperChapterStat> onChapterMatricPaperSelected;
  final ValueChanged<ChapterExamMode> onChapterExamModeChanged;
  final bool canStart;
  final bool hasQuestions;
  final VoidCallback onStart;
  final VoidCallback onBack;

  List<SubjectChapter> get _chapters => chaptersForSubject(
        subjectName,
        gradeLabel: matricGrade,
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.close, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: examType.iconBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: examType.iconColor.withValues(alpha: 0.25),
                width: 0.5,
              ),
            ),
            child: Icon(examType.icon, color: examType.iconColor, size: 28),
          ),
          const SizedBox(height: 20),
          Text(
            args.examTitle,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${args.subjectName} · ${args.displaySubtitle}',
            style: HomeTextStyles.bodySmall.copyWith(fontSize: 13),
          ),
          if (isMatricSetup) ...[
            const SizedBox(height: 24),
            Text('EXAM SCOPE', style: HomeTextStyles.sectionLabel),
            const SizedBox(height: 10),
            _MatricScopeOption(
              scope: MatricExamScope.whole,
              selected: matricScope == MatricExamScope.whole,
              accent: accent,
              onTap: () => onMatricScopeChanged(MatricExamScope.whole),
            ),
            const SizedBox(height: 8),
            _MatricScopeOption(
              scope: MatricExamScope.byGradeChapter,
              selected: matricScope == MatricExamScope.byGradeChapter,
              accent: accent,
              showChevron: true,
              expanded: showMatricClassify,
              onTap: () =>
                  onMatricScopeChanged(MatricExamScope.byGradeChapter),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: showMatricClassify
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        Text('SELECT GRADE', style: HomeTextStyles.sectionLabel),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: gradesPreferring(matricGrade).map((grade) {
                            final selected = matricGrade == grade;
                            return GestureDetector(
                              onTap: () => onMatricGradeChanged(grade),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? accent.withValues(alpha: 0.12)
                                      : AppColors.bgSurface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: selected
                                        ? accent.withValues(alpha: 0.4)
                                        : AppColors.border,
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  grade.replaceAll('Grade ', 'Gr '),
                                  style: HomeTextStyles.badge.copyWith(
                                    color: selected
                                        ? accent
                                        : AppColors.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'SELECT CHAPTER · ${matricYearFromTitle(args.examTitle)}',
                          style: HomeTextStyles.sectionLabel,
                        ),
                        const SizedBox(height: 8),
                        ...List.generate(_chapters.length, (index) {
                          final chapter = _chapters[index];
                          final isLast = index == _chapters.length - 1;
                          final count = matricExamId != null
                              ? matricChapterQuestionCount(
                                  examId: matricExamId!,
                                  chapterId: chapter.id,
                                  subjectName: subjectName,
                                )
                              : 0;
                          return _MatricChapterOption(
                            chapter: chapter,
                            questionCount: count,
                            year: matricYearFromTitle(args.examTitle),
                            accent: accent,
                            selected: matricChapterId == chapter.id,
                            isLast: isLast,
                            onTap: () => onMatricChapterSelected(chapter),
                          );
                        }),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
          if (isChapterMatricPick && chapterId != null) ...[
            const SizedBox(height: 24),
            Text('EXAM TYPE', style: HomeTextStyles.sectionLabel),
            const SizedBox(height: 10),
            _ChapterExamModeOption(
              mode: ChapterExamMode.practice,
              selected: chapterExamMode == ChapterExamMode.practice,
              accent: accent,
              onTap: () => onChapterExamModeChanged(ChapterExamMode.practice),
            ),
            const SizedBox(height: 8),
            _ChapterExamModeOption(
              mode: ChapterExamMode.matric,
              selected: chapterExamMode == ChapterExamMode.matric,
              accent: accent,
              onTap: () => onChapterExamModeChanged(ChapterExamMode.matric),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: chapterExamMode == ChapterExamMode.matric
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          'MATRIC BY YEAR',
                          style: HomeTextStyles.sectionLabel,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Past matric questions in this chapter',
                          style: HomeTextStyles.bodySmall.copyWith(fontSize: 11),
                        ),
                        const SizedBox(height: 12),
                        ...matricPapersForChapter(
                          subjectName: subjectName,
                          chapterId: chapterId!,
                        ).map(
                          (paper) => _ChapterMatricYearTile(
                            paper: paper,
                            accent: accent,
                            onTap: () => onChapterMatricPaperSelected(paper),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
          const SizedBox(height: 28),
          if (!hasQuestions)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'No questions published for this exam yet.',
                textAlign: TextAlign.center,
                style: HomeTextStyles.bodySmall.copyWith(fontSize: 12),
              ),
            ),
          GestureDetector(
            onTap: canStart ? onStart : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: canStart
                    ? AppColors.bgElevated
                    : AppColors.bgSurface,
                borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
                border: Border.all(
                  color: canStart
                      ? accent.withValues(alpha: 0.35)
                      : AppColors.border,
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Text(
                  examType == ExamType.noteQuiz ? 'Start quiz' : 'Start exam',
                  style: HomeTextStyles.badge.copyWith(
                    color: canStart ? accent : AppColors.textMuted,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _MatricScopeOption extends StatelessWidget {
  const _MatricScopeOption({
    required this.scope,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.showChevron = false,
    this.expanded = false,
  });

  final MatricExamScope scope;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final bool showChevron;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.08) : AppColors.bgElevated,
          borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.4) : AppColors.border,
            width: selected ? 1 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.12)
                    : AppColors.bgSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                scope.icon,
                size: 18,
                color: selected ? accent : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scope.title,
                    style: HomeTextStyles.cardTitle.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(scope.subtitle, style: HomeTextStyles.cardSub),
                ],
              ),
            ),
            if (showChevron)
              AnimatedRotation(
                turns: expanded ? 0.25 : 0,
                duration: const Duration(milliseconds: 220),
                child: Icon(
                  Icons.chevron_right,
                  color: expanded ? accent : AppColors.textMuted,
                  size: 18,
                ),
              )
            else
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? accent : AppColors.textMuted,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _ChapterExamModeOption extends StatelessWidget {
  const _ChapterExamModeOption({
    required this.mode,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final ChapterExamMode mode;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.08) : AppColors.bgElevated,
          borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.4) : AppColors.border,
            width: selected ? 1 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.12)
                    : AppColors.bgSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                mode.icon,
                size: 18,
                color: selected ? accent : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.title,
                    style: HomeTextStyles.cardTitle.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(mode.subtitle, style: HomeTextStyles.cardSub),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? accent : AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _MatricChapterOption extends StatelessWidget {
  const _MatricChapterOption({
    required this.chapter,
    required this.questionCount,
    required this.year,
    required this.accent,
    required this.selected,
    required this.isLast,
    required this.onTap,
  });

  final SubjectChapter chapter;
  final int questionCount;
  final String year;
  final Color accent;
  final bool selected;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.08) : AppColors.bgElevated,
          borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.4) : AppColors.border,
            width: selected ? 1 : 0.5,
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
                    chapter.title,
                    style: HomeTextStyles.cardTitle.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$questionCount questions · $year paper',
                    style: HomeTextStyles.bodySmall.copyWith(
                      fontSize: 10,
                      color: selected ? accent : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: accent.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: Text(
                '$questionCount',
                style: HomeTextStyles.badge.copyWith(
                  color: accent,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? accent : AppColors.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterMatricYearTile extends StatelessWidget {
  const _ChapterMatricYearTile({
    required this.paper,
    required this.accent,
    required this.onTap,
  });

  final MatricPaperChapterStat paper;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.amberSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.amber.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    paper.year,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.amber,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paper.title,
                      style: HomeTextStyles.cardTitle.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${paper.questionCount} past matric questions in this chapter',
                      style: HomeTextStyles.bodySmall.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  '${paper.questionCount}',
                  style: HomeTextStyles.badge.copyWith(
                    color: accent,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.play_arrow_rounded, color: accent, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamQuestionView extends StatelessWidget {
  const _ExamQuestionView({
    required this.args,
    required this.question,
    required this.questionIndex,
    required this.total,
    required this.selectedIndex,
    required this.showingFeedback,
    required this.secondsRemaining,
    required this.accent,
    required this.examType,
    required this.onSelect,
    required this.onSubmit,
    required this.onBack,
    this.freeNavigation = false,
    this.paywalled = false,
    this.isFlagged = false,
    this.onToggleFlag,
    this.onOpenNavigator,
    this.onAskAiWhy,
    this.onSubscribe,
  });

  final ExamSessionArgs args;
  final ExamQuestion question;
  final int questionIndex;
  final int total;
  final int? selectedIndex;
  final bool showingFeedback;
  final int secondsRemaining;
  final Color accent;
  final ExamType examType;
  final bool freeNavigation;
  final bool paywalled;
  final bool isFlagged;
  final VoidCallback? onToggleFlag;
  final VoidCallback? onOpenNavigator;
  final ValueChanged<int> onSelect;
  final VoidCallback onSubmit;
  final VoidCallback onBack;
  final VoidCallback? onAskAiWhy;
  final VoidCallback? onSubscribe;

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isLast = questionIndex >= total - 1;
    final lowTime = secondsRemaining < 60;
    final isCorrect = showingFeedback &&
        selectedIndex != null &&
        selectedIndex == question.correctIndex;
    final labels = ['A', 'B', 'C', 'D'];
    final canSubmit = freeNavigation
        ? true
        : showingFeedback;
    final submitLabel = freeNavigation
        ? (isLast ? 'Finish exam' : 'Next question')
        : (isLast
            ? (showingFeedback ? 'Finish exam' : 'Select an answer')
            : (showingFeedback ? 'Next question' : 'Select an answer'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      args.examTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      args.displaySubtitle,
                      style: HomeTextStyles.bodySmall.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
              if (freeNavigation && onToggleFlag != null)
                IconButton(
                  onPressed: onToggleFlag,
                  icon: Icon(
                    isFlagged ? Icons.flag : Icons.outlined_flag,
                    color: isFlagged ? AppColors.amber : AppColors.textSecondary,
                    size: 22,
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: lowTime ? AppColors.dangerSoft : AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: lowTime
                        ? AppColors.danger.withValues(alpha: 0.3)
                        : AppColors.border,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: lowTime ? AppColors.danger : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(secondsRemaining),
                      style: HomeTextStyles.badge.copyWith(
                        color: lowTime ? AppColors.danger : AppColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GestureDetector(
            onTap: onOpenNavigator,
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                _SegmentedProgress(
                  total: total,
                  current: questionIndex,
                  accent: accent,
                ),
                if (freeNavigation && onOpenNavigator != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.grid_view_rounded,
                        size: 14,
                        color: accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Jump to question',
                        style: HomeTextStyles.badge.copyWith(
                          color: accent,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          paywalled
              ? 'Question ${questionIndex + 1} of $total · Locked'
              : 'Question ${questionIndex + 1} of $total',
          textAlign: TextAlign.center,
          style: HomeTextStyles.bodySmall.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ImageFiltered(
                  imageFilter: paywalled
                      ? ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7)
                      : ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                  child: IgnorePointer(
                    ignoring: paywalled,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: MathText(
                    question.question,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(question.options.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _OptionTile(
                      label: labels[index],
                      text: question.options[index],
                      isSelected: selectedIndex == index,
                      accent: accent,
                      revealCorrect: showingFeedback &&
                          index == question.correctIndex,
                      revealWrong: showingFeedback &&
                          selectedIndex == index &&
                          index != question.correctIndex,
                      onTap: showingFeedback || paywalled ? () {} : () => onSelect(index),
                    ),
                  );
                }),
                if (showingFeedback) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isCorrect ? AppColors.tealSoft : AppColors.dangerSoft,
                      borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
                      border: Border.all(
                        color: isCorrect
                            ? AppColors.teal.withValues(alpha: 0.3)
                            : AppColors.danger.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isCorrect ? Icons.check_circle : Icons.cancel,
                              color: isCorrect ? AppColors.teal : AppColors.danger,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isCorrect ? 'Correct!' : 'Incorrect',
                              style: HomeTextStyles.badge.copyWith(
                                color:
                                    isCorrect ? AppColors.teal : AppColors.danger,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Answer: ${question.correctAnswerText}',
                          style: HomeTextStyles.bodySmall.copyWith(
                            fontSize: 12,
                            color: AppColors.teal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'DESCRIPTION',
                          style: HomeTextStyles.sectionLabel.copyWith(fontSize: 9),
                        ),
                        const SizedBox(height: 4),
                        MathText(
                          question.descriptionText,
                          style: HomeTextStyles.bodySmall.copyWith(
                            fontSize: 11,
                            height: 1.45,
                          ),
                        ),
                        if (!isCorrect && onAskAiWhy != null) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: onAskAiWhy,
                              icon: const Icon(Icons.auto_awesome, size: 16),
                              label: const Text('Ask AI why'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accentText,
                                side: BorderSide(
                                  color: AppColors.accentText.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                      ],
                    ),
                  ),
                ),
              ),
              if (paywalled)
                Positioned.fill(
                  child: _ExamPaywallOverlay(
                    accent: accent,
                    onSubscribe: onSubscribe ?? () {},
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: GestureDetector(
            onTap: paywalled
                ? onSubscribe
                : (canSubmit ? onSubmit : null),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: paywalled || canSubmit
                    ? AppColors.bgElevated
                    : AppColors.bgSurface,
                borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
                border: Border.all(
                  color: paywalled || canSubmit
                      ? accent.withValues(alpha: 0.35)
                      : AppColors.border,
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Text(
                  paywalled ? 'Unlock with subscription' : submitLabel,
                  style: HomeTextStyles.badge.copyWith(
                    color: paywalled || canSubmit
                        ? accent
                        : AppColors.textMuted,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}


class _ExamPaywallOverlay extends StatelessWidget {
  const _ExamPaywallOverlay({
    required this.accent,
    required this.onSubscribe,
  });

  final Color accent;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      color: AppColors.bgBase.withValues(alpha: 0.28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent.withValues(alpha: 0.4),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.lock_rounded, color: accent, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              'Continue with a subscription',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Questions 1–${ContentAccess.freeExamQuestionCount} are free. Unlock the rest of this exam to keep practicing.',
              textAlign: TextAlign.center,
              style: HomeTextStyles.bodySmall.copyWith(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onSubscribe,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('View subscription plans'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.text,
    required this.isSelected,
    required this.accent,
    required this.onTap,
    this.revealCorrect = false,
    this.revealWrong = false,
  });

  final String label;
  final String text;
  final bool isSelected;
  final Color accent;
  final VoidCallback onTap;
  final bool revealCorrect;
  final bool revealWrong;

  Color get _borderColor {
    if (revealCorrect) return AppColors.teal.withValues(alpha: 0.45);
    if (revealWrong) return AppColors.danger.withValues(alpha: 0.45);
    if (isSelected) return accent.withValues(alpha: 0.45);
    return AppColors.border;
  }

  Color get _bgColor {
    if (revealCorrect) return AppColors.tealSoft;
    if (revealWrong) return AppColors.dangerSoft;
    if (isSelected) return accent.withValues(alpha: 0.08);
    return AppColors.bgElevated;
  }

  Color get _labelColor {
    if (revealCorrect) return AppColors.teal;
    if (revealWrong) return AppColors.danger;
    if (isSelected) return accent;
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
          border: Border.all(
            color: _borderColor,
            width: revealCorrect || revealWrong || isSelected ? 1 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _labelColor.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _labelColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MathText(
                text,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamQuestionNavigatorSheet extends StatelessWidget {
  const _ExamQuestionNavigatorSheet({
    required this.total,
    required this.currentIndex,
    required this.answers,
    required this.flaggedQuestions,
    required this.accent,
    required this.onSelect,
    required this.onFinish,
    this.freeQuestionCount = 999,
  });

  final int total;
  final int currentIndex;
  final Map<int, int> answers;
  final Set<int> flaggedQuestions;
  final Color accent;
  final ValueChanged<int> onSelect;
  final VoidCallback onFinish;
  final int freeQuestionCount;

  @override
  Widget build(BuildContext context) {
    final answeredCount = answers.length;
    final flaggedCount = flaggedQuestions.length;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All questions',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$answeredCount answered · $flaggedCount flagged',
                          style: HomeTextStyles.bodySmall.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(total, (index) {
                    final isCurrent = index == currentIndex;
                    final isAnswered = answers.containsKey(index);
                    final isFlagged = flaggedQuestions.contains(index);
                    final isLocked = index >= freeQuestionCount;

                    return GestureDetector(
                      onTap: () => onSelect(index),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isLocked
                              ? AppColors.bgOverlay.withValues(alpha: 0.45)
                              : isCurrent
                                  ? accent.withValues(alpha: 0.12)
                                  : isAnswered
                                      ? accent.withValues(alpha: 0.06)
                                      : AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isLocked
                                ? AppColors.border.withValues(alpha: 0.55)
                                : isCurrent
                                    ? accent.withValues(alpha: 0.5)
                                    : isAnswered
                                        ? accent.withValues(alpha: 0.25)
                                        : AppColors.border,
                            width: isCurrent && !isLocked ? 1 : 0.5,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              '${index + 1}',
                              style: HomeTextStyles.badge.copyWith(
                                color: isLocked
                                    ? AppColors.textMuted
                                    : isCurrent || isAnswered
                                        ? accent
                                        : AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            if (isLocked)
                              const Positioned(
                                top: 6,
                                right: 6,
                                child: Icon(
                                  Icons.lock_rounded,
                                  size: 10,
                                  color: AppColors.textMuted,
                                ),
                              )
                            else if (isFlagged)
                              const Positioned(
                                top: 6,
                                right: 6,
                                child: Icon(
                                  Icons.flag,
                                  size: 10,
                                  color: AppColors.amber,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: GestureDetector(
                onTap: onFinish,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.35),
                      width: 0.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Finish exam',
                      style: HomeTextStyles.badge.copyWith(
                        color: accent,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedProgress extends StatelessWidget {
  const _SegmentedProgress({
    required this.total,
    required this.current,
    required this.accent,
  });

  final int total;
  final int current;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (index) {
        final isPast = index < current;
        final isCurrent = index == current;
        return Expanded(
          child: Container(
            height: 3,
            margin: EdgeInsets.only(right: index < total - 1 ? 4 : 0),
            decoration: BoxDecoration(
              color: isPast || isCurrent ? accent : AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class _ExamResultsView extends StatefulWidget {
  const _ExamResultsView({
    required this.args,
    required this.results,
    required this.total,
    required this.accent,
    required this.examType,
    required this.duration,
    required this.onRetake,
    required this.onDone,
  });

  final ExamSessionArgs args;
  final List<ExamAnswerResult> results;
  final int total;
  final Color accent;
  final ExamType examType;
  final Duration duration;
  final VoidCallback onRetake;
  final VoidCallback onDone;

  @override
  State<_ExamResultsView> createState() => _ExamResultsViewState();
}

class _ExamResultsViewState extends State<_ExamResultsView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ringController;
  late final Animation<double> _ringAnimation;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _ringAnimation = CurvedAnimation(
      parent: _ringController,
      curve: Curves.easeOutCubic,
    );
    _ringController.forward();
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

  int get _correctCount => widget.results.where((r) => r.isCorrect).length;
  int get _wrongCount => widget.results.where((r) => !r.isCorrect).length;
  int get _score =>
      widget.total > 0 ? (_correctCount / widget.total * 100).round() : 0;

  /// Matric papers pass at 50%; other exams keep the 80% bar.
  bool get _isMatricExam {
    if (widget.examType == ExamType.matricExam) return true;
    if (widget.args.matricScope != null) return true;
    if (widget.args.matricPaperTitle != null) return true;
    final title = widget.args.examTitle.toLowerCase();
    return title.contains('matric');
  }

  int get _passMark => _isMatricExam ? 50 : 80;

  bool get _passed => _score >= _passMark;

  bool get _celebrateScore => _passed;

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final isNoteQuiz = widget.examType == ExamType.noteQuiz;

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedBuilder(
                      animation: _ringAnimation,
                      builder: (context, child) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.bgElevated,
                            borderRadius:
                                BorderRadius.circular(HomeLayout.cardRadius),
                            border: Border.all(
                              color: AppColors.border,
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              _CircleRing(
                                size: 104,
                                strokeWidth: 7,
                                progress: (_score / 100) * _ringAnimation.value,
                                color: widget.accent,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${(_score * _ringAnimation.value).round()}%',
                                      style: GoogleFonts.inter(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: widget.accent,
                                      ),
                                    ),
                                    Text(
                                      'Score',
                                      style: HomeTextStyles.bodySmall
                                          .copyWith(fontSize: 9),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  children: [
                                    _DetailStatRow(
                                      icon: Icons.timer_outlined,
                                      label: 'Time',
                                      value: _formatDuration(widget.duration),
                                    ),
                                    const SizedBox(height: 8),
                                    _DetailStatRow(
                                      icon: Icons.check_circle_outline,
                                      label: 'Correct',
                                      value: '$_correctCount / ${widget.total}',
                                    ),
                                    const SizedBox(height: 8),
                                    _DetailStatRow(
                                      icon: Icons.close_rounded,
                                      label: 'Incorrect',
                                      value: '$_wrongCount',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ResultMetricChip(
                            label: 'Correct',
                            value: '$_correctCount',
                            color: AppColors.teal,
                            icon: Icons.check_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ResultMetricChip(
                            label: 'Wrong',
                            value: '$_wrongCount',
                            color: AppColors.danger,
                            icon: Icons.close_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ResultMetricChip(
                            label: _passed ? 'Passed' : 'Failed',
                            value: '$_passMark%',
                            color: _passed ? AppColors.teal : AppColors.danger,
                            icon: _passed
                                ? Icons.verified_rounded
                                : Icons.flag_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text(
                          'ANSWER REVIEW',
                          style: HomeTextStyles.sectionLabel,
                        ),
                        const Spacer(),
                        Text(
                          '$_correctCount right · $_wrongCount wrong',
                          style: HomeTextStyles.badge.copyWith(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...widget.results.map(
                      (result) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _AnswerReviewTile(result: result),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              decoration: BoxDecoration(
                color: AppColors.bgSurface.withValues(alpha: 0.96),
                border: const Border(
                  top: BorderSide(color: AppColors.border, width: 0.5),
                ),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: widget.onRetake,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: widget.accent.withValues(alpha: 0.14),
                        borderRadius:
                            BorderRadius.circular(HomeLayout.cardRadius),
                        border: Border.all(
                          color: widget.accent.withValues(alpha: 0.4),
                          width: 0.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          isNoteQuiz ? 'Retake quiz' : 'Retake exam',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: widget.accent,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: widget.onDone,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.bgElevated,
                        borderRadius:
                            BorderRadius.circular(HomeLayout.cardRadius),
                        border: Border.all(color: AppColors.border, width: 0.5),
                      ),
                      child: Center(
                        child: Text(
                          'Done',
                          style: HomeTextStyles.badge.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_celebrateScore)
          const ExamConfettiCelebration()
        else
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 156,
            child: ExamSadResultLottie(),
          ),
      ],
    );
  }
}

class _ResultMetricChip extends StatelessWidget {
  const _ResultMetricChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.22),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: HomeTextStyles.badge.copyWith(
              fontSize: 8,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerReviewTile extends StatelessWidget {
  const _AnswerReviewTile({required this.result});

  final ExamAnswerResult result;

  @override
  Widget build(BuildContext context) {
    final labels = ['A', 'B', 'C', 'D'];
    final statusColor = result.isSkipped
        ? AppColors.textMuted
        : result.isCorrect
            ? AppColors.teal
            : AppColors.danger;
    final statusBg = result.isSkipped
        ? AppColors.bgSurface
        : result.isCorrect
            ? AppColors.tealSoft
            : AppColors.dangerSoft;
    final statusLabel = result.isSkipped
        ? 'Skipped'
        : result.isCorrect
            ? 'Correct'
            : 'Wrong';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.22),
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '${result.questionNumber}',
              style: HomeTextStyles.badge.copyWith(
                fontSize: 11,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        result.question.question,
                        style: HomeTextStyles.cardTitle.copyWith(fontSize: 12),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel,
                        style: HomeTextStyles.badge.copyWith(
                          color: statusColor,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    if (result.flagged) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.flag, size: 13, color: AppColors.amber),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                if (result.isSkipped)
                  Text(
                    'Not answered',
                    style: HomeTextStyles.bodySmall.copyWith(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  )
                else ...[
                  Text(
                    'You: ${labels[result.selectedIndex!]}. ${result.question.options[result.selectedIndex!]}',
                    style: HomeTextStyles.bodySmall.copyWith(
                      fontSize: 11,
                      color: result.isCorrect ? AppColors.teal : AppColors.danger,
                    ),
                  ),
                  if (!result.isCorrect) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Answer: ${result.question.correctAnswerText}',
                      style: HomeTextStyles.bodySmall.copyWith(
                        fontSize: 11,
                        color: AppColors.teal,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 8),
                Text(
                  result.question.descriptionText,
                  style: HomeTextStyles.bodySmall.copyWith(
                    fontSize: 10,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailStatRow extends StatelessWidget {
  const _DetailStatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text(label, style: HomeTextStyles.bodySmall.copyWith(fontSize: 10)),
          const Spacer(),
          Text(
            value,
            style: HomeTextStyles.badge.copyWith(
              color: AppColors.textPrimary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleRing extends StatelessWidget {
  const _CircleRing({
    required this.size,
    required this.strokeWidth,
    required this.progress,
    required this.color,
    required this.child,
  });

  final double size;
  final double strokeWidth;
  final double progress;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          color: color,
          strokeWidth: strokeWidth,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final track = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}
