import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/app_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/home_layout.dart';
import '../../core/theme/home_text_styles.dart';
import '../../data/ai_api.dart';
import '../../data/ai_study_context.dart';
import '../../data/ai_tutor_data.dart';
import '../../features/auth/auth_provider.dart';
import 'ai_limit_upgrade.dart';
import '../../widgets/common/ai_composer_field.dart';

class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key});

  static Future<void> showSheet(BuildContext context, WidgetRef ref) {
    final sheetContext = rootNavigatorKey.currentContext ?? context;
    ref.read(aiSheetOpenProvider.notifier).state = true;
    return showModalBottomSheet<void>(
      context: sheetContext,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      builder: (context) => const AiScreen(),
    ).whenComplete(() {
      ref.read(aiSheetOpenProvider.notifier).state = false;
      ref.read(guiderVisibleProvider.notifier).state = true;
    });
  }

  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _api = AiApi();
  final List<AiChatMessage> _messages = [];
  int _questionsUsed = 0;
  int _limit = aiFreeQuestionLimit;
  var _busy = false;
  var _loadingQuota = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final auth = ref.read(authProvider);
    final grade = auth.grade?.trim().isNotEmpty == true
        ? auth.grade!.trim()
        : ref.read(selectedGradeProvider);
    final ctx = ref.read(aiStudyContextProvider);
    if (ctx.grade.trim().isEmpty && grade.trim().isNotEmpty) {
      ref.read(aiStudyContextProvider.notifier).state =
          ctx.copyWith(grade: grade);
    }

    try {
      final quota = await _api.fetchQuota(feature: 'tutor');
      if (!mounted) return;
      setState(() {
        _questionsUsed = quota.used;
        _limit = quota.limit;
        _loadingQuota = false;
        if (_messages.isEmpty) {
          final focus = ref.read(aiStudyContextProvider);
          _messages.add(
            AiChatMessage(
              isUser: false,
              text: focus.hasFocus
                  ? 'Hi! I can help with ${focus.label}. Ask me to explain, simplify, give an example, quiz you, or check your weak spots.'
                  : 'Hi! Open a note or exam for better context, or ask me anything you are studying.',
            ),
          );
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingQuota = false;
        if (_messages.isEmpty) {
          _messages.add(
            const AiChatMessage(
              isUser: false,
              text:
                  'Hi! Sign in and keep the server running to use the AI tutor. You still have a few free asks per day.',
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _atLimit => _questionsUsed >= _limit;

  Color get _usageColor {
    if (_atLimit) return AppColors.danger;
    if (_limit - _questionsUsed == 1) return AppColors.amber;
    return AppColors.accentText;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _atLimit || _busy) return;

    HapticFeedback.lightImpact();
    setState(() {
      _messages.add(AiChatMessage(isUser: true, text: text));
      if (preset == null) _controller.clear();
      _busy = true;
    });
    _scrollToBottom();

    try {
      final weak = await AiWeakSpotStore.load();
      final result = await _api.askTutor(
        message: text,
        context: ref.read(aiStudyContextProvider),
        weakSpots: weak,
      );
      if (!mounted) return;
      setState(() {
        _questionsUsed = result.quota.used;
        _limit = result.quota.limit;
        _messages.add(AiChatMessage(isUser: false, text: result.reply));
        _busy = false;
      });
    } on AiApiException catch (error) {
      if (!mounted) return;
      final limited = isAiQuotaExceeded(error);
      setState(() {
        _busy = false;
        if (limited) {
          _questionsUsed = _limit;
        } else {
          _messages.add(AiChatMessage(isUser: false, text: error.message));
        }
      });
      if (limited && mounted) {
        await promptAiLimitUpgrade(context);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _messages.add(
          const AiChatMessage(
            isUser: false,
            text: 'Could not reach the AI tutor. Check your connection and try again.',
          ),
        );
      });
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final availableHeight =
        MediaQuery.sizeOf(context).height - viewInsets.bottom;
    final sheetHeight = availableHeight * 0.88;
    final ctx = ref.watch(aiStudyContextProvider);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        height: sheetHeight,
        decoration: const BoxDecoration(
          color: AppColors.bgBase,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(
            top: BorderSide(color: AppColors.border, width: 0.5),
            left: BorderSide(color: AppColors.border, width: 0.5),
            right: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const _SheetHandle(),
              _ContextHeader(
                label: ctx.label,
                used: _questionsUsed,
                limit: _limit,
                usageColor: _usageColor,
                loading: _loadingQuota,
              ),
              if (_messages.length <= 1 && !_atLimit)
                _SuggestedPrompts(
                  enabled: !_busy,
                  onTap: (prompt) => _sendMessage(prompt),
                ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: _messages.length + (_busy ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_busy && index == _messages.length) {
                      return const _TypingBubble();
                    }
                    return _MessageBubble(message: _messages[index]);
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                decoration: const BoxDecoration(
                  color: AppColors.bgSurface,
                  border: Border(
                    top: BorderSide(color: AppColors.border, width: 0.5),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: _atLimit
                      ? const AiLimitUpgradeCard()
                      : AiComposerField(
                          controller: _controller,
                          enabled: !_busy,
                          onSend: _sendMessage,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _ContextHeader extends StatelessWidget {
  const _ContextHeader({
    required this.label,
    required this.used,
    required this.limit,
    required this.usageColor,
    required this.loading,
  });

  final String label;
  final int used;
  final int limit;
  final Color usageColor;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HomeTextStyles.badge.copyWith(
                    fontSize: 12,
                    color: AppColors.accentText,
                  ),
                ),
              ),
              Text(
                loading ? '…' : '$used / $limit free',
                style: HomeTextStyles.bodySmall.copyWith(
                  fontSize: 11,
                  color: usageColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(HomeLayout.progressRadius),
            child: LinearProgressIndicator(
              value: limit <= 0 ? 1 : (used / limit).clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(usageColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestedPrompts extends StatelessWidget {
  const _SuggestedPrompts({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        itemCount: aiSuggestedPrompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (label, emoji) = aiSuggestedPrompts[index];
          return GestureDetector(
            onTap: enabled ? () => onTap(label) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Text(
                '$emoji $label',
                style: HomeTextStyles.bodySmall.copyWith(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Text(
          'Thinking…',
          style: HomeTextStyles.bodySmall.copyWith(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final AiChatMessage message;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.82;

    if (message.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                message.text,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomRight: Radius.circular(14),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Text(
              message.text,
              style: HomeTextStyles.bodySmall.copyWith(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
