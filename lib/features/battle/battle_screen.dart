import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/home_layout.dart';
import '../../core/theme/home_text_styles.dart';
import '../../data/battle_data.dart';
import '../../data/battle_setup_data.dart';
import '../../data/home_mock_data.dart';
import '../../data/study_subjects.dart';

enum _BattleView { lobby, live }

enum _LobbySort { newest, mostOpen }

class BattleScreen extends ConsumerStatefulWidget {
  const BattleScreen({super.key});

  @override
  ConsumerState<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends ConsumerState<BattleScreen> {
  _BattleView _view = _BattleView.lobby;
  final List<OpenBattle> _openBattles =
      List<OpenBattle>.from(initialOpenBattles);
  String? _filterSubject;
  String? _filterGrade;
  _LobbySort _lobbySort = _LobbySort.newest;
  OpenBattle? _activeBattle;
  BattleSetup? _activeSetup;

  int _questionIndex = 0;
  int? _selectedOption;
  bool _answered = false;
  int _secondsLeft = 15;
  Timer? _timer;

  int get _questionDuration => _activeSetup?.timeLimitSeconds ?? 15;
  int get _totalRounds => _activeSetup?.roundCount ?? 10;

  BattleQuestion get _question =>
      sampleBattleQuestions[_questionIndex % sampleBattleQuestions.length];

  @override
  void initState() {
    super.initState();
    _refreshOpenBattles();
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePendingLaunch());
  }

  /// Rebuilds battle list so new fields are valid after hot reload.
  void _refreshOpenBattles() {
    _openBattles
      ..clear()
      ..addAll(initialOpenBattles);
  }

  void _consumePendingLaunch() {
    final setup = ref.read(pendingBattleLaunchProvider);
    if (setup == null || !mounted) return;
    ref.read(pendingBattleLaunchProvider.notifier).state = null;
    _startFromSetup(setup);
  }

