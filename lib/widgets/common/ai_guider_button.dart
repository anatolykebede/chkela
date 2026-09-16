import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../core/router/app_router.dart';
import '../../features/ai/ai_screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/home_text_styles.dart';

import 'dart:math' as math;

const _buttonSize = 52.0;
const _dragSlop = 4.0;
const _tapSlop = 10.0;

/// Custom AI buddy face — visor eyes, antenna, soft glow. Scales down cleanly.
class _GuiderMascotPainter extends CustomPainter {
  _GuiderMascotPainter({
    required this.glow,
    required this.compact,
  });

  final double glow;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final center = Offset(s / 2, s / 2);
    final radius = s / 2 - 1;

    final bg = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.35),
        radius: 1.05,
        colors: const [
          Color(0xFFB8AEFF),
          AppColors.accent,
          Color(0xFF3B4FD8),
          Color(0xFF1A2A6E),
        ],
        stops: const [0.0, 0.38, 0.72, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, bg);

    final shade = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.2, 0.9),
        radius: 0.75,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.28),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, shade);

    if (!compact) {
      final antenna = Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      final tip = Offset(s / 2, s * 0.1);
      final base = Offset(s / 2, s * 0.24);
      canvas.drawLine(base, tip, antenna);
      canvas.drawCircle(
        tip,
        s * 0.045,
        Paint()..color = Color.lerp(AppColors.teal, Colors.white, glow * 0.5)!,
      );
    }

    final visor = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.2, s * 0.34, s * 0.6, s * 0.2),
      Radius.circular(s * 0.1),
    );
    canvas.drawRRect(
      visor,
      Paint()..color = const Color(0xFF120F2E).withValues(alpha: 0.72),
    );
    canvas.drawRRect(
      visor,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.18),
    );

    for (final dx in [0.36, 0.64]) {
      final eyeCenter = Offset(s * dx, s * 0.44);
      final eyeGlow = Paint()
        ..color = AppColors.teal.withValues(alpha: 0.18 + glow * 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(eyeCenter, s * 0.1, eyeGlow);

      canvas.drawCircle(
        eyeCenter,
        s * 0.055,
        Paint()..color = Color.lerp(const Color(0xFF7DFFF0), Colors.white, glow * 0.45)!,
      );
      canvas.drawCircle(
        eyeCenter + Offset(-s * 0.018, -s * 0.018),
        s * 0.018,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }

    final smile = Path()
      ..addArc(
        Rect.fromCircle(center: Offset(s / 2, s * 0.56), radius: s * 0.11),
        math.pi * 0.12,
        math.pi * 0.76,
      );
    canvas.drawPath(
      smile,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = compact ? 1.2 : 1.6
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.42 + glow * 0.18),
    );

    if (!compact) {
      _drawSpark(
        canvas,
        _polar(center, radius * 0.78, -math.pi / 2 - 0.55),
        s * 0.05,
        glow,
      );
      _drawSpark(
        canvas,
        _polar(center, radius * 0.74, math.pi / 2 + 0.35),
        s * 0.04,
        glow * 0.85,
      );
    }
  }

  Offset _polar(Offset origin, double r, double angle) {
    return origin + Offset(math.cos(angle) * r, math.sin(angle) * r);
  }

  void _drawSpark(Canvas canvas, Offset origin, double size, double intensity) {
    final paint = Paint()
      ..color = Color.lerp(AppColors.accentText, Colors.white, intensity * 0.6)!
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      origin + Offset(0, -size),
      origin + Offset(0, size),
      paint,
    );
    canvas.drawLine(
      origin + Offset(-size, 0),
      origin + Offset(size, 0),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GuiderMascotPainter oldDelegate) {
    return oldDelegate.glow != glow || oldDelegate.compact != compact;
  }
}

/// AI buddy FAB used by the overlay and home restore control.
class GuiderFabIcon extends StatefulWidget {
  const GuiderFabIcon({
    super.key,
    this.size = _buttonSize,
    this.pulse = true,
  });

