import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/home_text_styles.dart';

/// Shared AI chat / explain follow-up input.
class AiComposerField extends StatefulWidget {
  const AiComposerField({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onSend,
    this.maxLines = 4,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;
  final int maxLines;

  @override
  State<AiComposerField> createState() => _AiComposerFieldState();
}

class _AiComposerFieldState extends State<AiComposerField> {
  final _focusNode = FocusNode();
  var _focused = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (!mounted) return;
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  bool get _hasText => widget.controller.text.trim().isNotEmpty;
  bool get _canSend => widget.enabled && _hasText;

  @override
  Widget build(BuildContext context) {
    final borderColor = !widget.enabled
        ? AppColors.border.withValues(alpha: 0.55)
        : _focused
            ? AppColors.accent.withValues(alpha: 0.5)
            : AppColors.border;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              maxLines: widget.maxLines,
              minLines: 1,
              textInputAction: TextInputAction.send,
              cursorColor: AppColors.accentText,
              style: HomeTextStyles.bodySmall.copyWith(
                fontSize: 15,
                height: 1.35,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                isDense: true,
                hintText: null,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onSubmitted: widget.enabled ? (_) => widget.onSend() : null,
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _canSend ? widget.onSend : null,
              borderRadius: BorderRadius.circular(18),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _canSend ? AppColors.accent : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_upward_rounded,
                  size: 18,
                  color: _canSend ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
