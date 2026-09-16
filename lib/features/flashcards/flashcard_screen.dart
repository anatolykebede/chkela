import 'dart:math' as math;
import 'dart:ui' as ui;

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
import '../../data/content_access.dart';
import '../../data/flashcard_data.dart';
import '../../data/study_progress_store.dart';
import '../../data/study_subjects.dart';
import '../../features/subscription/subscription_flow.dart';
import '../../widgets/common/exam_confetti.dart';
import '../../widgets/common/exam_sad_result.dart';
import '../../widgets/math_text.dart';

class FlashcardScreen extends ConsumerStatefulWidget {
  const FlashcardScreen({
    super.key,
    required this.args,
  });

  final FlashcardSessionArgs args;

  @override
  ConsumerState<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends ConsumerState<FlashcardScreen>
    with SingleTickerProviderStateMixin {
  late final List<FlashCard> _cards;
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;

  int _currentIndex = 0;
  int _knownCount = 0;
  int _againCount = 0;
  bool _isFlipped = false;
  bool _sessionComplete = false;
  final List<FlashcardReviewResult> _results = [];
  DateTime _sessionStartedAt = DateTime.now();
  DateTime? _sessionEndedAt;

  @override
  void initState() {
    super.initState();
    ContentScreenshotGuard.enable();
    _cards = flashcardsForChapter(
      widget.args.chapterId,
      widget.args.chapterTitle,
      deckId: widget.args.deckId,
    );
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    ContentScreenshotGuard.disable();
    _flipController.dispose();
    super.dispose();
  }

  StudySubject? get _subject {
    for (final subject in studySubjects) {
      if (subject.name == widget.args.subjectName) return subject;
    }
    return null;
  }

  Color get _accent => _subject?.iconColor ?? AppColors.accentText;

  FlashCard get _currentCard => _cards[_currentIndex];

  bool get _fullAccess =>
      ref.watch(fullContentAccessProvider).valueOrNull ?? false;

  bool get _paywalled => ContentAccess.isFlashcardPaywalled(
        _currentIndex,
        fullAccess: _fullAccess,
      );

  String get _shortChapter {
    final title = widget.args.chapterTitle;
    final colonIndex = title.indexOf(':');
    if (colonIndex != -1 && colonIndex < title.length - 2) {
      return title.substring(colonIndex + 2);
    }
    return title;
  }

  void _requireSubscription() {
    HapticFeedback.lightImpact();
    openSubscriptionFlow(context);
  }

  void _flipCard() {
    if (_sessionComplete || _isFlipped || _paywalled) return;
    HapticFeedback.lightImpact();
    _flipController.forward();
    setState(() => _isFlipped = true);
  }

  void _rateCard({required bool known}) {
    if (_sessionComplete || !_isFlipped || _paywalled) return;
    HapticFeedback.selectionClick();

    if (known) {
      _knownCount++;
    } else {
      _againCount++;
    }

    _results.add(
      FlashcardReviewResult(
        card: _currentCard,
        cardNumber: _currentIndex + 1,
        known: known,
      ),
    );

    if (_currentIndex >= _cards.length - 1) {
      setState(() {
        _sessionComplete = true;
        _sessionEndedAt = DateTime.now();
      });
      _saveStudyProgress();
      return;
    }

    _flipController.reset();
    setState(() {
      _currentIndex++;
      _isFlipped = false;
    });
  }

  void _restartSession() {
    _flipController.reset();
    setState(() {
      _currentIndex = 0;
      _knownCount = 0;
      _againCount = 0;
      _isFlipped = false;
      _sessionComplete = false;
      _results.clear();
      _sessionStartedAt = DateTime.now();
      _sessionEndedAt = null;
    });
  }

  Future<void> _saveStudyProgress() async {
    final deckId = widget.args.deckId;
    if (deckId != null && deckId.isNotEmpty) {
      await StudyProgressStore.instance.markDeckDone(deckId);
    } else {
      await StudyProgressStore.instance
          .markChapterFlashcardsDone(widget.args.chapterId);
    }
  }

  Duration get _sessionDuration {
    final end = _sessionEndedAt ?? DateTime.now();
    return end.difference(_sessionStartedAt);
  }

  @override
  Widget build(BuildContext context) {
    if (_cards.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.bgBase,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(
                chapter: _shortChapter,
                subject: widget.args.subjectName,
                onBack: () => context.pop(),
              ),
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No flashcards published for this chapter yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
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

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: _sessionComplete
            ? _DoneView(
                knownCount: _knownCount,
                againCount: _againCount,
                total: _cards.length,
                accent: _accent,
                subject: widget.args.subjectName,
                chapter: _shortChapter,
                duration: _sessionDuration,
                results: _results,
                onRestart: _restartSession,
                onDone: () => context.pop(),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(
                    chapter: _shortChapter,
                    subject: widget.args.subjectName,
                    onBack: () => context.pop(),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SegmentedProgress(
                      total: _cards.length,
                      current: _currentIndex,
                      accent: _accent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _paywalled
                        ? 'Card ${_currentIndex + 1} of ${_cards.length} · Locked'
                        : 'Card ${_currentIndex + 1} of ${_cards.length}',
                    textAlign: TextAlign.center,
                    style: HomeTextStyles.bodySmall.copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Stack(
                        children: [
                          ImageFiltered(
                            imageFilter: _paywalled
                                ? ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7)
                                : ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                            child: IgnorePointer(
                              ignoring: _paywalled,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: GestureDetector(
                                  key: ValueKey(_currentIndex),
                                  onTap: _isFlipped || _paywalled
                                      ? null
                                      : _flipCard,
                                  child: AnimatedBuilder(
                                    animation: _flipAnimation,
                                    builder: (context, child) {
                                      final angle =
                                          _flipAnimation.value * math.pi;
                                      final showFront =
                                          _flipAnimation.value < 0.5;
                                      return Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.identity()
                                          ..setEntry(3, 2, 0.001)
                                          ..rotateY(angle),
                                        child: showFront
                                            ? _CardSide(
                                                side: _CardSideType.question,
                                                text: _currentCard.question,
                                                accent: _accent,
                                              )
                                            : Transform(
                                                alignment: Alignment.center,
                                                transform: Matrix4.identity()
                                                  ..rotateY(math.pi),
                                                child: _CardSide(
                                                  side: _CardSideType.answer,
                                                  text: _currentCard.answer,
                                                  accent: _accent,
                                                ),
                                              ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_paywalled)
                            Positioned.fill(
                              child: _FlashcardPaywallOverlay(
                                accent: _accent,
                                onSubscribe: _requireSubscription,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_paywalled) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _requireSubscription,
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Unlock with subscription'),
                        ),
                      ),
                    ),
                  ] else if (!_isFlipped) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Tap the card to reveal',
                      textAlign: TextAlign.center,
                      style: HomeTextStyles.bodySmall.copyWith(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: _RateButton(
                              label: "Don't know",
                              icon: Icons.close,
                              color: AppColors.danger,
                              onTap: () => _rateCard(known: false),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _RateButton(
                              label: 'Know it',
                              icon: Icons.check,
                              color: AppColors.teal,
                              onTap: () => _rateCard(known: true),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
      ),
    );
  }
}

class _FlashcardPaywallOverlay extends StatelessWidget {
  const _FlashcardPaywallOverlay({
    required this.accent,
    required this.onSubscribe,
  });

  final Color accent;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: AppColors.bgBase.withValues(alpha: 0.22),
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
              'The first ${ContentAccess.freeFlashcardCount} cards are free. Unlock the rest of this deck to keep reviewing.',
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

enum _CardSideType { question, answer }

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.chapter,
    required this.subject,
    required this.onBack,
  });

  final String chapter;
  final String subject;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 22),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  chapter,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subject,
                  style: HomeTextStyles.bodySmall.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
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

class _CardSide extends StatelessWidget {
  const _CardSide({
    required this.side,
    required this.text,
    required this.accent,
  });

  final _CardSideType side;
  final String text;
  final Color accent;

  bool get _isQuestion => side == _CardSideType.question;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      decoration: BoxDecoration(
        color: _isQuestion ? AppColors.bgElevated : AppColors.bgOverlay,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isQuestion ? AppColors.border : accent.withValues(alpha: 0.35),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _isQuestion ? 'Question' : 'Answer',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.12,
              color: _isQuestion ? AppColors.textMuted : accent,
            ),
          ),
          const SizedBox(height: 28),
          MathText(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: _isQuestion ? 22 : 19,
              fontWeight: FontWeight.w600,
              height: 1.5,
              letterSpacing: -0.3,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RateButton extends StatelessWidget {
  const _RateButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: HomeTextStyles.badge.copyWith(
                color: color,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoneView extends StatefulWidget {
  const _DoneView({
    required this.knownCount,
    required this.againCount,
    required this.total,
    required this.accent,
    required this.subject,
    required this.chapter,
    required this.duration,
    required this.results,
    required this.onRestart,
    required this.onDone,
  });

  final int knownCount;
  final int againCount;
  final int total;
  final Color accent;
  final String subject;
  final String chapter;
  final Duration duration;
  final List<FlashcardReviewResult> results;
  final VoidCallback onRestart;
  final VoidCallback onDone;

  @override
  State<_DoneView> createState() => _DoneViewState();
}

class _DoneViewState extends State<_DoneView> with SingleTickerProviderStateMixin {
  late final AnimationController _ringController;
  late final Animation<double> _ringAnimation;
  _ReviewFilter _filter = _ReviewFilter.all;

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

  String get _feedbackMessage {
    final mastery = widget.total > 0
        ? (widget.knownCount / widget.total * 100).round()
        : 0;
    if (mastery == 100) return 'Perfect — you nailed every card!';
    if (mastery >= 80) return 'Strong session. Keep this momentum.';
    if (mastery >= 50) return 'Good effort. Review the missed cards below.';
    return 'Focus on the cards marked for review.';
  }

  List<FlashcardReviewResult> get _filteredResults {
    switch (_filter) {
      case _ReviewFilter.all:
        return widget.results;
      case _ReviewFilter.known:
        return widget.results.where((r) => r.known).toList();
      case _ReviewFilter.review:
        return widget.results.where((r) => !r.known).toList();
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  int get _mastery => widget.total > 0
      ? (widget.knownCount / widget.total * 100).round()
      : 0;

  bool get _celebrateScore => _mastery >= 80;

  @override
  Widget build(BuildContext context) {
    final mastery = _mastery;
    final knownProgress =
        widget.total > 0 ? widget.knownCount / widget.total : 0.0;
    final againProgress =
        widget.total > 0 ? widget.againCount / widget.total : 0.0;
    final filtered = _filteredResults;

    return Stack(
      children: [
        Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.tealSoft,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.teal.withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: AppColors.teal,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Session review',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${widget.subject} · ${widget.chapter}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HomeTextStyles.bodySmall.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                AnimatedBuilder(
                  animation: _ringAnimation,
                  builder: (context, child) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _CircleRing(
                          size: 110,
                          strokeWidth: 8,
                          progress: (mastery / 100) * _ringAnimation.value,
                          color: widget.accent,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(mastery * _ringAnimation.value).round()}%',
                                style: GoogleFonts.inter(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: widget.accent,
                                  height: 1,
                                ),
                              ),
                              Text(
                                'Mastery',
                                style:
                                    HomeTextStyles.bodySmall.copyWith(fontSize: 9),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
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
                                icon: Icons.style_outlined,
                                label: 'Cards',
                                value: '${widget.total} reviewed',
                              ),
                              const SizedBox(height: 8),
                              _DetailStatRow(
                                icon: Icons.trending_up,
                                label: 'Accuracy',
                                value: '$mastery%',
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  _feedbackMessage,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedBuilder(
                  animation: _ringAnimation,
                  builder: (context, child) {
                    return Row(
                      children: [
                        Expanded(
                          child: _CircleStatCard(
                            label: 'Know it',
                            value: widget.knownCount,
                            progress: knownProgress * _ringAnimation.value,
                            color: AppColors.teal,
                            icon: Icons.check,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CircleStatCard(
                            label: "Don't know",
                            value: widget.againCount,
                            progress: againProgress * _ringAnimation.value,
                            color: AppColors.danger,
                            icon: Icons.close,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text('CARD BREAKDOWN', style: HomeTextStyles.sectionLabel),
                const SizedBox(height: 10),
                _ReviewFilterBar(
                  filter: _filter,
                  allCount: widget.results.length,
                  knownCount: widget.knownCount,
                  reviewCount: widget.againCount,
                  accent: widget.accent,
                  onChanged: (filter) => setState(() => _filter = filter),
                ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Text(
                      _filter == _ReviewFilter.review
                          ? 'No cards to review — great work!'
                          : 'No cards in this filter.',
                      textAlign: TextAlign.center,
                      style: HomeTextStyles.bodySmall.copyWith(fontSize: 12),
                    ),
                  )
                else
                  ...filtered.map(
                    (result) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ReviewCardTile(result: result),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: const BoxDecoration(
            color: AppColors.bgBase,
            border: Border(
              top: BorderSide(color: AppColors.border, width: 0.5),
            ),
          ),
          child: Column(
            children: [
              if (widget.againCount > 0)
                GestureDetector(
                  onTap: widget.onRestart,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
                      border: Border.all(
                        color: widget.accent.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Review ${widget.againCount} missed cards',
                        style: HomeTextStyles.badge.copyWith(
                          color: widget.accent,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              if (widget.againCount > 0) const SizedBox(height: 10),
              GestureDetector(
                onTap: widget.onDone,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Center(
                    child: Text(
                      'Done',
                      style: HomeTextStyles.badge.copyWith(
                        color: AppColors.textPrimary,
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

enum _ReviewFilter { all, known, review }

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

class _ReviewFilterBar extends StatelessWidget {
  const _ReviewFilterBar({
    required this.filter,
    required this.allCount,
    required this.knownCount,
    required this.reviewCount,
    required this.accent,
    required this.onChanged,
  });

  final _ReviewFilter filter;
  final int allCount;
  final int knownCount;
  final int reviewCount;
  final Color accent;
  final ValueChanged<_ReviewFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterChip(
          label: 'All ($allCount)',
          selected: filter == _ReviewFilter.all,
          accent: accent,
          onTap: () => onChanged(_ReviewFilter.all),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'Known ($knownCount)',
          selected: filter == _ReviewFilter.known,
          accent: AppColors.teal,
          onTap: () => onChanged(_ReviewFilter.known),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'Review ($reviewCount)',
          selected: filter == _ReviewFilter.review,
          accent: AppColors.danger,
          onTap: () => onChanged(_ReviewFilter.review),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.12) : AppColors.bgElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.4) : AppColors.border,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: HomeTextStyles.badge.copyWith(
            color: selected ? accent : AppColors.textSecondary,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}

class _ReviewCardTile extends StatefulWidget {
  const _ReviewCardTile({required this.result});

  final FlashcardReviewResult result;

  @override
  State<_ReviewCardTile> createState() => _ReviewCardTileState();
}

class _ReviewCardTileState extends State<_ReviewCardTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.result.known ? AppColors.teal : AppColors.danger;
    final bg = widget.result.known ? AppColors.tealSoft : AppColors.dangerSoft;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
          border: Border.all(
            color: _expanded ? color.withValues(alpha: 0.35) : AppColors.border,
            width: 0.5,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: color.withValues(alpha: 0.25),
                        width: 0.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.result.cardNumber}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
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
                          widget.result.card.question,
                          maxLines: _expanded ? null : 2,
                          overflow: _expanded ? null : TextOverflow.ellipsis,
                          style: HomeTextStyles.cardTitle.copyWith(fontSize: 12),
                        ),
                        if (!_expanded) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.result.known ? 'Marked as known' : 'Needs review',
                            style: HomeTextStyles.bodySmall.copyWith(
                              fontSize: 10,
                              color: color,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    widget.result.known ? Icons.check_circle : Icons.cancel_outlined,
                    color: color,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                ],
              ),
            ),
            if (_expanded) ...[
              Container(height: 0.5, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ANSWER',
                      style: HomeTextStyles.sectionLabel.copyWith(fontSize: 9),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.result.card.answer,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.result.known ? 'You knew this' : 'Review again',
                        style: HomeTextStyles.badge.copyWith(
                          color: color,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CircleStatCard extends StatelessWidget {
  const _CircleStatCard({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
    required this.icon,
  });

  final String label;
  final int value;
  final double progress;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          _CircleRing(
            size: 64,
            strokeWidth: 5,
            progress: progress,
            color: color,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 14),
                const SizedBox(height: 2),
                Text(
                  '$value',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: HomeTextStyles.badge.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
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
          trackColor: AppColors.border,
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
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
