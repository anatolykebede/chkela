import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/home_text_styles.dart';
import '../../data/battle_setup_data.dart';
import '../../data/home_mock_data.dart';
import '../../data/study_subjects.dart';

enum _CreateStep { type, rules, participants, rewards, review }

class CreateBattleScreen extends StatefulWidget {
  const CreateBattleScreen({super.key});

  @override
  State<CreateBattleScreen> createState() => _CreateBattleScreenState();
}

class _CreateBattleScreenState extends State<CreateBattleScreen> {
  _CreateStep _step = _CreateStep.type;
  bool _showSuccess = false;

  BattleVisibility _visibility = BattleVisibility.public;
  String? _subjectName;
  int _roundCount = 10;
  final Set<String> _invitedIds = {};
  bool _randomMatchmaking = true;
  bool _rewardPoints = true;
  int _pointsAmount = 50;

  late BattleSetup _createdSetup;

  List<StudySubject> get _subjects =>
      studySubjects.where((s) => !s.isLocked).toList();

  int get _stepIndex => _CreateStep.values.indexOf(_step);
  int get _totalSteps => _CreateStep.values.length;

  bool get _canContinue {
    switch (_step) {
      case _CreateStep.type:
        return true;
      case _CreateStep.rules:
        return _subjectName != null;
      case _CreateStep.participants:
        return true;
      case _CreateStep.rewards:
      case _CreateStep.review:
        return true;
    }
  }

  void _goToStep(_CreateStep step) => setState(() => _step = step);

  void _next() {
    if (!_canContinue) return;
    final index = _stepIndex;
    if (index < _totalSteps - 1) {
      HapticFeedback.lightImpact();
      setState(() => _step = _CreateStep.values[index + 1]);
    }
  }

  void _back() {
    if (_showSuccess) return;
    if (_stepIndex > 0) {
      setState(() => _step = _CreateStep.values[_stepIndex - 1]);
    } else {
      context.pop();
    }
  }

  BattleSetup _buildSetup() {
    return BattleSetup(
      id: 'battle-${DateTime.now().millisecondsSinceEpoch}',
      inviteCode: generateInviteCode(),
      format: BattleFormat.oneVsOne,
      visibility: _visibility,
      subjectName: _subjectName ?? _subjects.first.name,
      gameMode: BattleGameMode.classicQuiz,
      timeLimitSeconds: 15,
      roundCount: _roundCount,
      difficulty: BattleDifficulty.medium,
      invitedFriendIds: Set<String>.from(_invitedIds),
      randomMatchmaking: _randomMatchmaking,
      rewardPoints: _rewardPoints,
      pointsAmount: _pointsAmount,
      rewardBadges: false,
      rewardPrizePool: false,
      prizePoolLabel: '',
      hostName: studentName,
      hostInitials: studentInitials,
      hostGrade: enrolledGrade,
    );
  }

  void _createBattle() {
    HapticFeedback.mediumImpact();
    setState(() {
      _createdSetup = _buildSetup();
      _showSuccess = true;
    });
  }

