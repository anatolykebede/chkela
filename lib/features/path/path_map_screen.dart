import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../data/content_access.dart';
import '../../data/path_catalog.dart';
import '../../data/path_levels.dart';
import '../../data/path_progress_store.dart';
import '../subscription/subscription_flow.dart';

class PathMapScreen extends ConsumerStatefulWidget {
  const PathMapScreen({super.key});

  @override
  ConsumerState<PathMapScreen> createState() => _PathMapScreenState();
}

class _PathMapScreenState extends ConsumerState<PathMapScreen>
    with TickerProviderStateMixin {
  final _store = PathProgressStore.instance;
  var _ready = false;
  AnimationController? _pulse;
  AnimationController? _drift;

  @override
  void initState() {
    super.initState();
    _ensureAnims();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  void _reload() {
    final grade = ref.read(selectedGradeProvider);
    PathCatalogStore.instance.setViewerGrade(grade);
    setState(() => _ready = false);
    Future.wait([
      _store.load(),
      PathCatalogStore.instance.load(force: true),
    ]).then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void reassemble() {
    super.reassemble();
    _ensureAnims();
  }

  void _ensureAnims() {
    _pulse ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _drift ??= AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse?.dispose();
    _drift?.dispose();
    super.dispose();
  }

  bool get _fullAccess =>
      ref.read(fullContentAccessProvider).valueOrNull ?? false;

  List<PathLevel> _sameGrade(PathLevel level) => PathCatalogStore.instance.levels
      .where((l) => l.gradeId == level.gradeId)
      .toList();

  PathLevelStatus _statusFor(PathLevel level) {
    final base = _store.statusFor(level);
    if (ContentAccess.isPathLevelPaywalled(
      level,
      fullAccess: _fullAccess,
      sameGradeLevels: _sameGrade(level),
    )) {
      return PathLevelStatus.locked;
    }
    return base;
  }

  Future<void> _openLevel(PathLevel level) async {
    final isDaily = level.id == kPathDailyId;
    if (!isDaily) {
      if (ContentAccess.isPathLevelPaywalled(
        level,
        fullAccess: _fullAccess,
        sameGradeLevels: _sameGrade(level),
      )) {
        HapticFeedback.heavyImpact();
        await openSubscriptionFlow(context);
        if (mounted) setState(() {});
        return;
      }
      final status = _store.statusFor(level);
      if (status == PathLevelStatus.locked) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Clear the previous gate in this grade to unlock',
              style: const TextStyle(color: Colors.white),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.bgElevated,
          ),
        );
        return;
      }
    }
    if (!_store.canPlay) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _store.energyRefillLabel.isEmpty
                ? 'Out of energy. Wait for a refill, then jump back in.'
                : 'Out of energy. ${_store.energyRefillLabel}.',
            style: const TextStyle(color: Colors.white),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.bgElevated,
        ),
      );
      return;
    }
    HapticFeedback.lightImpact();
    await context.pushNamed('thePathLevel', pathParameters: {'id': level.id});
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(selectedGradeProvider, (prev, next) {
      if (prev != next) _reload();
    });
    ref.watch(fullContentAccessProvider);
    _ensureAnims();
    final pulse = _pulse!;
    final drift = _drift!;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final continueLevel = _ready ? _continueTarget() : null;
    final grade = ref.watch(selectedGradeProvider);
    final gradeIds = pathVisibleGradeIds(grade);

    return Scaffold(
      backgroundColor: const Color(0xFF05060C),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: drift,
            builder: (context, _) => CustomPaint(
              painter: _ArenaBackdropPainter(t: drift.value),
              size: Size.infinite,
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _ArenaHud(
                  ready: _ready,
                  arenaTitle: gradeIds.length > 1
                      ? 'Grades 9–12 Arena'
                      : 'Battle Arena',
                  cleared: _store.clearedCount,
                  total: PathCatalogStore.instance.levels.length,
                  xp: _store.xpWallet,
                  energy: _store.energy,
                  streak: _store.liveStreak,
                  stars: _store.totalStars,
                  maxStars: _store.maxStars,
                  dailyDone: _store.dailyDoneToday,
                  onDaily: () =>
                      _openLevel(PathCatalogStore.instance.dailyLevel),
                  onBack: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  },
                ),
                Expanded(
                  child: !_ready
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.amber,
                          ),
                        )
                      : PathCatalogStore.instance.levels.isEmpty
                          ? _EmptyPathState(gradeLabel: grade)
                          : SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                16,
                                4,
                                16,
                                120 + bottomSafe,
                              ),
                              child: _PathTrail(
                                levels: PathCatalogStore.instance.levels,
                                statusFor: _statusFor,
                                starsFor: _store.starsFor,
                                onTap: _openLevel,
                                pulse: pulse,
                                fullAccess: _fullAccess,
                              ),
                            ),
                ),
              ],
            ),
          ),
          if (continueLevel != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: bottomSafe + 16,
              child: _ContinueBar(
                level: continueLevel,
                stars: continueLevel.id == kPathDailyId
                    ? 0
                    : _store.starsFor(continueLevel.id),
                onPlay: () => _openLevel(continueLevel),
              ),
            ),
        ],
      ),
    );
  }

  PathLevel? _continueTarget() {
    final preferred = _store.continueTarget(preferDaily: true);
    if (preferred.id == kPathDailyId) return preferred;
    if (!ContentAccess.isPathLevelPaywalled(
      preferred,
      fullAccess: _fullAccess,
      sameGradeLevels: _sameGrade(preferred),
    )) {
      return preferred;
    }
    // Free users who finished the free gate: keep daily as the CTA.
    if (!_store.dailyDoneToday) {
      return PathCatalogStore.instance.dailyLevel;
    }
    for (final level in PathCatalogStore.instance.levels) {
      if (_statusFor(level) == PathLevelStatus.current) return level;
    }
    return null;
  }
}

