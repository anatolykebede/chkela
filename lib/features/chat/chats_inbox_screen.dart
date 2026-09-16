import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/home_layout.dart';
import '../../core/theme/home_text_styles.dart';
import '../../data/chat_api.dart';
import '../../data/map_profile_store.dart';
import '../auth/auth_provider.dart';

/// Inbox of real 1:1 conversations (friends + map demo peers).
class ChatsInboxScreen extends ConsumerStatefulWidget {
  const ChatsInboxScreen({super.key});

  @override
  ConsumerState<ChatsInboxScreen> createState() => _ChatsInboxScreenState();
}

class _ChatsInboxScreenState extends ConsumerState<ChatsInboxScreen> {
  List<ChatConversationSummary> _items = const [];
  bool _loading = true;
  String? _error;
  Timer? _poll;
  int _refreshGen = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final phone = ref.read(authProvider).phoneE164;
    final gen = ++_refreshGen;
    if (phone == null || phone.isEmpty) {
      if (mounted && gen == _refreshGen) {
        setState(() {
          _loading = false;
          _items = const [];
          _error = null;
        });
      }
      return;
    }
    try {
      final list = await ChatApi.instance.inbox(phone);
      if (!mounted || gen != _refreshGen) return;
      setState(() {
        _items = list;
        _loading = false;
        _error = null;
      });
    } on ChatException catch (e) {
      if (!mounted || gen != _refreshGen) return;
      setState(() {
        _loading = false;
        _error = e.userMessage;
      });
    } catch (_) {
      if (!mounted || gen != _refreshGen) return;
      setState(() {
        _loading = false;
        _error = const ChatException('network').userMessage;
      });
    }
  }

  void _openChat(ChatConversationSummary row) {
    // Prefer phone / stable targetId so shared mapId never opens "me".
    final id = row.peer.targetId.isNotEmpty
        ? row.peer.targetId
        : row.peer.id;
    context.push('/chat/${Uri.encodeComponent(id)}');
  }

  void _openFriendPicker() {
    final friends = MapProfileStore.instance.friendsFor(MapProfileStore.instance.me);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        if (friends.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Add friends on the map first, then message them here.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Message a friend',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              for (final s in friends)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.accentSoft,
                    child: Text(
                      s.initials,
                      style: GoogleFonts.inter(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(
                    s.name,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    s.grade,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/chat/${Uri.encodeComponent(s.id)}');
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final phone = ref.watch(authProvider).phoneE164;
    final signedIn = phone != null && phone.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      floatingActionButton: signedIn
          ? FloatingActionButton(
              onPressed: _openFriendPicker,
              backgroundColor: AppColors.accent,
              child: const Icon(Icons.edit_outlined, color: Colors.white),
            )
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Messages',
                      style: HomeTextStyles.cardTitle.copyWith(fontSize: 18),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => _loading = _items.isEmpty);
                      _refresh();
                    },
                    icon: const Icon(
                      Icons.refresh,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null && signedIn)
              _ChatErrorBanner(
                message: _error!,
                onRetry: () {
                  setState(() => _loading = _items.isEmpty);
                  _refresh();
                },
              ),
            Expanded(
              child: !signedIn
                  ? Center(
                      child: Text(
                        'Sign in to see your chats.',
                        style: HomeTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    )
                  : _loading
                      ? const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _items.isEmpty && _error == null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text(
                                  'No conversations yet.\nOpen a friend\'s profile and tap Message.',
                                  textAlign: TextAlign.center,
                                  style: HomeTextStyles.bodySmall.copyWith(
                                    color: AppColors.textMuted,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            )
                          : _items.isEmpty && _error != null
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Text(
                                      'Could not load messages.',
                                      textAlign: TextAlign.center,
                                      style: HomeTextStyles.bodySmall.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: _refresh,
                                  child: ListView.separated(
                                    padding:
                                        const EdgeInsets.fromLTRB(16, 4, 16, 88),
                                    itemCount: _items.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final row = _items[index];
                                      return _InboxTile(
                                        row: row,
                                        onTap: () => _openChat(row),
                                      );
                                    },
                                  ),
                                ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatErrorBanner extends StatelessWidget {
  const _ChatErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.danger.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 18, color: AppColors.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: HomeTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxTile extends StatelessWidget {
  const _InboxTile({required this.row, required this.onTap});

  final ChatConversationSummary row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = row.lastMessage?.text ?? 'Say hi';
    final time = formatChatTime(row.lastMessage?.createdAt ?? row.updatedAt);
    final unread = row.unread > 0;

    return Material(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HomeLayout.cardRadius),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.35),
                  ),
                ),
                child: Center(
                  child: Text(
                    row.peer.initials,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.peer.name,
                            style: HomeTextStyles.cardTitle.copyWith(
                              fontSize: 14,
                              fontWeight:
                                  unread ? FontWeight.w700 : FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          time,
                          style: HomeTextStyles.bodySmall.copyWith(
                            fontSize: 11,
                            color: unread
                                ? AppColors.accent
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HomeTextStyles.bodySmall.copyWith(
                              fontSize: 13,
                              color: unread
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontWeight:
                                  unread ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              row.unread > 9 ? '9+' : '${row.unread}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
