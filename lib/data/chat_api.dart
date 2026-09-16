import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_auth_headers.dart';
import 'content/content_api.dart' show contentApiBaseUrl;

class ChatPeer {
  const ChatPeer({
    required this.id,
    required this.targetId,
    required this.name,
    required this.initials,
    this.grade = '',
    this.school = '',
    this.kind = 'phone',
  });

  final String id;
  final String targetId;
  final String name;
  final String initials;
  final String grade;
  final String school;
  final String kind;

  factory ChatPeer.fromJson(Map<String, dynamic> json) {
    return ChatPeer(
      id: '${json['id'] ?? json['targetId'] ?? ''}',
      targetId: '${json['targetId'] ?? json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      initials: '${json['initials'] ?? '?'}',
      grade: '${json['grade'] ?? ''}',
      school: '${json['school'] ?? ''}',
      kind: '${json['kind'] ?? 'phone'}',
    );
  }
}

class ChatMessageDto {
  const ChatMessageDto({
    required this.id,
    required this.text,
    required this.from,
    required this.createdAt,
    required this.isMine,
  });

  final String id;
  final String text;
  final String from;
  final String createdAt;
  final bool isMine;

  factory ChatMessageDto.fromJson(Map<String, dynamic> json) {
    return ChatMessageDto(
      id: '${json['id'] ?? ''}',
      text: '${json['text'] ?? ''}',
      from: '${json['from'] ?? ''}',
      createdAt: '${json['createdAt'] ?? ''}',
      isMine: json['isMine'] == true,
    );
  }
}

class ChatConversationSummary {
  const ChatConversationSummary({
    required this.conversationId,
    required this.peer,
    required this.unread,
    required this.updatedAt,
    this.lastMessage,
  });

  final String conversationId;
  final ChatPeer peer;
  final int unread;
  final String updatedAt;
  final ChatMessageDto? lastMessage;

  factory ChatConversationSummary.fromJson(Map<String, dynamic> json) {
    final lastRaw = json['lastMessage'];
    ChatMessageDto? last;
    if (lastRaw is Map) {
      final map = Map<String, dynamic>.from(lastRaw);
      last = ChatMessageDto(
        id: '${map['id'] ?? ''}',
        text: '${map['text'] ?? ''}',
        from: '${map['from'] ?? ''}',
        createdAt: '${map['createdAt'] ?? ''}',
        isMine: map['isMine'] == true,
      );
    }
    final peerRaw = json['peer'];
    return ChatConversationSummary(
      conversationId: '${json['conversationId'] ?? ''}',
      peer: peerRaw is Map
          ? ChatPeer.fromJson(Map<String, dynamic>.from(peerRaw))
          : const ChatPeer(
              id: '',
              targetId: '',
              name: '',
              initials: '?',
            ),
      unread: (json['unread'] as num?)?.toInt() ?? 0,
      updatedAt: '${json['updatedAt'] ?? ''}',
      lastMessage: last,
    );
  }
}

class ChatThreadSnapshot {
  const ChatThreadSnapshot({
    required this.conversationId,
    required this.peer,
    required this.messages,
    required this.unread,
  });

  final String conversationId;
  final ChatPeer peer;
  final List<ChatMessageDto> messages;
  final int unread;

  static const empty = ChatThreadSnapshot(
    conversationId: '',
    peer: ChatPeer(id: '', targetId: '', name: '', initials: '?'),
    messages: [],
    unread: 0,
  );
}

/// Typed chat API failure with a student-facing message.
class ChatException implements Exception {
  const ChatException(this.code, [this.detail]);

  final String code;
  final String? detail;

  String get userMessage {
    switch (code) {
      case 'friends_only':
        return 'You can only message friends. Add them on the map first.';
      case 'phone_required':
        return 'Sign in to use chat.';
      case 'peer_required':
      case 'peer_not_found':
        return 'That student could not be found.';
      case 'cannot_message_self':
        return 'You cannot message yourself.';
      case 'timeout':
        return 'Chat server timed out. Check your connection and try again.';
      case 'network':
        return 'Cannot reach chat server. Start the dashboard (port 5173) or check CONTENT_API_BASE.';
      case 'http':
        return detail ?? 'Chat server returned an error.';
      default:
        if (detail != null && detail!.trim().isNotEmpty) return detail!;
        return 'Something went wrong with chat.';
    }
  }

  @override
  String toString() => 'ChatException($code${detail != null ? ': $detail' : ''})';
}

/// Real 1:1 messaging API (friends-only, map demo peers allowed).
class ChatApi {
  ChatApi._();
  static final instance = ChatApi._();

