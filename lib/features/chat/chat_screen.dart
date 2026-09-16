import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/home_layout.dart';
import '../../core/theme/home_text_styles.dart';
import '../../data/chat_api.dart';
import '../../data/map_students.dart';
import '../auth/auth_provider.dart';
import '../map/student_profile_helpers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.student,
  });

  final MapStudent student;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessageDto> _messages = [];
  Timer? _poll;
  String? _conversationId;
  ChatPeer? _peer;
  bool _loading = true;
  bool _sending = false;
  bool _polling = false;
  String? _error;
  String? _lastCreatedAt;

  MapStudent get student => widget.student;
  String get _peerId => student.id;

  bool get _isSoftConnectivityError {
    final e = _error;
    if (e == null) return false;
    return e.startsWith('Cannot reach') || e.startsWith('Chat server timed');
  }

  bool get _composerEnabled {
    final phone = _phone;
    if (phone == null || phone.isEmpty || _loading) return false;
    // Soft offline: still allow send attempts. Hard errors (friends_only, etc.): lock.
    if (_error != null && !_isSoftConnectivityError) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String? get _phone => ref.read(authProvider).phoneE164;

  Future<void> _bootstrap() async {
    final phone = _phone;
    if (phone == null || phone.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Sign in to message friends.';
      });
      return;
    }

    try {
      final snap = await ChatApi.instance.thread(phone: phone, peerId: _peerId);
      if (!mounted) return;

      setState(() {
        _loading = false;
        _peer = snap.peer.targetId.isNotEmpty ? snap.peer : null;
        _conversationId = snap.conversationId;
        _messages
          ..clear()
          ..addAll(snap.messages);
        _lastCreatedAt =
            snap.messages.isEmpty ? null : snap.messages.last.createdAt;
        _error = null;
      });

      await ChatApi.instance.markRead(
        phone: phone,
        peerId: _peerId,
        conversationId: _conversationId,
      ).then((ok) async {
        if (ok || !mounted) return;
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        await ChatApi.instance.markRead(
          phone: phone,
          peerId: _peerId,
          conversationId: _conversationId,
        );
      });
      _scrollToBottom(jump: true);
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 2), (_) => _pollNew());
    } on ChatException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.userMessage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = const ChatException('network').userMessage;
      });
    }
  }

  Future<void> _pollNew() async {
    final phone = _phone;
    if (phone == null || phone.isEmpty || _sending || _polling) return;
    _polling = true;
    try {
      final snap = await ChatApi.instance.thread(
        phone: phone,
        peerId: _peerId,
        since: _lastCreatedAt,
      );
      if (!mounted || _sending) return;

      if (_error != null && _isSoftConnectivityError) {
        setState(() => _error = null);
      }

      if (snap.messages.isEmpty) return;

      final existing = _messages.map((m) => m.id).toSet();
      final incoming =
          snap.messages.where((m) => !existing.contains(m.id)).toList();
      if (incoming.isEmpty) {
        final newest = snap.messages.last.createdAt;
        if (newest.isNotEmpty) _lastCreatedAt = newest;
        return;
      }

      setState(() {
        _messages.addAll(incoming);
        _lastCreatedAt = _messages.last.createdAt;
        if (snap.peer.targetId.isNotEmpty) _peer = snap.peer;
        if (snap.conversationId.isNotEmpty) {
          _conversationId = snap.conversationId;
        }
      });
      await ChatApi.instance.markRead(phone: phone, peerId: _peerId);
      _scrollToBottom();
    } on ChatException catch (e) {
      if (!mounted) return;
      if (e.code == 'network' || e.code == 'timeout') {
        setState(() => _error = e.userMessage);
      } else if (e.code == 'friends_only' ||
          e.code == 'peer_not_found' ||
          e.code == 'cannot_message_self') {
        _poll?.cancel();
        setState(() => _error = e.userMessage);
      }
    } catch (_) {
      // Ignore transient poll failures.
    } finally {
      _polling = false;
    }
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    final phone = _phone;
    if (text.isEmpty ||
        phone == null ||
        phone.isEmpty ||
        _sending ||
        !_composerEnabled) {
      return;
    }

    setState(() => _sending = true);
    _controller.clear();

    final optimistic = ChatMessageDto(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      from: phone,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      isMine: true,
    );
    setState(() {
      _messages.add(optimistic);
      _error = null;
    });
    _scrollToBottom();

    try {
      final saved = await ChatApi.instance.send(
        phone: phone,
        peerId: _peerId,
        text: text,
      );
      if (!mounted) return;
      setState(() {
        _sending = false;
        // Drop optimistic + any poll-duplicated server copy, then keep one.
        _messages.removeWhere(
          (m) => m.id == optimistic.id || m.id == saved.id,
        );
        _messages.add(saved);
        _lastCreatedAt = saved.createdAt;
      });
      _scrollToBottom();
    } on ChatException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _messages.removeWhere((m) => m.id == optimistic.id);
        _controller.text = text;
        _error = e.userMessage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _messages.removeWhere((m) => m.id == optimistic.id);
        _controller.text = text;
        _error = const ChatException('network').userMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = profileStyleFor(student);
    final title = (_peer?.name.isNotEmpty == true) ? _peer!.name : student.name;
    final initials =
        (_peer?.initials.isNotEmpty == true) ? _peer!.initials : student.initials;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(
              name: title,
              initials: initials,
              studentId: student.id,
              style: style,
              subtitle: (_peer?.grade.isNotEmpty == true)
                  ? _peer!.grade
                  : (student.grade.isNotEmpty ? student.grade : 'Chkela chat'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Material(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 18,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: HomeTextStyles.bodySmall.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _loading = _messages.isEmpty;
                              _error = null;
                            });
                            _bootstrap();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return _ChatBubble(
                          message: _messages[index],
                          accent: style.accent,
                          accentSoft: style.accentSoft,
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: const BoxDecoration(
                color: AppColors.bgSurface,
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: _composerEnabled,
                      style: HomeTextStyles.bodySmall.copyWith(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Message ${title.split(' ').first}…',
                        hintStyle: HomeTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                        filled: true,
                        fillColor: AppColors.bgElevated,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(HomeLayout.cardRadius),
                          borderSide: const BorderSide(
                            color: AppColors.border,
                            width: 0.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(HomeLayout.cardRadius),
                          borderSide: const BorderSide(
                            color: AppColors.border,
                            width: 0.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(HomeLayout.cardRadius),
                          borderSide: BorderSide(
                            color: style.accent.withValues(alpha: 0.5),
                            width: 0.5,
                          ),
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sending ? null : _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: style.accent,
                        borderRadius:
                            BorderRadius.circular(HomeLayout.cardRadius),
                      ),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
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

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.name,
    required this.initials,
    required this.studentId,
    required this.style,
    required this.subtitle,
  });

  final String name;
  final String initials;
  final String studentId;
  final StudentProfileStyle style;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.textSecondary,
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: style.accentSoft,
              shape: BoxShape.circle,
              border: Border.all(
                color: style.accent.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                initials,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: style.accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: HomeTextStyles.cardTitle.copyWith(fontSize: 15),
                ),
                Text(
                  subtitle,
                  style: HomeTextStyles.bodySmall.copyWith(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              context.push('/student/${Uri.encodeComponent(studentId)}');
            },
            icon: const Icon(
              Icons.person_outline,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.accent,
    required this.accentSoft,
  });

  final ChatMessageDto message;
  final Color accent;
  final Color accentSoft;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isMine
              ? accentSoft.withValues(alpha: 0.55)
              : AppColors.bgElevated,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(HomeLayout.cardRadius),
            topRight: const Radius.circular(HomeLayout.cardRadius),
            bottomLeft: Radius.circular(isMine ? HomeLayout.cardRadius : 4),
            bottomRight: Radius.circular(isMine ? 4 : HomeLayout.cardRadius),
          ),
          border: Border.all(
            color: isMine
                ? accent.withValues(alpha: 0.35)
                : AppColors.border,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: HomeTextStyles.bodySmall.copyWith(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatChatTime(message.createdAt),
              style: HomeTextStyles.bodySmall.copyWith(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
