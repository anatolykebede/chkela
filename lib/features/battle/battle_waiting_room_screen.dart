import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/home_text_styles.dart';
import '../../data/battle_setup_data.dart';

class BattleWaitingRoomScreen extends ConsumerStatefulWidget {
  const BattleWaitingRoomScreen({super.key, required this.setup});

  final BattleSetup setup;

  @override
  ConsumerState<BattleWaitingRoomScreen> createState() =>
      _BattleWaitingRoomScreenState();
}

class _BattleWaitingRoomScreenState
    extends ConsumerState<BattleWaitingRoomScreen> {
  late List<BattleParticipant> _participants;
  final List<_ChatMessage> _messages = [];
  final TextEditingController _chatController = TextEditingController();
  bool _isReady = true;
  int? _countdown;
  Timer? _simulationTimer;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _participants = initialParticipantsForSetup(widget.setup);
    _messages.add(
      _ChatMessage(
        sender: 'System',
        text: 'Waiting room opened. Share code ${widget.setup.inviteCode}',
        isSystem: true,
      ),
    );
    _startSimulation();
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _countdownTimer?.cancel();
    _chatController.dispose();
    super.dispose();
  }

  void _startSimulation() {
    _simulationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || _countdown != null) return;

      var changed = false;
      final updated = [..._participants];

      for (var i = 0; i < updated.length; i++) {
        final p = updated[i];
        if (p.isCurrentUser || p.status == ParticipantStatus.ready) continue;

        if (p.id == 'matchmaking' && widget.setup.randomMatchmaking) {
          updated[i] = BattleParticipant(
            id: 'random-1',
            name: 'Kidus R.',
            initials: 'KR',
            grade: 'Grade 10',
            status: ParticipantStatus.joined,
          );
          _addMessage('Kidus R. joined via matchmaking');
          changed = true;
          continue;
        }

        if (p.status == ParticipantStatus.waiting) {
          updated[i] = p.copyWith(status: ParticipantStatus.joined);
          _addMessage('${p.name} joined the battle');
          changed = true;
        } else if (p.status == ParticipantStatus.joined) {
          updated[i] = p.copyWith(status: ParticipantStatus.ready);
          _addMessage('${p.name} is ready');
          changed = true;
        }
      }

      if (changed) {
        setState(() => _participants = updated);
        _maybeStartCountdown();
      }
    });
  }

  void _addMessage(String text) {
    _messages.add(_ChatMessage(sender: 'System', text: text, isSystem: true));
  }

  int get _readyCount =>
      _participants.where((p) => p.status == ParticipantStatus.ready).length;

  int get _minPlayers => widget.setup.format == BattleFormat.oneVsOne ? 2 : 4;

  bool get _canStartCountdown =>
      _countdown == null && _readyCount >= _minPlayers && _isReady;

  void _maybeStartCountdown() {
    if (_canStartCountdown) _beginCountdown();
  }

  void _toggleReady() {
    HapticFeedback.lightImpact();
    setState(() => _isReady = !_isReady);
    if (_isReady) {
      _addMessage('You are ready');
      _maybeStartCountdown();
    } else {
      _countdownTimer?.cancel();
      setState(() => _countdown = null);
      _addMessage('You are no longer ready');
    }
  }

  void _beginCountdown() {
    _simulationTimer?.cancel();
    setState(() => _countdown = 5);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdown == null || _countdown! <= 1) {
        timer.cancel();
        _launchBattle();
      } else {
        setState(() => _countdown = _countdown! - 1);
      }
    });
  }

  void _launchBattle() {
    ref.read(pendingBattleLaunchProvider.notifier).state = widget.setup;
    context.go('/battle');
  }

  void _sendChat() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(
        _ChatMessage(sender: 'You', text: text, isCurrentUser: true),
      );
      _chatController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInviteCard(),
                    const SizedBox(height: 16),
                    _buildParticipants(),
                    const SizedBox(height: 16),
                    _buildChat(),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.textSecondary,
              size: 22,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Waiting Room',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${widget.setup.subjectName} · ${battleFormatLabel(widget.setup.format)}',
                  style: HomeTextStyles.bodySmall.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          if (_countdown != null)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.amberSoft,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.amber, width: 2),
              ),
              child: Center(
                child: Text(
                  '$_countdown',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.amber,
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildInviteCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invite code', style: HomeTextStyles.badge.copyWith(fontSize: 10)),
                const SizedBox(height: 4),
                Text(
                  widget.setup.inviteCode,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentText,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: widget.setup.inviteCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code copied')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Copy',
                style: HomeTextStyles.badge.copyWith(
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipants() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('PARTICIPANTS', style: HomeTextStyles.sectionLabel),
            const Spacer(),
            Text(
              '$_readyCount/${_participants.length} ready',
              style: HomeTextStyles.badge.copyWith(
                color: AppColors.teal,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._participants.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ParticipantRow(participant: p),
          ),
        ),
      ],
    );
  }

  Widget _buildChat() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CHAT', style: HomeTextStyles.sectionLabel),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(minHeight: 120, maxHeight: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  msg.isSystem ? msg.text : '${msg.sender}: ${msg.text}',
                  style: HomeTextStyles.bodySmall.copyWith(
                    fontSize: 12,
                    color: msg.isCurrentUser
                        ? AppColors.accentText
                        : msg.isSystem
                            ? AppColors.textMuted
                            : AppColors.textSecondary,
                    fontStyle:
                        msg.isSystem ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _chatController,
                style: HomeTextStyles.cardTitle.copyWith(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Say something…',
                  hintStyle: HomeTextStyles.bodySmall,
                  filled: true,
                  fillColor: AppColors.bgElevated,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                onSubmitted: (_) => _sendChat(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _sendChat,
              icon: const Icon(Icons.send_rounded, color: AppColors.accent),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    if (_countdown != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        color: AppColors.amberSoft,
        child: Column(
          children: [
            Text(
              'Battle starts in',
              style: HomeTextStyles.bodySmall.copyWith(fontSize: 12),
            ),
            Text(
              '$_countdown',
              style: GoogleFonts.inter(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: AppColors.amber,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: GestureDetector(
        onTap: _toggleReady,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: _isReady ? AppColors.teal : AppColors.accent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              _isReady ? 'Ready ✓' : 'Ready up',
              style: GoogleFonts.inter(
                fontSize: 15,
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

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({required this.participant});

  final BattleParticipant participant;

  @override
  Widget build(BuildContext context) {
    final status = switch (participant.status) {
      ParticipantStatus.waiting => ('Waiting', AppColors.textMuted),
      ParticipantStatus.joined => ('Joined', AppColors.info),
      ParticipantStatus.ready => ('Ready', AppColors.teal),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Text(
                participant.initials,
                style: HomeTextStyles.badge.copyWith(
                  color: AppColors.accentText,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      participant.name,
                      style: HomeTextStyles.cardTitle.copyWith(fontSize: 13),
                    ),
                    if (participant.isHost) ...[
                      const SizedBox(width: 6),
                      Text(
                        'HOST',
                        style: HomeTextStyles.badge.copyWith(
                          color: AppColors.amber,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(participant.grade, style: HomeTextStyles.cardSub),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status.$2.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status.$1,
              style: HomeTextStyles.badge.copyWith(
                color: status.$2,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  _ChatMessage({
    required this.sender,
    required this.text,
    this.isSystem = false,
    this.isCurrentUser = false,
  });

  final String sender;
  final String text;
  final bool isSystem;
  final bool isCurrentUser;
}
