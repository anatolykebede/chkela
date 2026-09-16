import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/home_text_styles.dart';
import '../../data/home_mock_data.dart';

class GradeSelector extends StatefulWidget {
  const GradeSelector({
    super.key,
    required this.activeGrade,
    required this.onGradeSelected,
    this.preferredGrade,
  });

  final String activeGrade;
  final ValueChanged<String> onGradeSelected;

  /// Registered profile grade — listed first in the picker.
  final String? preferredGrade;

  @override
  State<GradeSelector> createState() => _GradeSelectorState();
}

class _GradeSelectorState extends State<GradeSelector> {
  final _link = LayerLink();
  final _overlayController = OverlayPortalController();
  final _triggerKey = GlobalKey();

  bool get _isOpen => _overlayController.isShowing;

  void _toggle() {
    if (_isOpen) {
      _overlayController.hide();
    } else {
      _overlayController.show();
    }
    setState(() {});
  }

  void _close() {
    if (!_isOpen) return;
    _overlayController.hide();
    setState(() {});
  }

  void _selectGrade(String grade) {
    widget.onGradeSelected(grade);
    _close();
  }

  double _triggerWidth() {
    final box = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.size.width ?? 180;
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: (context) {
        final width = _triggerWidth();
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _close,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: Offset.zero,
              child: Material(
                color: Colors.transparent,
                elevation: 0,
                child: SizedBox(
                  width: width,
                  child: _GradeDropdownPanel(
                    activeGrade: widget.activeGrade,
                    preferredGrade: widget.preferredGrade ?? widget.activeGrade,
                    onSelect: _selectGrade,
                    onHeaderTap: _toggle,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: CompositedTransformTarget(
        link: _link,
        child: KeyedSubtree(
          key: _triggerKey,
          child: _GradeTrigger(
            activeGrade: widget.activeGrade,
            isOpen: _isOpen,
            onTap: _toggle,
          ),
        ),
      ),
    );
  }
}

class _GradeTrigger extends StatelessWidget {
  const _GradeTrigger({
    required this.activeGrade,
    required this.isOpen,
    required this.onTap,
  });

  final String activeGrade;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgElevated,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOpen
                  ? AppColors.accent.withValues(alpha: 0.5)
                  : AppColors.border,
              width: isOpen ? 1 : 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  size: 15,
                  color: AppColors.accentText,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Your grade',
                      style: HomeTextStyles.badge.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 9,
                      ),
                    ),
                    Text(
                      activeGrade,
                      style: HomeTextStyles.pillLabel.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                isOpen
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating panel that mirrors the closed trigger and lists options underneath.
class _GradeDropdownPanel extends StatelessWidget {
  const _GradeDropdownPanel({
    required this.activeGrade,
    required this.preferredGrade,
    required this.onSelect,
    required this.onHeaderTap,
  });

  final String activeGrade;
  final String preferredGrade;
  final ValueChanged<String> onSelect;
  final VoidCallback onHeaderTap;

  @override
  Widget build(BuildContext context) {
    final orderedGrades = gradesPreferring(preferredGrade);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GradeTrigger(
            activeGrade: activeGrade,
            isOpen: true,
            onTap: onHeaderTap,
          ),
          const Divider(
            height: 1,
            thickness: 0.5,
            color: AppColors.border,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < orderedGrades.length; i++) ...[
                    if (gradeHasStreamOptions(orderedGrades[i]))
                      _GradeStreamGroup(
                        baseGrade: orderedGrades[i],
                        activeGrade: activeGrade,
                        preferredGrade: preferredGrade,
                        isLastBase: i == orderedGrades.length - 1,
                        onSelect: onSelect,
                      )
                    else
                      _GradeOptionTile(
                        grade: orderedGrades[i],
                        isSelected: orderedGrades[i] == activeGrade,
                        isLast: false,
                        onTap: () => onSelect(orderedGrades[i]),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradeStreamGroup extends StatelessWidget {
  const _GradeStreamGroup({
    required this.baseGrade,
    required this.activeGrade,
    required this.preferredGrade,
    required this.isLastBase,
    required this.onSelect,
  });

  final String baseGrade;
  final String activeGrade;
  final String preferredGrade;
  final bool isLastBase;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final isGroupActive = gradeBase(activeGrade) == baseGrade;
    final streams = gradeStreamsPreferring(preferredGrade, baseGrade);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Text(
            baseGrade,
            style: HomeTextStyles.badge.copyWith(
              color: isGroupActive
                  ? AppColors.accentText
                  : AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
        for (var i = 0; i < streams.length; i++)
          _GradeOptionTile(
            grade: gradeWithStream(baseGrade, streams[i]),
            label: streams[i],
            isSelected: activeGrade == gradeWithStream(baseGrade, streams[i]),
            isLast: isLastBase && i == streams.length - 1,
            indented: true,
            onTap: () => onSelect(gradeWithStream(baseGrade, streams[i])),
          ),
      ],
    );
  }
}

class _GradeOptionTile extends StatelessWidget {
  const _GradeOptionTile({
    required this.grade,
    required this.isSelected,
    required this.isLast,
    required this.onTap,
    this.label,
    this.indented = false,
  });

  final String grade;
  final String? label;
  final bool isSelected;
  final bool isLast;
  final bool indented;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.accent.withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(indented ? 26 : 14, 11, 14, 11),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : const Border(
                    bottom: BorderSide(color: AppColors.border, width: 0.5),
                  ),
          ),
          child: Row(
            children: [
              if (indented) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppColors.accentText
                        : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  label ?? grade,
                  style: HomeTextStyles.pillLabel.copyWith(
                    color: isSelected
                        ? AppColors.accentText
                        : AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: AppColors.accentText,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet to change the global grade (used from subject screens).
Future<String?> showGradePickerSheet(
  BuildContext context, {
  required String activeGrade,
  String? preferredGrade,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.bgElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      final orderedGrades = gradesPreferring(preferredGrade ?? activeGrade);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Your grade',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Your registered grade is listed first. You can switch anytime.',
                  style: HomeTextStyles.bodySmall.copyWith(fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < orderedGrades.length; i++) ...[
                if (gradeHasStreamOptions(orderedGrades[i]))
                  _SheetStreamGroup(
                    baseGrade: orderedGrades[i],
                    activeGrade: activeGrade,
                    preferredGrade: preferredGrade ?? activeGrade,
                    isLastBase: i == orderedGrades.length - 1,
                    onSelect: (value) => Navigator.of(context).pop(value),
                  )
                else
                  _GradeOptionTile(
                    grade: orderedGrades[i],
                    isSelected: orderedGrades[i] == activeGrade,
                    isLast: i == orderedGrades.length - 1,
                    onTap: () => Navigator.of(context).pop(orderedGrades[i]),
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _SheetStreamGroup extends StatelessWidget {
  const _SheetStreamGroup({
    required this.baseGrade,
    required this.activeGrade,
    required this.preferredGrade,
    required this.isLastBase,
    required this.onSelect,
  });

  final String baseGrade;
  final String activeGrade;
  final String preferredGrade;
  final bool isLastBase;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final isGroupActive = gradeBase(activeGrade) == baseGrade;
    final streams = gradeStreamsPreferring(preferredGrade, baseGrade);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Text(
            baseGrade,
            style: HomeTextStyles.badge.copyWith(
              color: isGroupActive
                  ? AppColors.accentText
                  : AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
        for (var i = 0; i < streams.length; i++)
          _GradeOptionTile(
            grade: gradeWithStream(baseGrade, streams[i]),
            label: streams[i],
            isSelected: activeGrade == gradeWithStream(baseGrade, streams[i]),
            isLast: isLastBase && i == streams.length - 1,
            indented: true,
            onTap: () => onSelect(gradeWithStream(baseGrade, streams[i])),
          ),
      ],
    );
  }
}