  Future<List<ChatConversationSummary>> inbox(String phone) async {
    if (phone.trim().isEmpty) {
      throw const ChatException('phone_required');
    }
    final uri = Uri.parse('${contentApiBaseUrl()}/api/chat/inbox').replace(
      queryParameters: {'phone': phone.trim()},
    );
    final res = await _get(uri);
    final decoded = _decodeMap(res);
    final raw = decoded['conversations'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          ChatConversationSummary.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<ChatThreadSnapshot> thread({
    required String phone,
    required String peerId,
    String? since,
  }) async {
    if (phone.trim().isEmpty) {
      throw const ChatException('phone_required');
    }
    if (peerId.trim().isEmpty) {
      throw const ChatException('peer_required');
    }
    final uri = Uri.parse('${contentApiBaseUrl()}/api/chat/thread').replace(
      queryParameters: {
        'phone': phone.trim(),
        'peerId': peerId.trim(),
        if (since != null && since.isNotEmpty) 'since': since,
      },
    );
    final res = await _get(uri);
    final map = _decodeMap(res);
    final peerRaw = map['peer'];
    final messagesRaw = map['messages'];
    return ChatThreadSnapshot(
      conversationId: '${map['conversationId'] ?? ''}',
      peer: peerRaw is Map
          ? ChatPeer.fromJson(Map<String, dynamic>.from(peerRaw))
          : const ChatPeer(
              id: '',
              targetId: '',
              name: '',
              initials: '?',
            ),
      messages: messagesRaw is List
          ? [
              for (final item in messagesRaw)
                if (item is Map)
                  ChatMessageDto.fromJson(Map<String, dynamic>.from(item)),
            ]
          : const [],
      unread: (map['unread'] as num?)?.toInt() ?? 0,
    );
  }

  Future<ChatMessageDto> send({
    required String phone,
    required String peerId,
    required String text,
  }) async {
    if (phone.trim().isEmpty) {
      throw const ChatException('phone_required');
    }
    if (peerId.trim().isEmpty) {
      throw const ChatException('peer_required');
    }
    if (text.trim().isEmpty) {
      throw const ChatException('empty_message', 'Type a message first.');
    }
    final uri = Uri.parse('${contentApiBaseUrl()}/api/chat/send');
    final res = await _post(
      uri,
      body: {
        'phone': phone.trim(),
        'peerId': peerId.trim(),
        'text': text.trim(),
      },
      timeout: const Duration(seconds: 8),
    );
    final decoded = _decodeMap(res);
    final messageRaw = decoded['message'];
    if (messageRaw is! Map) {
      throw const ChatException('http', 'Chat server did not return a message.');
    }
    return ChatMessageDto.fromJson(Map<String, dynamic>.from(messageRaw));
  }

  Future<bool> markRead({
    required String phone,
    String? peerId,
    String? conversationId,
  }) async {
    if (phone.trim().isEmpty) return false;
    try {
      final uri = Uri.parse('${contentApiBaseUrl()}/api/chat/read');
      await _post(
        uri,
        body: {
          'phone': phone.trim(),
          if (peerId != null) 'peerId': peerId.trim(),
          if (conversationId != null) 'conversationId': conversationId,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<http.Response> _get(Uri uri) async {
    try {
      final res = await http
          .get(uri, headers: await apiAuthHeaders())
          .timeout(const Duration(seconds: 5));
      _ensureOk(res);
      return res;
    } on TimeoutException {
      throw const ChatException('timeout');
    } on ChatException {
      rethrow;
    } on http.ClientException catch (e) {
      throw ChatException('network', e.message);
    } catch (_) {
      throw const ChatException('network');
    }
  }

  Future<http.Response> _post(
    Uri uri, {
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final res = await http
          .post(uri, headers: await apiAuthHeaders(), body: jsonEncode(body))
          .timeout(timeout);
      _ensureOk(res);
      return res;
    } on TimeoutException {
      throw const ChatException('timeout');
    } on ChatException {
      rethrow;
    } on http.ClientException catch (e) {
      throw ChatException('network', e.message);
    } catch (_) {
      throw const ChatException('network');
    }
  }

  void _ensureOk(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    final code = _errorCodeFromBody(res.body);
    throw ChatException(
      code,
      code == 'http' ? 'Chat server error (${res.statusCode}).' : null,
    );
  }

  Map<String, dynamic> _decodeMap(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    throw const ChatException('http', 'Chat server returned invalid data.');
  }

  String _errorCodeFromBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] != null) {
        final code = '${decoded['error']}'.trim();
        if (code.isNotEmpty) return code;
      }
    } catch (_) {}
    return 'http';
  }
}

String formatChatTime(String iso) {
  if (iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '';
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inSeconds < 45) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24 && now.day == dt.day) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  if (diff.inDays < 7) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dt.weekday - 1];
  }
  return '${dt.day}/${dt.month}';
}