  final double size;
  final bool pulse;

  @override
  State<GuiderFabIcon> createState() => _GuiderFabIconState();
}

class _GuiderFabIconState extends State<GuiderFabIcon>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    if (widget.pulse) {
      _pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  Widget _buildMascot(double glow) {
    final compact = widget.size < 40;

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.24),
          width: compact ? 1.2 : 1.5,
        ),
      ),
      child: ClipOval(
        child: CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _GuiderMascotPainter(glow: glow, compact: compact),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_pulse == null) return _buildMascot(0.4);

    return AnimatedBuilder(
      animation: _pulse!,
      builder: (context, child) {
        final pulseGlow = 0.22 + _pulse!.value * 0.2;
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: pulseGlow),
                blurRadius: 14 + _pulse!.value * 6,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: AppColors.teal.withValues(alpha: pulseGlow * 0.65),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _buildMascot(0.35 + _pulse!.value * 0.45),
        );
      },
    );
  }
}

/// Draggable guider — shown on every screen except the guider chat itself.
class AiGuiderOverlay extends ConsumerStatefulWidget {
  const AiGuiderOverlay({super.key});

  @override
  ConsumerState<AiGuiderOverlay> createState() => _AiGuiderOverlayState();
}

class _AiGuiderOverlayState extends ConsumerState<AiGuiderOverlay> {
  Offset? _dragOffset;
  bool _isDragging = false;
  Offset _panAccum = Offset.zero;
  Offset? _pointerDownOffset;
  int? _activePointer;
  bool _sessionBootstrapped = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sessionBootstrapped) return;
    _sessionBootstrapped = true;

    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(guiderVisibleProvider.notifier).state = true;
      ref.read(guiderAnchorProvider.notifier).state =
          GuiderAnchor.aboveSquadNav(size, padding, buttonSize: _buttonSize);
    });
  }

  Rect _bounds(Size size, EdgeInsets padding) {
    return GuiderAnchor.draggableBounds(
      size,
      padding,
      buttonSize: _buttonSize,
    );
  }

  Offset _anchorToOffset(GuiderAnchor anchor, Rect bounds) {
    return Offset(
      bounds.left + anchor.x * bounds.width,
      bounds.top + anchor.y * bounds.height,
    );
  }

  GuiderAnchor _offsetToAnchor(Offset offset, Rect bounds) {
    return GuiderAnchor(
      x: ((offset.dx - bounds.left) / bounds.width).clamp(0.0, 1.0),
      y: ((offset.dy - bounds.top) / bounds.height).clamp(0.0, 1.0),
    );
  }

  bool _hitsDismissZone(Offset buttonCenter, Size size, EdgeInsets padding) {
    final dismissCenter = Offset(
      size.width / 2,
      size.height - padding.bottom - 80,
    );
    return (buttonCenter - dismissCenter).distance < 52;
  }

  Offset _clampOffset(Offset value, Rect bounds) {
    return Offset(
      value.dx.clamp(bounds.left, bounds.right),
      value.dy.clamp(bounds.top, bounds.bottom),
    );
  }

  void _finishPointer(
    Size size,
    EdgeInsets padding,
    Rect bounds,
    Offset baseOffset,
  ) {
    final current = _dragOffset ?? _pointerDownOffset ?? baseOffset;
    final center = current + const Offset(_buttonSize / 2, _buttonSize / 2);

    if (_panAccum.distance < _tapSlop) {
      HapticFeedback.lightImpact();
      ref.read(guiderVisibleProvider.notifier).state = false;
      AiScreen.showSheet(context, ref);
    } else if (_hitsDismissZone(center, size, padding)) {
      HapticFeedback.mediumImpact();
      ref.read(guiderVisibleProvider.notifier).state = false;
    } else {
      ref.read(guiderAnchorProvider.notifier).state =
          _offsetToAnchor(current, bounds);
    }

    setState(() {
      _isDragging = false;
      _dragOffset = null;
      _panAccum = Offset.zero;
      _pointerDownOffset = null;
      _activePointer = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return ListenableBuilder(
      listenable: router.routerDelegate,
      builder: (context, _) {
        final location =
            router.routerDelegate.currentConfiguration.uri.path;
        if (location == '/splash') return const SizedBox.shrink();

        final visible = ref.watch(guiderVisibleProvider);
        final sheetOpen = ref.watch(aiSheetOpenProvider);
        final suppressed = ref.watch(guiderSuppressCountProvider) > 0;
        if (!visible || sheetOpen || suppressed) {
          return const SizedBox.shrink();
        }

        return _buildGuider(context);
      },
    );
  }

  Widget _buildGuider(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final bounds = _bounds(size, padding);
    final anchor = ref.watch(guiderAnchorProvider);
    final baseOffset = _anchorToOffset(anchor, bounds);
    final offset = _dragOffset ?? baseOffset;

    return Stack(
      children: [
        if (_isDragging)
          Positioned(
            left: size.width / 2 - 30,
            bottom: padding.bottom + 56,
            child: _DismissTarget(highlighted: _hitsDismissZone(
              offset + const Offset(_buttonSize / 2, _buttonSize / 2),
              size,
              padding,
            )),
          ),
        Positioned(
          left: offset.dx,
          top: offset.dy,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              _activePointer = event.pointer;
              _panAccum = Offset.zero;
              _pointerDownOffset = offset;
            },
            onPointerMove: (event) {
              if (_activePointer != event.pointer || _pointerDownOffset == null) {
                return;
              }

              _panAccum += event.delta;
              if (_panAccum.distance < _dragSlop) return;

              final next = _clampOffset(_pointerDownOffset! + _panAccum, bounds);
              setState(() {
                _isDragging = true;
                _dragOffset = next;
              });
            },
            onPointerUp: (event) {
              if (_activePointer != event.pointer) return;
              _finishPointer(size, padding, bounds, baseOffset);
            },
            onPointerCancel: (event) {
              if (_activePointer != event.pointer) return;
              _finishPointer(size, padding, bounds, baseOffset);
            },
            child: const SizedBox(
              width: _buttonSize,
              height: _buttonSize,
              child: GuiderFabIcon(),
            ),
          ),
        ),
      ],
    );
  }
}