  void _startFromSetup(BattleSetup setup) {
    final battle = OpenBattle(
      id: setup.id,
      subjectName: setup.subjectName,
      hostName: setup.hostName,
      hostInitials: setup.hostInitials,
      hostGrade: setup.hostGrade,
      joinedCount: 1,
      maxPlayers: setup.maxPlayers,
      mode: setup.format == BattleFormat.oneVsOne
          ? BattleMode.duel
          : BattleMode.group,
      isHostedByCurrentUser: true,
      minutesAgo: 0,
      playerInitials: [setup.hostInitials],
    );

    setState(() {
      if (!_openBattles.any((b) => b.id == battle.id)) {
        _openBattles.insert(0, battle);
      }
      _activeSetup = setup;
      _activeBattle = battle;
      _view = _BattleView.live;
      _questionIndex = 0;
      _secondsLeft = setup.timeLimitSeconds;
    });
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsLeft = _questionDuration;
      _selectedOption = null;
      _answered = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _secondsLeft = 0;
          if (!_answered) _answered = true;
        });
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _selectOption(int index) {
    if (_answered) return;
    HapticFeedback.lightImpact();
    setState(() {
      _selectedOption = index;
      _answered = true;
    });
    _timer?.cancel();
  }

  void _nextQuestion() {
    HapticFeedback.mediumImpact();
    setState(() => _questionIndex++);
    _startTimer();
  }

  void _openCreateBattle() => context.push('/battle/create');

  List<String> get _subjectOptions => studySubjects
      .where((subject) => !subject.isLocked)
      .map((subject) => subject.name)
      .toList();

  bool get _hasActiveFilters =>
      _filterSubject != null || _filterGrade != null;

  OpenBattle _safeBattle(OpenBattle battle) {
    var elapsed = 0;
    var players = <String>[];
    try {
      elapsed = battle.elapsedMinutes;
    } catch (_) {
      elapsed = 0;
    }
    try {
      players = List<String>.from(battle.playerInitials);
    } catch (_) {
      players = [];
    }
    return OpenBattle(
      id: battle.id,
      subjectName: battle.subjectName,
      hostName: battle.hostName,
      hostInitials: battle.hostInitials,
      hostGrade: battle.hostGrade,
      joinedCount: battle.joinedCount,
      maxPlayers: battle.maxPlayers,
      mode: battle.mode,
      isHostedByCurrentUser: battle.isHostedByCurrentUser,
      minutesAgo: elapsed,
      playerInitials: players,
    );
  }

  Future<void> _refreshLobby() async {
    HapticFeedback.lightImpact();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(_refreshOpenBattles);
  }

  List<OpenBattle> get _visibleBattles {
    var battles = _openBattles.map(_safeBattle).toList();
    if (_filterSubject != null) {
      battles =
          battles.where((b) => b.subjectName == _filterSubject).toList();
    }
    if (_filterGrade != null) {
      battles = battles.where((b) => b.hostGrade == _filterGrade).toList();
    }
    battles.sort((a, b) {
      if (a.isHostedByCurrentUser != b.isHostedByCurrentUser) {
        return a.isHostedByCurrentUser ? -1 : 1;
      }
      return switch (_lobbySort) {
        _LobbySort.newest =>
          a.elapsedMinutes.compareTo(b.elapsedMinutes),
        _LobbySort.mostOpen => b.spotsLeft.compareTo(a.spotsLeft),
      };
    });

    return battles;
  }

  int get _joinableCount =>
      _openBattles.where((b) => !b.isFull && !b.isHostedByCurrentUser).length;

  int get _yourBattleCount =>
      _openBattles.where((b) => b.isHostedByCurrentUser).length;

  void _joinBattle(OpenBattle battle) {
    if (battle.isFull && !battle.isHostedByCurrentUser) return;

    HapticFeedback.lightImpact();
    final index = _openBattles.indexWhere((item) => item.id == battle.id);

    if (index != -1 && !battle.isHostedByCurrentUser) {
      _openBattles[index] =
          battle.copyWith(joinedCount: battle.joinedCount + 1);
    }

    final setup = defaultBattleSetup(subjectName: battle.subjectName);
    context.push('/battle/waiting', extra: setup);
  }

  void _enterWaitingRoom(OpenBattle battle) {
    final setup = defaultBattleSetup(subjectName: battle.subjectName);
    context.push('/battle/waiting', extra: setup);
  }

  void _leaveBattle() {
    _timer?.cancel();
    setState(() {
      _activeBattle = null;
      _activeSetup = null;
      _view = _BattleView.lobby;
      _questionIndex = 0;
      _selectedOption = null;
      _answered = false;
      _secondsLeft = 15;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        bottom: false,
        child: _view == _BattleView.lobby
            ? _buildLobby()
            : _buildLiveBattle(),
      ),
    );
  }

  Widget _buildLobby() {
    final visible = _visibleBattles;
    Widget battleCard(OpenBattle battle) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: _OpenBattleCard(
          battle: battle,
          onJoin: () => battle.isHostedByCurrentUser
              ? _enterWaitingRoom(battle)
              : _joinBattle(battle),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.bgElevated,
      onRefresh: _refreshLobby,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BattleHeader(
                    subtitle: 'Find a match or host your own',
                  ),
                  const SizedBox(height: 14),
                  _LobbyStatsStrip(
                    liveCount: _openBattles.length,
                    joinableCount: _joinableCount,
                    yourCount: _yourBattleCount,
                  ),
                  const SizedBox(height: 14),
                  _LobbyCreateBanner(onTap: _openCreateBattle),
                  const SizedBox(height: 12),
                  _LobbyFilterBar(
                    subjects: _subjectOptions,
                    grades: grades,
                    selectedSubject: _filterSubject,
                    selectedGrade: _filterGrade,
                    onSubjectChanged: (subject) =>
                        setState(() => _filterSubject = subject),
                    onGradeChanged: (grade) =>
                        setState(() => _filterGrade = grade),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    Text('OPEN BATTLES', style: HomeTextStyles.sectionLabel),
                    const SizedBox(width: 6),
                    _LiveCountBadge(count: visible.length),
                    const Spacer(),
                    _FilterChip(
                      label: 'Newest',
                      selected: _lobbySort == _LobbySort.newest,
                      compact: true,
                      onTap: () =>
                          setState(() => _lobbySort = _LobbySort.newest),
                    ),
                    const SizedBox(width: 4),
                    _FilterChip(
                      label: 'Open',
                      selected: _lobbySort == _LobbySort.mostOpen,
                      compact: true,
                      onTap: () =>
                          setState(() => _lobbySort = _LobbySort.mostOpen),
                    ),
                    if (_hasActiveFilters) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() {
                          _filterSubject = null;
                          _filterGrade = null;
                        }),
                        child: Text(
                          'Clear',
                          style: HomeTextStyles.seeAll.copyWith(fontSize: 10),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                if (_openBattles.isEmpty)
                  _LobbyEmptyState(onCreate: _openCreateBattle)
                else if (visible.isEmpty)
                  _LobbyNoResultsState(
                    subject: _filterSubject,
                    grade: _filterGrade,
                    onClear: () => setState(() {
                      _filterSubject = null;
                      _filterGrade = null;
                    }),
                  )
                else
                  ...visible.map(battleCard),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveBattle() {
    final battle = _activeBattle!;
    final subject = studySubjectByName(battle.subjectName);
    final progress = _secondsLeft / _questionDuration;
    final isCorrect = _selectedOption == _question.correctIndex;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BattleHeader(
            showBack: true,
            onBack: _leaveBattle,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Live · ${battle.subjectName} · Q${_questionIndex + 1} of $_totalRounds',
                style: HomeTextStyles.bodySmall.copyWith(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _VsCard(
            opponentName: battle.isHostedByCurrentUser
                ? 'Waiting...'
                : battle.hostName,
            opponentInitials:
                battle.isHostedByCurrentUser ? '?' : battle.hostInitials,
            opponentGrade:
                battle.isHostedByCurrentUser ? '' : battle.hostGrade,
          ),
          const SizedBox(height: 12),
          _TimerBar(progress: progress, secondsLeft: _secondsLeft),
          const SizedBox(height: 16),
          Text(
            _question.text,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(_question.options.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AnswerOption(
                label: String.fromCharCode(65 + index),
                text: _question.options[index],
                state: _optionState(index),
                onTap: () => _selectOption(index),
              ),
            );
          }),
          if (_answered) ...[
            const SizedBox(height: 8),
            _ExplanationBanner(
              isCorrect: isCorrect,
              explanation: _question.explanation,
            ),
          ],
          const SizedBox(height: 20),
          if (subject != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: subject.iconBg.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: subject.iconColor.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(subject.icon, color: subject.iconColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${battle.slotsLabel} · ${battleModeLabel(battle.mode)}',
                      style: HomeTextStyles.cardSub.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _answered ? _nextQuestion : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: _answered ? AppColors.accent : AppColors.bgElevated,
                borderRadius: BorderRadius.circular(12),
                border: _answered
                    ? null
                    : Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Center(
                child: Text(
                  _answered ? 'Next question' : 'Answer to continue',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _answered ? Colors.white : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _AnswerState _optionState(int index) {
    if (!_answered) return _AnswerState.idle;
    if (index == _question.correctIndex) return _AnswerState.correct;
    if (index == _selectedOption) return _AnswerState.wrong;
    return _AnswerState.idle;
  }
}

enum _AnswerState { idle, correct, wrong }

class _OpenBattleCard extends StatelessWidget {
  const _OpenBattleCard({
    required this.battle,
    required this.onJoin,
  });

  final OpenBattle battle;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final subject = studySubjectByName(battle.subjectName);
    final accent = subject?.iconColor ?? AppColors.accentText;
    final iconBg = subject?.iconBg ?? AppColors.accentSoft;
    final icon = subject?.icon ?? Icons.sports_esports_outlined;
    final canJoin = !battle.isFull;
    final urgency = battle.urgencyLabel;
    final actionLabel = battle.isHostedByCurrentUser
        ? 'Enter'
        : canJoin
            ? 'Join'
            : 'Full';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canJoin
            ? () {
                HapticFeedback.selectionClick();
                onJoin();
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: battle.isHostedByCurrentUser
                  ? AppColors.accent.withValues(alpha: 0.45)
                  : battle.isAlmostFull
                      ? AppColors.amber.withValues(alpha: 0.4)
                      : AppColors.border,
              width: 0.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accent, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const _LivePulseDot(size: 6),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              battle.subjectName,
                              style: HomeTextStyles.cardTitle.copyWith(
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (battle.isHostedByCurrentUser)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                'Yours',
                                style: HomeTextStyles.badge.copyWith(
                                  color: AppColors.accentText,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${battle.hostName} · ${battle.hostGrade} · '
                        '${battleModeLabel(battle.mode)} · ${battle.slotsLabel}',
                        style: HomeTextStyles.cardSub.copyWith(fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _PlayerAvatarStack(
                            initials: battle.displayPlayerInitials,
                            maxVisible: 3,
                            size: 20,
                            overlap: 7,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SlotsProgressBar(
                              fillRatio: battle.fillRatio,
                              joined: battle.joinedCount,
                              max: battle.maxPlayers,
                              accent: accent,
                              height: 3,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            battle.timeAgoLabel,
                            style: HomeTextStyles.cardSub.copyWith(fontSize: 9),
                          ),
                          if (urgency != null) ...[
                            const SizedBox(width: 4),
                            _UrgencyBadge(label: urgency),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _JoinButton(
                  label: actionLabel,
                  enabled: canJoin,
                  isPrimary: battle.isHostedByCurrentUser,
                  highlight: battle.isAlmostFull && canJoin,
                  compact: true,
                  onTap: onJoin,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LobbyStatsStrip extends StatelessWidget {
  const _LobbyStatsStrip({
    required this.liveCount,
    required this.joinableCount,
    required this.yourCount,
  });

  final int liveCount;
  final int joinableCount;
  final int yourCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: _LobbyStatTile(
              value: '$liveCount',
              label: 'Live now',
              icon: Icons.sensors,
              color: AppColors.danger,
            ),
          ),
          Container(width: 1, height: 42, color: AppColors.border),
          Expanded(
            child: _LobbyStatTile(
              value: '$joinableCount',
              label: 'Joinable',
              icon: Icons.group_add_outlined,
              color: AppColors.teal,
            ),
          ),
          Container(width: 1, height: 42, color: AppColors.border),
          Expanded(
            child: _LobbyStatTile(
              value: '$yourCount',
              label: 'Yours',
              icon: Icons.flag_outlined,
              color: AppColors.accentText,
            ),
          ),
        ],
      ),
    );
  }
}

class _LobbyStatTile extends StatelessWidget {
  const _LobbyStatTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        Text(label, style: HomeTextStyles.cardSub),
      ],
    );
  }
}

class _LobbyCreateBanner extends StatelessWidget {
  const _LobbyCreateBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.battleCoral,
          borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create new battle',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Set rules, invite friends, earn rewards',
                    style: HomeTextStyles.bodySmall.copyWith(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white.withValues(alpha: 0.9),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _LobbyFilterBar extends StatelessWidget {
  const _LobbyFilterBar({
    required this.subjects,
    required this.grades,
    required this.selectedSubject,
    required this.selectedGrade,
    required this.onSubjectChanged,
    required this.onGradeChanged,
  });

  final List<String> subjects;
  final List<String> grades;
  final String? selectedSubject;
  final String? selectedGrade;
  final ValueChanged<String?> onSubjectChanged;
  final ValueChanged<String?> onGradeChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CompactFilterDropdown(
            prefix: 'Subject',
            allLabel: 'All',
            value: selectedSubject,
            options: subjects,
            onChanged: onSubjectChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CompactFilterDropdown(
            prefix: 'Grade',
            allLabel: 'All',
            value: selectedGrade,
            options: grades,
            onChanged: onGradeChanged,
          ),
        ),
      ],
    );
  }
}

class _CompactFilterDropdown extends StatelessWidget {
  const _CompactFilterDropdown({
    required this.prefix,
    required this.allLabel,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String prefix;
  final String allLabel;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  static const _radius = 10.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgElevated,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radius),
        side: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: SizedBox(
        height: 36,
        child: Padding(
          padding: const EdgeInsets.only(left: 10, right: 2),
          child: Row(
            children: [
              Text(
                prefix,
                style: HomeTextStyles.badge.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 9,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: value,
                    isDense: true,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(_radius),
                    dropdownColor: AppColors.bgOverlay,
                    style: HomeTextStyles.cardTitle.copyWith(fontSize: 12),
                    icon: const Icon(
                      Icons.expand_more_rounded,
                      color: AppColors.textMuted,
                      size: 18,
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(allLabel, style: HomeTextStyles.cardSub),
                      ),
                      ...options.map(
                        (option) => DropdownMenuItem<String?>(
                          value: option,
                          child: Text(
                            option,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: onChanged,
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.accent;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 4 : 8,
        ),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.18) : AppColors.bgElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : AppColors.border,
            width: selected ? 1.2 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: HomeTextStyles.badge.copyWith(
            color: selected ? accent : AppColors.textSecondary,
            fontSize: compact ? 10 : 11,
          ),
        ),
      ),
    );
  }
}

class _LiveCountBadge extends StatelessWidget {
  const _LiveCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _LivePulseDot(size: 6),
          const SizedBox(width: 5),
          Text(
            '$count',
            style: HomeTextStyles.badge.copyWith(
              color: AppColors.danger,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _LobbyEmptyState extends StatelessWidget {
  const _LobbyEmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
            ),
            child: const Icon(
              Icons.sports_esports_rounded,
              color: AppColors.accentText,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'The arena is quiet',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start the first battle and invite classmates to join your waiting room.',
            style: HomeTextStyles.bodySmall.copyWith(fontSize: 12, height: 1.45),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: onCreate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                'Create the first battle',
                style: HomeTextStyles.badge.copyWith(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LobbyNoResultsState extends StatelessWidget {
  const _LobbyNoResultsState({
    required this.onClear,
    this.subject,
    this.grade,
  });

  final String? subject;
  final String? grade;
  final VoidCallback onClear;

  String get _message {
    if (subject != null && grade != null) {
      return 'No $subject battles for $grade';
    }
    if (subject != null) return 'No $subject battles right now';
    if (grade != null) return 'No battles for $grade right now';
    return 'No matching battles';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Text(
            _message,
            style: HomeTextStyles.cardTitle.copyWith(fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Try different filters or create your own battle.',
            style: HomeTextStyles.bodySmall.copyWith(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onClear,
            child: Text(
              'Show all battles',
              style: HomeTextStyles.seeAll,
            ),
          ),
        ],
      ),
    );
  }
}

class _LivePulseDot extends StatefulWidget {
  const _LivePulseDot({this.size = 7});

  final double size;

  @override
  State<_LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<_LivePulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(
              alpha: 0.55 + _controller.value * 0.45,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.danger.withValues(alpha: 0.35),
                blurRadius: 4 + _controller.value * 4,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UrgencyBadge extends StatelessWidget {
  const _UrgencyBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isLastSpot = label.contains('spot');
    final color = isLastSpot ? AppColors.amber : AppColors.battleCoral;

    return Text(
      label,
      style: HomeTextStyles.badge.copyWith(
        color: color,
        fontSize: 8,
      ),
    );
  }
}

class _PlayerAvatarStack extends StatelessWidget {
  const _PlayerAvatarStack({
    required this.initials,
    this.maxVisible = 4,
    this.size = 28,
    this.overlap = 10,
  });

  final List<String> initials;
  final int maxVisible;
  final double size;
  final double overlap;

  @override
  Widget build(BuildContext context) {
    final visible = initials.take(maxVisible).toList();
    final overflow = initials.length - visible.length;
    final width = size + (visible.length - 1) * (size - overlap) +
        (overflow > 0 ? size - overlap : 0);

    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * (size - overlap),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bgElevated, width: 2),
                ),
                child: Center(
                  child: Text(
                    visible[i],
                    style: HomeTextStyles.badge.copyWith(
                      color: AppColors.accentText,
                      fontSize: size < 24 ? 7 : 9,
                    ),
                  ),
                ),
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: visible.length * (size - overlap),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bgElevated, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    '+$overflow',
                    style: HomeTextStyles.badge.copyWith(
                      color: AppColors.accentText,
                      fontSize: size < 24 ? 7 : 9,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SlotsProgressBar extends StatelessWidget {
  const _SlotsProgressBar({
    required this.fillRatio,
    required this.joined,
    required this.max,
    required this.accent,
    this.height = 5,
  });

  final double fillRatio;
  final int joined;
  final int max;
  final Color accent;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(max.clamp(1, 8), (index) {
        final filled = index < joined;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < max - 1 ? 2 : 0),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: filled ? accent : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.isPrimary = false,
    this.highlight = false,
    this.compact = false,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool highlight;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bg = !enabled
        ? AppColors.bgSurface
        : isPrimary
            ? AppColors.accent
            : highlight
                ? AppColors.amber
                : AppColors.battleCoral;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 7 : 9,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: enabled
              ? null
              : Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Text(
          label,
          style: HomeTextStyles.badge.copyWith(
            color: enabled ? Colors.white : AppColors.textMuted,
            fontSize: compact ? 10 : 11,
          ),
        ),
      ),
    );
  }
}

class _BattleHeader extends StatelessWidget {
  const _BattleHeader({
    this.showBack = false,
    this.onBack,
    this.subtitle,
  });

  final bool showBack;
  final VoidCallback? onBack;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 40,
          child: showBack
              ? IconButton(
                  onPressed: onBack,
                  icon: const Icon(
                    Icons.arrow_back,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                )
              : null,
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                'Battle',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: HomeTextStyles.bodySmall.copyWith(fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.amber,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.emoji_events_outlined,
            color: Colors.white,
            size: 20,
          ),
        ),
      ],
    );
  }
}

class _VsCard extends StatelessWidget {
  const _VsCard({
    required this.opponentName,
    required this.opponentInitials,
    required this.opponentGrade,
  });

  final String opponentName;
  final String opponentInitials;
  final String opponentGrade;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: _PlayerAvatar(
                  initials: studentInitials,
                  name: 'Selam',
                  grade: enrolledGrade,
                ),
              ),
              Text(
                'VS',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.amber,
                  letterSpacing: 0.5,
                ),
              ),
              Expanded(
                child: _PlayerAvatar(
                  initials: opponentInitials,
                  name: opponentName,
                  grade: opponentGrade.isEmpty ? '—' : opponentGrade,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '0 Your pts',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.teal,
                ),
              ),
              const Spacer(),
              Text(
                '0 $opponentName\'s pts',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.teal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({
    required this.initials,
    required this.name,
    required this.grade,
    this.alignEnd = false,
  });

  final String initials;
  final String name;
  final String grade;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Center(
            child: Text(
              initials,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.accentText,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: HomeTextStyles.cardTitle.copyWith(fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          grade,
          style: HomeTextStyles.bodySmall.copyWith(fontSize: 10),
        ),
      ],
    );
  }
}

class _TimerBar extends StatelessWidget {
  const _TimerBar({
    required this.progress,
    required this.secondsLeft,
  });

  final double progress;
  final int secondsLeft;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 4,
            child: Stack(
              children: [
                Container(color: AppColors.border),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(color: AppColors.amber),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${secondsLeft}s left',
          style: HomeTextStyles.bodySmall.copyWith(fontSize: 11),
        ),
      ],
    );
  }
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.label,
    required this.text,
    required this.state,
    required this.onTap,
  });

  final String label;
  final String text;
  final _AnswerState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = switch (state) {
      _AnswerState.correct => AppColors.teal,
      _AnswerState.wrong => AppColors.danger,
      _AnswerState.idle => AppColors.border,
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: borderColor,
            width: state == _AnswerState.idle ? 0.5 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Center(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: HomeTextStyles.cardTitle.copyWith(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExplanationBanner extends StatelessWidget {
  const _ExplanationBanner({
    required this.isCorrect,
    required this.explanation,
  });

  final bool isCorrect;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    if (!isCorrect) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Not quite — keep going',
              style: HomeTextStyles.badge.copyWith(
                color: AppColors.danger,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              explanation,
              style:
                  HomeTextStyles.bodySmall.copyWith(fontSize: 13, height: 1.4),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.tealSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Correct! +10 XP',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.teal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            explanation,
            style: HomeTextStyles.bodySmall.copyWith(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
