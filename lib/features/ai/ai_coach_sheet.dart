import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/home_text_styles.dart';
import '../../data/ai_api.dart';
import '../../data/ai_study_context.dart';
import '../../widgets/common/ai_composer_field.dart';
import 'ai_limit_upgrade.dart';

const _translateTargets = <(String code, String label)>[
  ('am', 'Amharic'),
  ('om', 'Afaan Oromo'),
  ('ti', 'Tigrigna'),
  ('so', 'Somali'),
  ('aa', 'Afar'),
];

Future<void> showAiCoachSheet(
  BuildContext context, {
  required String title,
  required Future<AiTutorReply> Function() load,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: AppColors.bgSurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _AiCoachSheet(title: title, load: load),
  );
}

class _AiCoachSheet extends StatefulWidget {
  const _AiCoachSheet({required this.title, required this.load});

  final String title;
  final Future<AiTutorReply> Function() load;

  @override
  State<_AiCoachSheet> createState() => _AiCoachSheetState();
}

class _AiCoachSheetState extends State<_AiCoachSheet> {
  var _loading = true;
  var _limitHit = false;
  String? _error;
  String? _reply;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final result = await widget.load();
      if (!mounted) return;
      setState(() {
        _reply = result.reply;
        _loading = false;
      });
    } on AiApiException catch (error) {
      if (!mounted) return;
      final limited = isAiQuotaExceeded(error);
      setState(() {
        _error = limited ? null : error.message;
        _limitHit = limited;
        _loading = false;
      });
      if (limited && mounted) await promptAiLimitUpgrade(context);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not reach AI. Try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.title,
            style: HomeTextStyles.badge.copyWith(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            )
          else if (_limitHit)
            const AiLimitUpgradeCard()
          else if (_error != null)
            Text(
              _error!,
              style: HomeTextStyles.bodySmall.copyWith(
                color: AppColors.danger,
                height: 1.4,
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.45,
              ),
              child: SingleChildScrollView(
                child: Text(
                  _reply ?? '',
                  style: HomeTextStyles.bodySmall.copyWith(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          if (!_limitHit) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Got it'),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Close',
                  style: HomeTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> showExplainSelectionSheet(
  BuildContext context, {
  required String selection,
  required AiStudyContext studyContext,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: AppColors.bgSurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _ExplainSelectionSheet(
      selection: selection,
      studyContext: studyContext,
    ),
  );
}

class _ExplainTurn {
  const _ExplainTurn({required this.isUser, required this.text});
  final bool isUser;
  final String text;
}

class _ExplainSelectionSheet extends StatefulWidget {
  const _ExplainSelectionSheet({
    required this.selection,
    required this.studyContext,
  });

  final String selection;
  final AiStudyContext studyContext;

  @override
  State<_ExplainSelectionSheet> createState() => _ExplainSelectionSheetState();
}

class _ExplainSelectionSheetState extends State<_ExplainSelectionSheet> {
  final _api = AiApi();
  final _followUpController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ExplainTurn> _followUps = [];
  var _loading = true;
  var _translating = false;
  var _asking = false;
  var _limitHit = false;
  String? _error;
  String? _english;
  String? _translated;
  String? _translatedLabel;

  @override
  void initState() {
    super.initState();
    _loadExplain();
  }

  @override
  void dispose() {
    _followUpController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _loadExplain() async {
    setState(() {
      _loading = true;
      _error = null;
      _translated = null;
      _translatedLabel = null;
      _followUps.clear();
    });
    try {
      final result = await _api.explainSelection(
        selection: widget.selection,
        context: widget.studyContext,
      );
      if (!mounted) return;
      setState(() {
        _english = result.reply;
        _loading = false;
      });
    } on AiApiException catch (error) {
      if (!mounted) return;
      final limited = isAiQuotaExceeded(error);
      setState(() {
        _error = limited ? null : error.message;
        _limitHit = limited;
        _loading = false;
      });
      if (limited && mounted) await promptAiLimitUpgrade(context);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not reach AI. Try again.';
        _loading = false;
      });
    }
  }

  Future<void> _askFollowUp() async {
    final question = _followUpController.text.trim();
    if (question.isEmpty || _asking || _english == null || _limitHit) return;

    final priorTurns = List<_ExplainTurn>.from(_followUps);
    setState(() {
      _asking = true;
      _error = null;
      _followUps.add(_ExplainTurn(isUser: true, text: question));
      _followUpController.clear();
    });
    _scrollToEnd();

    final history = priorTurns.isEmpty
        ? ''
        : priorTurns
            .map((t) => '${t.isUser ? 'Student' : 'Tutor'}: ${t.text}')
            .join('\n');
    final snippet = [
      'Selected note text:\n${widget.selection.trim()}',
      'Prior English explanation:\n${_english!.trim()}',
      if (history.isNotEmpty) 'Earlier follow-ups:\n$history',
    ].join('\n\n');

    try {
      final result = await _api.askTutor(
        message: question,
        context: widget.studyContext.copyWith(
          noteSnippet: snippet.length > 2500
              ? '${snippet.substring(0, 2500)}…'
              : snippet,
        ),
      );
      if (!mounted) return;
      setState(() {
        _followUps.add(_ExplainTurn(isUser: false, text: result.reply));
        _asking = false;
      });
      _scrollToEnd();
    } on AiApiException catch (error) {
      if (!mounted) return;
      final limited = isAiQuotaExceeded(error);
      setState(() {
        _asking = false;
        _followUps.removeLast();
        _followUpController.text = question;
        if (limited) {
          _limitHit = true;
          _error = null;
        } else {
          _error = error.message;
        }
      });
      if (limited && mounted) await promptAiLimitUpgrade(context);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _asking = false;
        _error = 'Could not reach AI. Try again.';
        _followUps.removeLast();
        _followUpController.text = question;
      });
    }
  }

  Future<void> _pickAndTranslate() async {
    final english = _english?.trim() ?? '';
    if (english.isEmpty || _translating) return;

    final target = await showModalBottomSheet<(String, String)>(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Translate to',
                  style: HomeTextStyles.badge.copyWith(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                for (final (code, label) in _translateTargets)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      label,
                      style: HomeTextStyles.bodySmall.copyWith(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                    ),
                    onTap: () => Navigator.of(context).pop((code, label)),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (target == null || !mounted) return;
    final (code, label) = target;

    setState(() {
      _translating = true;
      _error = null;
    });

    try {
      final result = await _api.translateText(text: english, target: code);
      if (!mounted) return;
      setState(() {
        _translated = result.reply;
        _translatedLabel = label;
        _translating = false;
      });
    } on AiApiException catch (error) {
      if (!mounted) return;
      final limited = isAiQuotaExceeded(error);
      setState(() {
        _translating = false;
        if (limited) {
          _limitHit = true;
          _error = null;
        } else {
          _error = error.message;
        }
      });
      if (limited && mounted) await promptAiLimitUpgrade(context);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Translation failed. Try again.';
        _translating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final maxBody = MediaQuery.sizeOf(context).height * 0.48;
    final canAsk = !_loading && _english != null && !_asking && !_limitHit;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Explain selection',
                  style: HomeTextStyles.badge.copyWith(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (!_loading && _english != null && !_limitHit)
                TextButton.icon(
                  onPressed: _translating ? null : _pickAndTranslate,
                  icon: _translating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accentText,
                          ),
                        )
                      : const Icon(Icons.translate_rounded, size: 16),
                  label: Text(_translating ? '…' : 'Translate'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accentText,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            )
          else if (_limitHit && _english == null)
            const AiLimitUpgradeCard()
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxBody),
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_translated != null) ...[
                      Text(
                        _translatedLabel ?? 'Translation',
                        style: HomeTextStyles.bodySmall.copyWith(
                          fontSize: 11,
                          color: AppColors.accentText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _translated!,
                        style: HomeTextStyles.bodySmall.copyWith(
                          fontSize: 14,
                          height: 1.45,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ] else if (_english != null) ...[
                      Text(
                        'English',
                        style: HomeTextStyles.bodySmall.copyWith(
                          fontSize: 11,
                          color: AppColors.accentText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _english!,
                        style: HomeTextStyles.bodySmall.copyWith(
                          fontSize: 14,
                          height: 1.45,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                    for (final turn in _followUps) ...[
                      const SizedBox(height: 14),
                      Align(
                        alignment: turn.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: turn.isUser
                                ? AppColors.accent
                                : AppColors.bgElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: turn.isUser
                                ? null
                                : Border.all(
                                    color: AppColors.border,
                                    width: 0.5,
                                  ),
                          ),
                          child: Text(
                            turn.text,
                            style: HomeTextStyles.bodySmall.copyWith(
                              fontSize: 14,
                              height: 1.4,
                              color: turn.isUser
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (_asking) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Thinking…',
                        style: HomeTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: HomeTextStyles.bodySmall.copyWith(
                          color: AppColors.danger,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (!_loading && _english != null) ...[
            const SizedBox(height: 12),
            if (_limitHit)
              const AiLimitUpgradeCard()
            else
              AiComposerField(
                controller: _followUpController,
                enabled: canAsk,
                onSend: _askFollowUp,
              ),
          ],
        ],
      ),
    );
  }
}