class _DismissTarget extends StatelessWidget {
  const _DismissTarget({required this.highlighted});

  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.danger.withValues(alpha: 0.35)
            : AppColors.bgElevated.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        border: Border.all(
          color: highlighted ? AppColors.danger : AppColors.border,
          width: highlighted ? 2 : 0.5,
        ),
      ),
      child: Icon(
        Icons.close_rounded,
        color: highlighted ? AppColors.danger : AppColors.textMuted,
        size: 26,
      ),
    );
  }
}

/// Home top-bar control to bring the floating guider back.
class GuiderRestoreButton extends ConsumerWidget {
  const GuiderRestoreButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(guiderVisibleProvider);
    if (visible) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(guiderVisibleProvider.notifier).state = true;
      },
      child: const GuiderFabIcon(size: 36, pulse: false),
    );
  }
}

/// Legacy shell FAB — the global [AiGuiderOverlay] handles the guider now.
/// Kept with the original state shape so hot reload does not crash after refactors.
class AiGuiderButton extends StatefulWidget {
  const AiGuiderButton({super.key});

  @override
  State<AiGuiderButton> createState() => _AiGuiderButtonState();
}

class _AiGuiderButtonState extends State<AiGuiderButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Compact inline prompt for study contexts.
class AiGuiderPrompt extends ConsumerWidget {
  const AiGuiderPrompt({
    super.key,
    this.hint = 'Stuck? Ask Guider for help',
  });

  final String hint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(guiderVisibleProvider.notifier).state = false;
        AiScreen.showSheet(context, ref);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.tealSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.teal.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const GuiderFabIcon(size: 28, pulse: false),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hint,
                style: HomeTextStyles.cardTitle.copyWith(
                  fontSize: 12,
                  color: AppColors.teal,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.teal,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
