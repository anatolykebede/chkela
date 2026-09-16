import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../data/ai_api.dart';
import '../../data/ai_study_context.dart';
import '../../data/content_access.dart';
import '../../data/path_challenges.dart';
import '../../data/path_levels.dart';
import '../../data/path_catalog.dart';
import '../../data/path_progress_store.dart';
import '../../features/ai/ai_coach_sheet.dart';
import '../../features/subscription/subscription_flow.dart';

class PathLevelPlayScreen extends ConsumerStatefulWidget {
  const PathLevelPlayScreen({super.key, required this.levelId});

  final String levelId;

  @override
  ConsumerState<PathLevelPlayScreen> createState() =>
      _PathLevelPlayScreenState();
}

class _PathLevelPlayScreenState extends ConsumerState<PathLevelPlayScreen>
    with TickerProviderStateMixin {
  final _store = PathProgressStore.instance;
  PathLevel? _level;
  List<PathChallenge> _run = const [];
  var _wave = 0;
  var _playerHp = 3;
  var _playerMax = 3;
  var _gateHp = 0;
  var _gateMax = 0;
  var _combo = 0;
  var _bestCombo = 0;
  var _finished = false;
  var _won = false;
  var _showHook = true;
  var _blocked = false;
  var _locked = false;
  var _paywalled = false;
  var _energySpent = false;
  var _waveFlash = true;
  var _hitFlash = false;
  final _missedSkills = <String>[];
  PathAttemptResult? _result;
  var _stars = 0;
  AnimationController? _shake;
  AnimationController? _pulse;

  bool get _isDaily => widget.levelId == kPathDailyId;
  PathChallenge? get _current =>
      _wave < _run.length ? _run[_wave] : null;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _boot();
  }

  @override
  void dispose() {
    if (_energySpent && !_finished) {
      // Quit after paying, before a recorded attempt: refund.
      _store.refundEnergy();
    }
    _shake?.dispose();
    _pulse?.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    await _store.load();
    PathCatalogStore.instance.setViewerGrade(ref.read(selectedGradeProvider));
    await PathCatalogStore.instance.load();
    final level = PathCatalogStore.instance.levelById(widget.levelId);
    if (level == null) {
      if (mounted) setState(() => _level = null);
      return;
    }
    final fullAccess =
        ref.read(fullContentAccessProvider).valueOrNull ?? false;
    final sameGrade = PathCatalogStore.instance.levels
        .where((l) => l.gradeId == level.gradeId)
        .toList();
    if (!_isDaily &&
        ContentAccess.isPathLevelPaywalled(
          level,
          fullAccess: fullAccess,
          sameGradeLevels: sameGrade,
        )) {
      if (mounted) {
        setState(() {
          _level = level;
          _paywalled = true;
          _locked = true;
          _blocked = true;
        });
      }
      return;
    }
    if (!_isDaily &&
        _store.statusFor(level) == PathLevelStatus.locked) {
      if (mounted) {
        setState(() {
          _level = level;
          _locked = true;
          _blocked = true;
        });
      }
      return;
    }
    if (_store.energy <= 0) {
      if (mounted) {
        setState(() {
          _level = level;
          _blocked = true;
        });
      }
      return;
    }
    final run = _isDaily
        ? PathCatalogStore.instance.resolveDaily(_store.weakSkillTags)
        : PathCatalogStore.instance.resolveChallenges(level);
    if (!mounted) return;
    setState(() {
      _level = level;
      _run = run;
      _playerMax = playerMaxHp(level.kind);
      _playerHp = _playerMax;
      _gateMax = gateMaxHp(run);
      _gateHp = _gateMax;
      _showHook = true;
    });
  }

  Future<void> _beginChallenge() async {
    if (!_store.canPlay) {
      setState(() => _blocked = true);
      return;
    }
    final spent = await _store.spendEnergy();
    if (!spent) {
      if (mounted) setState(() => _blocked = true);
      return;
    }
    _energySpent = true;
    if (mounted) {
      setState(() {
        _showHook = false;
        _waveFlash = true;
      });
    }
  }

  Future<void> _onChallengeResult({
    required bool success,
    String? skillTag,
  }) async {
    if (_finished) return;

    if (success) {
      HapticFeedback.mediumImpact();
      setState(() {
        _combo += 1;
        if (_combo > _bestCombo) _bestCombo = _combo;
        _gateHp = (_gateHp - 1).clamp(0, _gateMax);
        _waveFlash = false;
        _hitFlash = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (!mounted) return;
      setState(() => _hitFlash = false);
    } else {
      HapticFeedback.heavyImpact();
      _shake?.forward(from: 0);
      setState(() {
        _combo = 0;
        _playerHp = (_playerHp - 1).clamp(0, _playerMax);
        if (skillTag != null && skillTag.isNotEmpty) {
          _missedSkills.add(skillTag);
        }
      });
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    if (!mounted) return;

    if (_playerHp <= 0) {
      await _finish(won: false);
      return;
    }
    if (_gateHp <= 0) {
      await _finish(won: true);
      return;
    }

    final next = _wave + 1;
    if (next >= _run.length) {
      await _finish(won: _gateHp <= 0);
      return;
    }
    setState(() {
      _wave = next;
      _waveFlash = true;
    });
  }

  Future<void> _finish({required bool won}) async {
    if (_finished) return;
    _finished = true;
    _energySpent = false;
    final level = _level!;
    final stars = starsFromCombat(
      playerHpLeft: _playerHp,
      playerHpMax: _playerMax,
      gateCleared: won,
      kind: level.kind,
    );
    final result = await _store.recordAttempt(
      level: level,
      stars: stars,
      xpGained: xpForStars(level, stars),
      missedSkills: _missedSkills,
      isDaily: _isDaily,
    );
    if (!mounted) return;
    setState(() {
      _won = won;
      _stars = stars;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final level = _level;
    if (level == null && !_blocked) {
      return const Scaffold(
        backgroundColor: Color(0xFF05060C),
        body: Center(child: CircularProgressIndicator(color: AppColors.amber)),
      );
    }
    if (level == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF05060C),
        body: Center(
          child: Text('Level not found',
              style: GoogleFonts.inter(color: Colors.white)),
        ),
      );
    }

    if (_blocked) return _blockedBody();
    if (_finished) return _resultBody(level);
    if (_showHook) return _hookBody(level);

    final challenge = _current;
    if (challenge == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF05060C),
        body: SizedBox.shrink(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF05060C),
      body: Stack(
        children: [
          const _ArenaGlow(),
          SafeArea(
            child: Column(
              children: [
                _CombatHud(
                  level: level,
                  isDaily: _isDaily,
                  playerHp: _playerHp,
                  playerMax: _playerMax,
                  gateHp: _gateHp,
                  gateMax: _gateMax,
                  combo: _combo,
                  wave: _wave + 1,
                  total: _run.length,
                  onClose: () => context.pop(),
                  hitFlash: _hitFlash,
                ),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _shake!,
                    builder: (context, child) {
                      final t = _shake!.value;
                      final dx = math.sin(t * math.pi * 6) * 8 * (1 - t);
                      return Transform.translate(
                        offset: Offset(dx, 0),
                        child: child,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        children: [
                          _WaveBanner(
                            label: challenge.waveLabel,
                            color: pathKindColor(level.kind),
                            pulse: _pulse!,
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 280),
                              child: KeyedSubtree(
                                key: ValueKey('wave-$_wave'),
                                child: _ChallengeHost(
                                  challenge: challenge,
                                  onResult: _onChallengeResult,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_waveFlash)
            _WaveSplash(
              label: challenge.waveLabel,
              onDone: () {
                if (mounted) setState(() => _waveFlash = false);
              },
            ),
        ],
      ),
    );
  }

  Widget _blockedBody() {
    final locked = _locked;
    final paywalled = _paywalled;
    return Scaffold(
      backgroundColor: const Color(0xFF05060C),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
              const Spacer(),
              Icon(
                locked ? Icons.lock_outline_rounded : Icons.favorite_border_rounded,
                size: 64,
                color: locked ? AppColors.amber : AppColors.danger,
              ),
              const SizedBox(height: 16),
              Text(
                paywalled
                    ? 'Subscribe to continue'
                    : locked
                        ? 'Gate locked'
                        : 'Out of energy',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                paywalled
                    ? 'The first Path gate is free. Subscribe to unlock the rest of the trail.'
                    : locked
                        ? 'Clear the previous gate in this grade to unlock this battle.'
                        : (_store.energyRefillLabel.isEmpty
                            ? 'Energy refills over time (1 every 10 min). Come back to keep your streak alive.'
                            : '${_store.energyRefillLabel}. Come back to keep your streak alive.'),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
              ),
              const Spacer(),
              if (paywalled) ...[
                FilledButton(
                  onPressed: () => openSubscriptionFlow(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: const Color(0xFF1A1200),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'View subscription plans',
                    style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => context.pop(),
                  child: Text(
                    'Back to Arena',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ] else
                FilledButton(
                  onPressed: () => context.pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: const Color(0xFF1A1200),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Back to Arena',
                    style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hookBody(PathLevel level) {
    return Scaffold(
      backgroundColor: const Color(0xFF05060C),
      body: Stack(
        children: [
          const _ArenaGlow(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _isDaily
                        ? 'DAILY RAID'
                        : switch (level.kind) {
                            PathLevelKind.boss => 'BOSS BATTLE',
                            PathLevelKind.checkpoint => 'CHECKPOINT RAID',
                            PathLevelKind.standard => 'STAGE BATTLE',
                          },
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: pathKindColor(level.kind),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    level.title,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    level.competency,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.amber,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      level.hook,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        height: 1.45,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ModeChip(label: 'STRIKE', color: AppColors.accent),
                      _ModeChip(label: 'BLITZ', color: AppColors.amber),
                      _ModeChip(label: 'LINK', color: AppColors.teal),
                      _ModeChip(label: 'SEQUENCE', color: Colors.purpleAccent),
                      _ModeChip(label: 'ANSWER', color: Colors.lightBlueAccent),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '$_gateMax waves · $_playerMax hearts · 1 energy',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _beginChallenge,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.amber,
                      foregroundColor: const Color(0xFF1A1200),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Enter battle',
                      style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultBody(PathLevel level) {
    return Scaffold(
      backgroundColor: const Color(0xFF05060C),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                _won ? Icons.emoji_events_rounded : Icons.heart_broken_rounded,
                size: 64,
                color: _won ? AppColors.amber : AppColors.danger,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 3; i++)
                    Icon(
                      i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 36,
                      color: i <= _stars ? AppColors.amber : Colors.white24,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _won
                    ? (_stars == 3 ? 'Flawless victory!' : 'Gate defeated!')
                    : 'Defeated. Retry the gate.',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hearts left $_playerHp/$_playerMax · Best combo x$_bestCombo'
                '${(_result?.xpGained ?? 0) > 0 ? ' · +${_result!.xpGained} XP' : ''}'
                '\nStreak ${_result?.streak ?? _store.liveStreak}',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.45,
                  color: Colors.white70,
                ),
              ),
              if (_won && _stars < 3 && !_isDaily) ...[
                const SizedBox(height: 12),
                Text(
                  'Replay with full hearts for 3 stars.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.amber.withValues(alpha: 0.9),
                  ),
                ),
              ],
              const Spacer(),
              FilledButton(
                onPressed: () => context.pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: const Color(0xFF1A1200),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Back to The Path',
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ArenaGlow extends StatelessWidget {
  const _ArenaGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.1,
            colors: [Color(0xFF1A1408), Color(0xFF05060C)],
          ),
        ),
      ),
    );
  }
}

class _CombatHud extends StatelessWidget {
  const _CombatHud({
    required this.level,
    required this.isDaily,
    required this.playerHp,
    required this.playerMax,
    required this.gateHp,
    required this.gateMax,
    required this.combo,
    required this.wave,
    required this.total,
    required this.onClose,
    required this.hitFlash,
  });

  final PathLevel level;
  final bool isDaily;
  final int playerHp;
  final int playerMax;
  final int gateHp;
  final int gateMax;
  final int combo;
  final int wave;
  final int total;
  final VoidCallback onClose;
  final bool hitFlash;

  @override
  Widget build(BuildContext context) {
    final gateColor = pathKindColor(level.kind);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDaily ? 'DAILY RAID' : 'WAVE $wave/$total',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: AppColors.amber,
                      ),
                    ),
                    Text(
                      level.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (combo > 1)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.amber),
                  ),
                  child: Text(
                    'x$combo COMBO',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: AppColors.amber,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < playerMax; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    i < playerHp
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 18,
                    color: i < playerHp ? AppColors.danger : Colors.white24,
                  ),
                ),
              const Spacer(),
              Text(
                'GATE',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white54,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              child: LinearProgressIndicator(
                value: gateMax == 0 ? 0 : gateHp / gateMax,
                minHeight: 10,
                backgroundColor: Colors.white12,
                color: hitFlash ? Colors.white : gateColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveBanner extends StatelessWidget {
  const _WaveBanner({
    required this.label,
    required this.color,
    required this.pulse,
  });

  final String label;
  final Color color;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: 0.35 + pulse.value * 0.25),
            ),
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0.04),
              ],
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
              color: color,
            ),
          ),
        );
      },
    );
  }
}

class _WaveSplash extends StatefulWidget {
  const _WaveSplash({required this.label, required this.onDone});
  final String label;
  final VoidCallback onDone;

  @override
  State<_WaveSplash> createState() => _WaveSplashState();
}

class _WaveSplashState extends State<_WaveSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final opacity = t < 0.55 ? t / 0.55 : (1 - t) / 0.45;
          return Container(
            color: Colors.black.withValues(alpha: 0.55 * opacity.clamp(0, 1)),
            alignment: Alignment.center,
            child: Transform.scale(
              scale: 0.85 + t * 0.35,
              child: Text(
                widget.label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                  color: AppColors.amber.withValues(alpha: opacity.clamp(0, 1)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChallengeHost extends StatelessWidget {
  const _ChallengeHost({
    required this.challenge,
    required this.onResult,
  });

  final PathChallenge challenge;
  final Future<void> Function({required bool success, String? skillTag})
      onResult;

  @override
  Widget build(BuildContext context) {
    return switch (challenge) {
      StrikeChallenge c => _StrikeView(challenge: c, onResult: onResult),
      BlitzChallenge c => _BlitzView(challenge: c, onResult: onResult),
      LinkChallenge c => _LinkView(challenge: c, onResult: onResult),
      SequenceChallenge c => _SequenceView(challenge: c, onResult: onResult),
      AnswerChallenge c => _AnswerView(challenge: c, onResult: onResult),
    };
  }
}

class _StrikeView extends StatefulWidget {
  const _StrikeView({required this.challenge, required this.onResult});
  final StrikeChallenge challenge;
  final Future<void> Function({required bool success, String? skillTag})
      onResult;

  @override
  State<_StrikeView> createState() => _StrikeViewState();
}

class _StrikeViewState extends State<_StrikeView> {
  int? _picked;
  var _locked = false;

  Future<void> _pick(int i) async {
    if (_locked) return;
    setState(() {
      _picked = i;
      _locked = true;
    });
    final ok = i == widget.challenge.correctIndex;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!ok && mounted) {
      final c = widget.challenge;
      final student = c.options[i];
      final correct = c.options[c.correctIndex];
      await AiWeakSpotStore.record(
        subject: 'Path',
        chapter: c.skillTag,
        question: c.prompt,
        studentAnswer: student,
        correctAnswer: correct,
      );
      if (!mounted) return;
      await showAiCoachSheet(
        context,
        title: 'Path coach',
        load: () => AiApi().coachWrongAnswer(
          question: c.prompt,
          options: c.options,
          studentAnswer: student,
          correctAnswer: correct,
          context: AiStudyContext(
            subject: 'Path',
            chapter: c.skillTag,
            note: c.prompt,
          ),
        ),
      );
    }
    if (!mounted) return;
    await widget.onResult(
      success: ok,
      skillTag: ok ? null : widget.challenge.skillTag,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          c.prompt,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.35,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: ListView(
            children: [
              for (var i = 0; i < c.options.length; i++) ...[
                _ArenaOption(
                  label: c.options[i],
                  selected: _picked == i,
                  locked: _locked,
                  correct: i == c.correctIndex,
                  onTap: () => _pick(i),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BlitzView extends StatefulWidget {
  const _BlitzView({required this.challenge, required this.onResult});
  final BlitzChallenge challenge;
  final Future<void> Function({required bool success, String? skillTag})
      onResult;

  @override
  State<_BlitzView> createState() => _BlitzViewState();
}

class _BlitzViewState extends State<_BlitzView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timer;
  var _locked = false;

  @override
  void initState() {
    super.initState();
    _timer = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.challenge.seconds),
    )..forward().whenComplete(() {
        if (!_locked && mounted) _answer(null);
      });
  }

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  Future<void> _answer(bool? value) async {
    if (_locked) return;
    _locked = true;
    _timer.stop();
    final ok = value != null && value == widget.challenge.isTrue;
    if (!ok && mounted) {
      final c = widget.challenge;
      final student = value == null
          ? 'Timed out'
          : (value ? 'True' : 'False');
      final correct = c.isTrue ? 'True' : 'False';
      await AiWeakSpotStore.record(
        subject: 'Path',
        chapter: c.skillTag,
        question: c.prompt,
        studentAnswer: student,
        correctAnswer: correct,
      );
      if (!mounted) return;
      await showAiCoachSheet(
        context,
        title: 'Path coach',
        load: () => AiApi().coachWrongAnswer(
          question: c.prompt,
          options: const ['True', 'False'],
          studentAnswer: student,
          correctAnswer: correct,
          context: AiStudyContext(
            subject: 'Path',
            chapter: c.skillTag,
            note: c.prompt,
          ),
        ),
      );
    }
    if (!mounted) return;
    await widget.onResult(
      success: ok,
      skillTag: ok ? null : widget.challenge.skillTag,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedBuilder(
          animation: _timer,
          builder: (context, _) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: 1 - _timer.value,
                minHeight: 8,
                backgroundColor: Colors.white12,
                color: _timer.value > 0.7 ? AppColors.danger : AppColors.amber,
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          widget.challenge.prompt,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.35,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: _BigAnswerButton(
                label: 'FALSE',
                color: AppColors.danger,
                onTap: () => _answer(false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BigAnswerButton(
                label: 'TRUE',
                color: AppColors.teal,
                onTap: () => _answer(true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BigAnswerButton extends StatelessWidget {
  const _BigAnswerButton({
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.85),
                color.withValues(alpha: 0.45),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkView extends StatefulWidget {
  const _LinkView({required this.challenge, required this.onResult});
  final LinkChallenge challenge;
  final Future<void> Function({required bool success, String? skillTag})
      onResult;

  @override
  State<_LinkView> createState() => _LinkViewState();
}

class _LinkViewState extends State<_LinkView> {
  late final List<String> _left;
  late final List<String> _right;
  final _matchedLeft = <String>{};
  String? _selectedLeft;
  String? _selectedRight;
  var _mistakes = 0;
  var _locked = false;

  @override
  void initState() {
    super.initState();
    final pairs = widget.challenge.pairs;
    _left = pairs.keys.toList()..shuffle(math.Random(7));
    _right = pairs.values.toList()..shuffle(math.Random(11));
  }

  Future<void> _tapLeft(String value) async {
    if (_locked || _matchedLeft.contains(value)) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedLeft = value);
    await _tryMatch();
  }

  Future<void> _tapRight(String value) async {
    if (_locked || _rightMatched(value)) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedRight = value);
    await _tryMatch();
  }

  Future<void> _tryMatch() async {
    final l = _selectedLeft;
    final r = _selectedRight;
    if (l == null || r == null) return;
    final expected = widget.challenge.pairs[l];
    if (expected == r) {
      setState(() {
        _matchedLeft.add(l);
        _selectedLeft = null;
        _selectedRight = null;
      });
      HapticFeedback.mediumImpact();
      if (_matchedLeft.length == widget.challenge.pairs.length) {
        _locked = true;
        await Future<void>.delayed(const Duration(milliseconds: 350));
        await widget.onResult(success: true);
      }
    } else {
      _mistakes++;
      HapticFeedback.heavyImpact();
      setState(() {
        _selectedLeft = null;
        _selectedRight = null;
      });
      if (_mistakes >= 2) {
        _locked = true;
        await widget.onResult(
          success: false,
          skillTag: widget.challenge.skillTag,
        );
      }
    }
  }

  bool _rightMatched(String value) {
    return widget.challenge.pairs.entries
        .any((e) => _matchedLeft.contains(e.key) && e.value == value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Match each term to its meaning',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Two misses and the gate strikes back',
          style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    for (final item in _left)
                      _LinkTile(
                        label: item,
                        selected: _selectedLeft == item,
                        matched: _matchedLeft.contains(item),
                        onTap: () => _tapLeft(item),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ListView(
                  children: [
                    for (final item in _right)
                      _LinkTile(
                        label: item,
                        selected: _selectedRight == item,
                        matched: _rightMatched(item),
                        onTap: () => _tapRight(item),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.label,
    required this.selected,
    required this.matched,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool matched;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color border = Colors.white24;
    Color bg = Colors.white.withValues(alpha: 0.06);
    if (matched) {
      border = AppColors.teal;
      bg = AppColors.teal.withValues(alpha: 0.2);
    } else if (selected) {
      border = AppColors.amber;
      bg = AppColors.amber.withValues(alpha: 0.18);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: matched ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SequenceView extends StatefulWidget {
  const _SequenceView({required this.challenge, required this.onResult});
  final SequenceChallenge challenge;
  final Future<void> Function({required bool success, String? skillTag})
      onResult;

  @override
  State<_SequenceView> createState() => _SequenceViewState();
}

class _SequenceViewState extends State<_SequenceView> {
  late final List<String> _pool;
  final _picked = <String>[];
  var _locked = false;

  @override
  void initState() {
    super.initState();
    _pool = [...widget.challenge.stepsInOrder]..shuffle(math.Random(3));
  }

  Future<void> _tap(String step) async {
    if (_locked || _picked.contains(step)) return;
    final nextIndex = _picked.length;
    final expected = widget.challenge.stepsInOrder[nextIndex];
    if (step != expected) {
      _locked = true;
      HapticFeedback.heavyImpact();
      await widget.onResult(
        success: false,
        skillTag: widget.challenge.skillTag,
      );
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _picked.add(step));
    if (_picked.length == widget.challenge.stepsInOrder.length) {
      _locked = true;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await widget.onResult(success: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.challenge.title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tap the steps in the correct order',
          style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
        ),
        const SizedBox(height: 12),
        if (_picked.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < _picked.length; i++)
                Chip(
                  backgroundColor: AppColors.teal.withValues(alpha: 0.2),
                  label: Text(
                    '${i + 1}. ${_picked[i]}',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              for (final step in _pool)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ArenaOption(
                    label: step,
                    selected: _picked.contains(step),
                    locked: _picked.contains(step),
                    correct: _picked.contains(step),
                    onTap: () => _tap(step),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnswerView extends StatefulWidget {
  const _AnswerView({required this.challenge, required this.onResult});
  final AnswerChallenge challenge;
  final Future<void> Function({required bool success, String? skillTag})
      onResult;

  @override
  State<_AnswerView> createState() => _AnswerViewState();
}

class _AnswerViewState extends State<_AnswerView> {
  final _controller = TextEditingController();
  var _locked = false;
  var _showFeedback = false;
  var _correct = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_locked) return;
    final ok = widget.challenge.matches(_controller.text);
    setState(() {
      _locked = true;
      _showFeedback = true;
      _correct = ok;
    });
    if (ok) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    await Future<void>.delayed(const Duration(milliseconds: 550));
    await widget.onResult(
      success: ok,
      skillTag: ok ? null : widget.challenge.skillTag,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    final keyboard = c.inputKind == AnswerInputKind.number
        ? const TextInputType.numberWithOptions(decimal: true, signed: true)
        : TextInputType.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          c.prompt,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.35,
            color: Colors.white,
          ),
        ),
        if (c.hint != null && c.hint!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            c.hint!,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white54),
          ),
        ],
        const SizedBox(height: 22),
        TextField(
          controller: _controller,
          enabled: !_locked,
          keyboardType: keyboard,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          onChanged: (_) => setState(() {}),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: c.inputKind == AnswerInputKind.number
                ? 'Enter the number'
                : 'Type your answer',
            hintStyle: GoogleFonts.inter(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.amber, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: _correct ? AppColors.teal : AppColors.danger,
              ),
            ),
          ),
        ),
        if (_showFeedback) ...[
          const SizedBox(height: 12),
          Text(
            _correct
                ? 'Correct!'
                : 'Not quite. Answer: ${c.correctAnswer}',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: _correct ? AppColors.teal : AppColors.danger,
            ),
          ),
        ],
        const Spacer(),
        FilledButton(
          onPressed: _locked || _controller.text.trim().isEmpty ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.amber,
            disabledBackgroundColor: Colors.white12,
            foregroundColor: const Color(0xFF1A1200),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(
            'Submit',
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _ArenaOption extends StatelessWidget {
  const _ArenaOption({
    required this.label,
    required this.selected,
    required this.locked,
    required this.correct,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool locked;
  final bool correct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color border = Colors.white24;
    Color bg = Colors.white.withValues(alpha: 0.06);
    if (locked && selected && correct) {
      border = AppColors.teal;
      bg = AppColors.teal.withValues(alpha: 0.22);
    } else if (locked && selected && !correct) {
      border = AppColors.danger;
      bg = AppColors.danger.withValues(alpha: 0.22);
    } else if (locked && correct) {
      border = AppColors.teal.withValues(alpha: 0.5);
      bg = AppColors.teal.withValues(alpha: 0.12);
    } else if (selected) {
      border = AppColors.amber;
      bg = AppColors.amber.withValues(alpha: 0.16);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: locked && selected ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.amber.withValues(alpha: 0.2),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}