  void _enterWaitingRoom() {
    context.push('/battle/waiting', extra: _createdSetup);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            if (!_showSuccess) ...[
              _buildProgress(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _buildStepContent(),
                ),
              ),
              _buildBottomBar(),
            ] else
              Expanded(child: _buildSuccess()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: _back,
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.textSecondary,
              size: 22,
            ),
          ),
          Expanded(
            child: Text(
              _showSuccess ? 'Battle Created' : 'Create Battle',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final active = index <= _stepIndex;
          return Expanded(
            child: Container(
              height: 3,
              margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 4 : 0),
              decoration: BoxDecoration(
                color: active ? AppColors.accent : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    return switch (_step) {
      _CreateStep.type => _buildTypeStep(),
      _CreateStep.rules => _buildRulesStep(),
      _CreateStep.participants => _buildParticipantsStep(),
      _CreateStep.rewards => _buildRewardsStep(),
      _CreateStep.review => _buildReviewStep(),
    };
  }

  Widget _buildTypeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Set up 1v1 battle', 'Choose who can join your duel'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accent, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: AppColors.accentText,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1v1', style: HomeTextStyles.cardTitle.copyWith(fontSize: 14)),
                    Text(
                      'Head-to-head duel with one opponent',
                      style: HomeTextStyles.cardSub,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.check_circle, color: AppColors.accent, size: 20),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('VISIBILITY', style: HomeTextStyles.sectionLabel),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _OptionCard(
                title: 'Public',
                subtitle: 'Anyone can find and join',
                icon: Icons.public_outlined,
                selected: _visibility == BattleVisibility.public,
                onTap: () =>
                    setState(() => _visibility = BattleVisibility.public),
                compact: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _OptionCard(
                title: 'Private',
                subtitle: 'Invite-only with a code',
                icon: Icons.lock_outline,
                selected: _visibility == BattleVisibility.private,
                onTap: () =>
                    setState(() => _visibility = BattleVisibility.private),
                compact: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRulesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Set rules', 'Configure how the battle plays'),
        const SizedBox(height: 16),
        Text('SUBJECT', style: HomeTextStyles.sectionLabel),
        const SizedBox(height: 8),
        ..._subjects.map((subject) {
          final selected = _subjectName == subject.name;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SubjectChip(
              subject: subject,
              selected: selected,
              onTap: () => setState(() => _subjectName = subject.name),
            ),
          );
        }),
        const SizedBox(height: 12),
        _PickerRow(
          label: 'Rounds',
          value: '$_roundCount questions',
          options: battleRoundCounts.map((n) => '$n').toList(),
          selectedIndex: battleRoundCounts.indexOf(_roundCount),
          onSelected: (i) => setState(() => _roundCount = battleRoundCounts[i]),
        ),
      ],
    );
  }

  Widget _buildParticipantsStep() {
    final previewCode = generateInviteCode();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Select participants', 'Invite friends or match randomly'),
        const SizedBox(height: 16),
        _ToggleRow(
          title: 'Random matchmaking',
          subtitle: _visibility == BattleVisibility.public
              ? 'Fill empty slots with online students'
              : 'Only works for public battles',
          value: _randomMatchmaking && _visibility == BattleVisibility.public,
          enabled: _visibility == BattleVisibility.public,
          onChanged: (v) => setState(() => _randomMatchmaking = v),
        ),
        const SizedBox(height: 16),
        Text('INVITE FRIENDS', style: HomeTextStyles.sectionLabel),
        const SizedBox(height: 8),
        ...battleFriends.map((friend) {
          final selected = _invitedIds.contains(friend.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FriendTile(
              friend: friend,
              selected: selected,
              onTap: () {
                setState(() {
                  if (selected) {
                    _invitedIds.remove(friend.id);
                  } else {
                    _invitedIds.add(friend.id);
                  }
                });
              },
            ),
          );
        }),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.link, size: 16, color: AppColors.accentText),
                  const SizedBox(width: 6),
                  Text(
                    'Invite link & code',
                    style: HomeTextStyles.cardTitle.copyWith(fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'https://chkela.app/battle/$previewCode',
                style: HomeTextStyles.bodySmall.copyWith(
                  fontSize: 12,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Code: $previewCode',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Generated after you create the battle',
                style: HomeTextStyles.badge.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRewardsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Configure rewards', 'Optional — motivate your challengers'),
        const SizedBox(height: 16),
        _ToggleRow(
          title: 'Points',
          subtitle: 'Award XP to the winner',
          value: _rewardPoints,
          onChanged: (v) => setState(() => _rewardPoints = v),
        ),
        if (_rewardPoints) ...[
          const SizedBox(height: 10),
          _PickerRow(
            label: 'Points amount',
            value: '$_pointsAmount XP',
            options: const ['25', '50', '100', '200'],
            selectedIndex: [25, 50, 100, 200].indexOf(_pointsAmount),
            onSelected: (i) =>
                setState(() => _pointsAmount = [25, 50, 100, 200][i]),
          ),
        ],
      ],
    );
  }

  Widget _buildReviewStep() {
    final subject = studySubjectByName(_subjectName ?? '');
    final rewards = <String>[
      if (_rewardPoints) '$_pointsAmount XP',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Review', 'Tap any row to make quick edits'),
        const SizedBox(height: 16),
        _ReviewSection(
          title: 'Battle type',
          onEdit: () => _goToStep(_CreateStep.type),
          rows: [
            ('Format', '1v1'),
            ('Visibility', battleVisibilityLabel(_visibility)),
          ],
        ),
        const SizedBox(height: 10),
        _ReviewSection(
          title: 'Rules',
          onEdit: () => _goToStep(_CreateStep.rules),
          rows: [
            ('Subject', _subjectName ?? 'Not selected'),
            ('Rounds', '$_roundCount'),
          ],
          leading: subject != null
              ? Icon(subject.icon, color: subject.iconColor, size: 18)
              : null,
        ),
        const SizedBox(height: 10),
        _ReviewSection(
          title: 'Participants',
          onEdit: () => _goToStep(_CreateStep.participants),
          rows: [
            (
              'Invited',
              _invitedIds.isEmpty
                  ? 'None'
                  : '${_invitedIds.length} friend${_invitedIds.length == 1 ? '' : 's'}',
            ),
            (
              'Matchmaking',
              _randomMatchmaking && _visibility == BattleVisibility.public
                  ? 'On'
                  : 'Off',
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ReviewSection(
          title: 'Rewards',
          onEdit: () => _goToStep(_CreateStep.rewards),
          rows: [
            ('Prizes', rewards.isEmpty ? 'None' : rewards.join(' · ')),
          ],
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.tealSoft,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.teal, width: 2),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.teal,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Battle created!',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share the code so friends can join your waiting room',
            style: HomeTextStyles.bodySmall.copyWith(fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Text('INVITE CODE', style: HomeTextStyles.sectionLabel),
                const SizedBox(height: 8),
                Text(
                  _createdSetup.inviteCode,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentText,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _createdSetup.inviteLink,
                  style: HomeTextStyles.bodySmall.copyWith(
                    fontSize: 12,
                    color: AppColors.info,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ShareButton(
                  icon: Icons.copy_outlined,
                  label: 'Copy code',
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: _createdSetup.inviteCode),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite code copied')),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ShareButton(
                  icon: Icons.share_outlined,
                  label: 'Share link',
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: _createdSetup.inviteLink),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite link copied')),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _enterWaitingRoom,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Enter waiting room',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => context.go('/battle'),
            child: Text(
              'Back to battle lobby',
              style: HomeTextStyles.cardSub.copyWith(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final isReview = _step == _CreateStep.review;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: GestureDetector(
        onTap: _canContinue
            ? (isReview ? _createBattle : _next)
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: _canContinue ? AppColors.accent : AppColors.bgElevated,
            borderRadius: BorderRadius.circular(12),
            border: _canContinue
                ? null
                : Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Center(
            child: Text(
              isReview ? 'Create battle' : 'Continue',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _canContinue ? Colors.white : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: HomeTextStyles.bodySmall.copyWith(fontSize: 13)),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(compact ? 12 : 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : AppColors.bgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: compact ? 36 : 40,
              height: compact ? 36 : 40,
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.accentText, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: HomeTextStyles.cardTitle.copyWith(fontSize: 14),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: HomeTextStyles.cardSub),
                  ],
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.accent, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({
    required this.subject,
    required this.selected,
    required this.onTap,
  });

  final StudySubject subject;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? subject.iconBg.withValues(alpha: 0.5) : AppColors.bgElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? subject.iconColor : AppColors.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(subject.icon, color: subject.iconColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                subject.name,
                style: HomeTextStyles.cardTitle.copyWith(fontSize: 14),
              ),
            ),
            if (selected)
              Icon(Icons.check, color: subject.iconColor, size: 18),
          ],
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.value,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
  });

  final String label;
  final String value;
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: HomeTextStyles.badge.copyWith(fontSize: 10)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(options.length, (index) {
                final selected = index == selectedIndex;
                return Padding(
                  padding: EdgeInsets.only(right: index < options.length - 1 ? 6 : 0),
                  child: GestureDetector(
                    onTap: () => onSelected(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.accent : AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected ? AppColors.accent : AppColors.border,
                        ),
                      ),
                      child: Text(
                        options[index],
                        style: HomeTextStyles.badge.copyWith(
                          color: selected ? Colors.white : AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: HomeTextStyles.cardTitle.copyWith(fontSize: 14)),
                Text(subtitle, style: HomeTextStyles.cardSub),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeTrackColor: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    required this.selected,
    required this.onTap,
  });

  final BattleFriend friend;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : AppColors.bgElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Text(
                      friend.initials,
                      style: HomeTextStyles.badge.copyWith(
                        color: AppColors.accentText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                if (friend.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.onlineGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.bgElevated, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(friend.name, style: HomeTextStyles.cardTitle.copyWith(fontSize: 14)),
                  Text(
                    '${friend.grade} · ${friend.points} pts',
                    style: HomeTextStyles.cardSub,
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.add_circle_outline,
              color: selected ? AppColors.accent : AppColors.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.title,
    required this.onEdit,
    required this.rows,
    this.leading,
  });

  final String title;
  final VoidCallback onEdit;
  final List<(String, String)> rows;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 8)],
              Text(title, style: HomeTextStyles.cardTitle.copyWith(fontSize: 14)),
              const Spacer(),
              GestureDetector(
                onTap: onEdit,
                child: Text(
                  'Edit',
                  style: HomeTextStyles.badge.copyWith(
                    color: AppColors.accentText,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(row.$1, style: HomeTextStyles.cardSub),
                  ),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: HomeTextStyles.cardTitle.copyWith(fontSize: 13),
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
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: HomeTextStyles.cardTitle.copyWith(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
