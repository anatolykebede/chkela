import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/app_providers.dart';
import '../../core/security/content_screenshot_guard.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/ai_study_context.dart';
import '../../data/chapter_content_items.dart';
import '../../data/content/content_store.dart';
import '../../data/exam_questions.dart';
import '../../data/exam_type.dart';
import '../../data/note_assets.dart';
import '../../data/study_mode.dart';
import '../../data/study_progress_store.dart';
import '../../features/ai/ai_coach_sheet.dart';
import '../../features/auth/auth_provider.dart';
import 'note_html_body.dart';
import 'note_html_document.dart';

class NoteReaderScreen extends ConsumerStatefulWidget {
  const NoteReaderScreen({
    super.key,
    required this.args,
  });

  final NoteSessionArgs args;

  @override
  ConsumerState<NoteReaderScreen> createState() => _NoteReaderScreenState();
}

class _NoteReaderScreenState extends ConsumerState<NoteReaderScreen> {
  var _isLoading = true;
  String? _errorMessage;
  String? _html;
  String? _sectionAnchor;

  List<ChapterContentItem> get _chapterNotes =>
      itemsForChapter(widget.args.chapterId, SubjectStudyMode.notes);

  int get _currentIndex =>
      _chapterNotes.indexWhere((note) => note.id == widget.args.noteId);

  ChapterContentItem? get _nextNote {
    final index = _currentIndex;
    if (index < 0 || index >= _chapterNotes.length - 1) return null;
    return _chapterNotes[index + 1];
  }

  @override
  void initState() {
    super.initState();
    ContentScreenshotGuard.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncAiContext();
    });
    _loadNote();
  }

  void _syncAiContext() {
    final authGrade = ref.read(authProvider).grade?.trim() ?? '';
    final grade = authGrade.isNotEmpty
        ? authGrade
        : ref.read(selectedGradeProvider);
    final cms = ContentStore.instance.noteById(widget.args.noteId);
    final snippet = _plainSnippet(cms?.bodyHtml ?? '');
    ref.read(aiStudyContextProvider.notifier).state = AiStudyContext(
      grade: grade,
      subject: widget.args.subjectName,
      chapter: widget.args.chapterTitle,
      note: widget.args.noteTitle,
      noteSnippet: snippet,
    );
  }

  String _plainSnippet(String html) {
    final plain = html
        .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (plain.length <= 1200) return plain;
    return '${plain.substring(0, 1200)}…';
  }

  Future<void> _onExplainSelection(String selection) async {
    final text = selection.trim();
    if (text.length < 8) return;
    await showExplainSelectionSheet(
      context,
      selection: text,
      studyContext: ref.read(aiStudyContextProvider),
    );
  }

  @override
  void dispose() {
    ContentScreenshotGuard.disable();
    super.dispose();
  }

  Future<void> _loadNote() async {
    final store = ContentStore.instance;
    final cmsNote = store.noteById(widget.args.noteId);
    if (cmsNote != null && cmsNote.bodyHtml.trim().isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _html = wrapNoteHtmlDocument(cmsNote.bodyHtml);
        _sectionAnchor = null;
        _errorMessage = null;
      });
      // Fallback if WebView never reports onPageFinished.
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (!mounted || !_isLoading) return;
        setState(() => _isLoading = false);
      });
      await StudyProgressStore.instance.markNoteDone(widget.args.noteId);
      return;
    }

    // CMS catalog is live: do not fall back to bundled demo note HTML.
    if (store.isLoaded) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Note content is not available yet.';
      });
      return;
    }

    final asset = noteAssetFor(widget.args.noteId);
    if (asset == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Note content is not available yet.';
      });
      return;
    }

    try {
      final html = await rootBundle.loadString(asset.assetPath);
      if (!mounted) return;
      setState(() {
        _html = wrapNoteHtmlDocument(html, sectionAnchor: asset.sectionAnchor);
        _sectionAnchor = asset.sectionAnchor;
      });
      await StudyProgressStore.instance.markNoteDone(widget.args.noteId);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load this note.';
      });
    }
  }

  void _onLoaded() {
    if (!mounted) return;
    setState(() => _isLoading = false);
    StudyProgressStore.instance.markNoteDone(widget.args.noteId);
  }

  void _onError(String message) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  void _openNextLesson() {
    final next = _nextNote;
    if (next == null) return;

    HapticFeedback.lightImpact();
    context.pushReplacement(
      '/content/notes',
      extra: NoteSessionArgs(
        subjectName: widget.args.subjectName,
        chapterTitle: widget.args.chapterTitle,
        chapterId: widget.args.chapterId,
        noteId: next.id,
        noteTitle: next.title,
      ),
    );
  }

  void _openUnitExam() {
    HapticFeedback.lightImpact();
    context.pushReplacement(
      '/content/exam',
      extra: ExamSessionArgs(
        subjectName: widget.args.subjectName,
        examType: ExamType.chapterExam,
        examTitle: widget.args.chapterTitle,
        chapterId: widget.args.chapterId,
        chapterTitle: widget.args.chapterTitle,
        grade: ref.read(selectedGradeProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final next = _nextNote;
    final hasNext = next != null;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9FC),
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.args.noteTitle,
          style: AppTextStyles.headingMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                : Stack(
                    children: [
                      if (_html != null)
                        NoteHtmlBody(
                          key: ValueKey(widget.args.noteId),
                          html: _html!,
                          sectionAnchor: _sectionAnchor,
                          onLoaded: _onLoaded,
                          onError: _onError,
                          onExplainSelection: _onExplainSelection,
                        ),
                      if (_isLoading)
                        const ColoredBox(
                          color: Color(0xFFFAF9FC),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          _NextLessonBar(
            hasNext: hasNext,
            nextTitle: next?.title,
            chapterTitle: widget.args.chapterTitle,
            bottomInset: bottomInset,
            onNext: _openNextLesson,
            onUnitExam: _openUnitExam,
          ),
        ],
      ),
    );
  }
}

class _NextLessonBar extends StatelessWidget {
  const _NextLessonBar({
    required this.hasNext,
    required this.nextTitle,
    required this.chapterTitle,
    required this.bottomInset,
    required this.onNext,
    required this.onUnitExam,
  });

  final bool hasNext;
  final String? nextTitle;
  final String chapterTitle;
  final double bottomInset;
  final VoidCallback onNext;
  final VoidCallback onUnitExam;

  @override
  Widget build(BuildContext context) {
    final shortChapter = chapterTitle.contains(':')
        ? chapterTitle.split(':').last.trim()
        : chapterTitle;

    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: hasNext ? onNext : onUnitExam,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasNext ? 'Next lesson' : 'Unit exam',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        hasNext
                            ? (nextTitle ?? 'Continue')
                            : shortChapter,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  hasNext
                      ? Icons.arrow_forward_rounded
                      : Icons.quiz_outlined,
                  size: 22,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