class _EmptyPathState extends StatelessWidget {
  const _EmptyPathState({required this.gradeLabel});

  final String gradeLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 56, color: Colors.white.withValues(alpha: 0.35)),
          const SizedBox(height: 16),
          Text(
            'No gates for $gradeLabel yet',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your Path will appear here once gates are published in the admin dashboard. Daily streak still works.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ArenaHud extends StatelessWidget {
  const _ArenaHud({
    required this.ready,
    required this.arenaTitle,
    required this.cleared,
    required this.total,
    required this.xp,
    required this.energy,
    required this.streak,
    required this.stars,
    required this.maxStars,
    required this.dailyDone,
    required this.onDaily,
    required this.onBack,
  });

  final bool ready;
  final String arenaTitle;
  final int cleared;
  final int total;
  final int xp;
  final int energy;
  final int streak;
  final int stars;
  final int maxStars;
  final bool dailyDone;
  final VoidCallback onDaily;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final progress = maxStars == 0 ? 0.0 : stars / maxStars;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 10),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                color: Colors.white,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'THE PATH',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.4,
                        color: AppColors.amber,
                      ),
                    ),
                    Text(
                      arenaTitle,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        color: Colors.white,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
              if (ready) ...[
                _HudChip(
                  icon: Icons.favorite_rounded,
                  label: '$energy',
                  color: AppColors.danger,
                ),
                const SizedBox(width: 6),
                _HudChip(
                  icon: Icons.local_fire_department_rounded,
                  label: '$streak',
                  color: AppColors.amber,
                ),
              ],
            ],
          ),
          if (ready) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _HudChip(
                  icon: Icons.bolt_rounded,
                  label: '$xp XP',
                  color: AppColors.amber,
                ),
                const SizedBox(width: 6),
                _HudChip(
                  icon: Icons.star_rounded,
                  label: '$stars/$maxStars',
                  color: AppColors.teal,
                ),
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: dailyDone ? null : onDaily,
                    borderRadius: BorderRadius.circular(14),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: dailyDone
                            ? Colors.white.withValues(alpha: 0.06)
                            : AppColors.teal.withValues(alpha: 0.2),
                        border: Border.all(
                          color: dailyDone
                              ? Colors.white24
                              : AppColors.teal.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        dailyDone ? 'Daily done' : 'Daily gate',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: dailyDone ? Colors.white54 : AppColors.teal,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ready ? progress : 0,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              color: AppColors.amber,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              ready
                  ? (cleared == 0
                      ? 'Clear Stage 1 to unlock the trail. Chase 3 stars to return.'
                      : 'Gates $cleared/$total · star hunt ${(progress * 100).round()}%')
                  : 'Loading arena…',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  const _HudChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueBar extends StatelessWidget {
  const _ContinueBar({
    required this.level,
    required this.stars,
    required this.onPlay,
  });

  final PathLevel level;
  final int stars;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final isDaily = level.id == kPathDailyId;
    final label = isDaily
        ? 'DAILY STREAK'
        : stars > 0 && stars < 3
            ? 'CHASE 3 STARS'
            : 'CONTINUE';
    final subtitle = isDaily
        ? level.title
        : 'Level ${level.number} · ${level.title}';

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPlay,
            child: Ink(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.amber.withValues(alpha: 0.45),
                ),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1A1408).withValues(alpha: 0.92),
                    const Color(0xFF0E1620).withValues(alpha: 0.92),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          pathKindColor(level.kind),
                          pathKindColor(level.kind).withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        isDaily
                            ? Icons.local_fire_department_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                            color: AppColors.amber,
                          ),
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.amber,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'PLAY',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: const Color(0xFF1A1200),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PathTrail extends StatelessWidget {
  const _PathTrail({
    required this.levels,
    required this.statusFor,
    required this.starsFor,
    required this.onTap,
    required this.pulse,
    required this.fullAccess,
  });

  final List<PathLevel> levels;
  final PathLevelStatus Function(PathLevel) statusFor;
  final int Function(String levelId) starsFor;
  final ValueChanged<PathLevel> onTap;
  final Animation<double> pulse;
  final bool fullAccess;

  static const _rowHeight = 132.0;

  double _alignX(int index) => index.isEven ? 0.24 : 0.76;

  @override
  Widget build(BuildContext context) {
    final height = levels.length * _rowHeight + 80;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final centers = <Offset>[
            for (var i = 0; i < levels.length; i++)
              Offset(width * _alignX(i), 48 + i * _rowHeight + 40),
          ];

          return Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                size: Size(width, height),
                painter: _PathConnectorPainter(
                  points: centers,
                  statuses: [for (final level in levels) statusFor(level)],
                ),
              ),
              for (var i = 0; i < levels.length; i++)
                if (levels[i].arenaLabel != null &&
                    levels[i].arenaLabel!.trim().isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: centers[i].dy - 78,
                    child: _WorldBanner(
                      label: levels[i].arenaLabel!,
                      locked: !fullAccess &&
                          ContentAccess.isPathLevelPaywalled(
                            levels[i],
                            fullAccess: fullAccess,
                            sameGradeLevels: levels
                                .where((l) => l.gradeId == levels[i].gradeId)
                                .toList(),
                          ),
                    ),
                  ),
              for (var i = 0; i < levels.length; i++)
                Positioned(
                  left: centers[i].dx - 42,
                  top: centers[i].dy - 42,
                  child: _LevelNode(
                    level: levels[i],
                    status: statusFor(levels[i]),
                    stars: starsFor(levels[i].id),
                    onTap: () => onTap(levels[i]),
                    pulse: pulse,
                  ),
                ),
              for (var i = 0; i < levels.length; i++)
                _captionFor(
                  index: i,
                  width: width,
                  center: centers[i],
                  level: levels[i],
                  status: statusFor(levels[i]),
                  stars: starsFor(levels[i].id),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _captionFor({
    required int index,
    required double width,
    required Offset center,
    required PathLevel level,
    required PathLevelStatus status,
    required int stars,
  }) {
    final onLeft = _alignX(index) < 0.5;
    return Positioned(
      left: onLeft ? center.dx + 54 : 12,
      right: onLeft ? 12 : width - center.dx + 54,
      top: center.dy - 22,
      child: _LevelCaption(
        level: level,
        status: status,
        stars: stars,
        alignEnd: !onLeft,
      ),
    );
  }
}

class _WorldBanner extends StatelessWidget {
  const _WorldBanner({
    required this.label,
    this.locked = false,
  });

  final String label;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final accent = locked ? AppColors.textMuted : AppColors.amber;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: 0.2),
              AppColors.accent.withValues(alpha: locked ? 0.06 : 0.12),
            ],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (locked) ...[
              Icon(Icons.lock_rounded, size: 12, color: accent),
              const SizedBox(width: 6),
            ],
            Text(
              locked ? '$label · SUBSCRIBE' : label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelCaption extends StatelessWidget {
  const _LevelCaption({
    required this.level,
    required this.status,
    required this.stars,
    required this.alignEnd,
  });

  final PathLevel level;
  final PathLevelStatus status;
  final int stars;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final muted = status == PathLevelStatus.locked;
    final kindLabel = switch (level.kind) {
      PathLevelKind.boss => 'BOSS',
      PathLevelKind.checkpoint => 'GATE',
      PathLevelKind.standard => 'STAGE',
    };

    final statusLine = status == PathLevelStatus.cleared
        ? (stars >= 3 ? '3★ PERFECT' : '$stars★ · REPLAY')
        : status == PathLevelStatus.current
            ? 'YOUR MOVE'
            : 'LOCKED';

    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          kindLabel,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: muted
                ? Colors.white.withValues(alpha: 0.28)
                : pathKindColor(level.kind),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          level.title,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: muted
                ? Colors.white.withValues(alpha: 0.35)
                : Colors.white,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          statusLine,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: status == PathLevelStatus.current
                ? AppColors.amber
                : Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}

class _LevelNode extends StatelessWidget {
  const _LevelNode({
    required this.level,
    required this.status,
    required this.stars,
    required this.onTap,
    required this.pulse,
  });

  final PathLevel level;
  final PathLevelStatus status;
  final int stars;
  final VoidCallback onTap;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final kindColor = pathKindColor(level.kind);
    final locked = status == PathLevelStatus.locked;
    final cleared = status == PathLevelStatus.cleared;
    final current = status == PathLevelStatus.current;
    final size = level.kind == PathLevelKind.boss ? 92.0 : 84.0;

    Widget node = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: locked
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1A1C24),
                  const Color(0xFF101218),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  kindColor.withValues(alpha: cleared ? 0.55 : 0.95),
                  kindColor.withValues(alpha: cleared ? 0.25 : 0.55),
                  const Color(0xFF0B0D14),
                ],
                stops: const [0, 0.45, 1],
              ),
        border: Border.all(
          color: locked
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: current ? 0.7 : 0.28),
          width: current ? 3 : 2,
        ),
        boxShadow: locked
            ? null
            : [
                BoxShadow(
                  color: kindColor.withValues(alpha: current ? 0.55 : 0.28),
                  blurRadius: current ? 26 : 14,
                  spreadRadius: current ? 2 : 0,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 10,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!locked)
            Positioned(
              top: 10,
              left: 14,
              child: Container(
                width: 16,
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withValues(alpha: 0.22),
                ),
              ),
            ),
          if (locked)
            Icon(
              Icons.lock_rounded,
              size: 26,
              color: Colors.white.withValues(alpha: 0.35),
            )
          else if (cleared)
            Icon(Icons.check_rounded, size: 34, color: Colors.white)
          else if (level.kind == PathLevelKind.boss)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 22,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                Text(
                  '${level.number}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ],
            )
          else
            Text(
              '${level.number}',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );

    if (current) {
      node = AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          final scale = 1 + (pulse.value * 0.06);
          return Transform.scale(scale: scale, child: child);
        },
        child: node,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 92,
        height: 110,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              bottom: 14,
              child: Container(
                width: size * 0.72,
                height: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: Colors.black.withValues(alpha: 0.45),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
            node,
            if (cleared)
              Positioned(
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 1; i <= 3; i++)
                      Icon(
                        i <= stars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 12,
                        color: i <= stars
                            ? AppColors.amber
                            : Colors.white38,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ArenaBackdropPainter extends CustomPainter {
  _ArenaBackdropPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0B1020),
            Color(0xFF07090F),
            Color(0xFF05060C),
          ],
        ).createShader(rect),
    );

    void blob(Offset c, double r, Color color) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 48),
      );
    }

    blob(
      Offset(size.width * 0.15, size.height * (0.18 + 0.02 * math.sin(t * math.pi * 2))),
      120,
      AppColors.accent.withValues(alpha: 0.16),
    );
    blob(
      Offset(size.width * 0.9, size.height * (0.35 + 0.03 * math.cos(t * math.pi * 2))),
      140,
      AppColors.amber.withValues(alpha: 0.12),
    );
    blob(
      Offset(size.width * 0.5, size.height * 0.75),
      160,
      AppColors.teal.withValues(alpha: 0.08),
    );

    final star = Paint()..color = Colors.white.withValues(alpha: 0.14);
    for (var i = 0; i < 28; i++) {
      final x = (i * 97.3) % size.width;
      final y = (i * 61.7 + t * 40) % size.height;
      canvas.drawCircle(Offset(x, y), i.isEven ? 1.4 : 0.9, star);
    }
  }

  @override
  bool shouldRepaint(covariant _ArenaBackdropPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _PathConnectorPainter extends CustomPainter {
  _PathConnectorPainter({
    required this.points,
    required this.statuses,
  });

  final List<Offset> points;
  final List<PathLevelStatus> statuses;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final unlocked = statuses[i] == PathLevelStatus.cleared ||
          statuses[i + 1] != PathLevelStatus.locked;

      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx, mid.dy, b.dx, mid.dy, b.dx, b.dy);

      if (unlocked) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 14
            ..strokeCap = StrokeCap.round
            ..color = AppColors.amber.withValues(alpha: 0.14)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = unlocked ? 8 : 5
          ..strokeCap = StrokeCap.round
          ..color = unlocked
              ? AppColors.amber.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.12),
      );

      if (unlocked) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withValues(alpha: 0.35),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PathConnectorPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.statuses != statuses;
  }
}
