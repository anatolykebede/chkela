import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_auth_headers.dart';
import 'content/content_api.dart' show contentApiBaseUrl;

enum FriendRelationStatus {
  none,
  outgoing,
  incoming,
  friends,
}

class FriendPeerSummary {
  const FriendPeerSummary({
    required this.id,
    required this.targetId,
    required this.name,
    required this.initials,
    this.grade = '',
    this.school = '',
    this.subjects = const [],
    this.bio = '',
    this.kind = 'map',
  });

  final String id;
  final String targetId;
  final String name;
  final String initials;
  final String grade;
  final String school;
  final List<String> subjects;
  final String bio;
  final String kind;

  factory FriendPeerSummary.fromJson(Map<String, dynamic> json) {
    final subjectsRaw = json['subjects'];
    return FriendPeerSummary(
      id: '${json['id'] ?? json['targetId'] ?? ''}',
      targetId: '${json['targetId'] ?? json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      initials: '${json['initials'] ?? '?'}',
      grade: '${json['grade'] ?? ''}',
      school: '${json['school'] ?? ''}',
      subjects: subjectsRaw is List
          ? subjectsRaw.map((e) => '$e').where((e) => e.isNotEmpty).toList()
          : const [],
      bio: '${json['bio'] ?? ''}',
      kind: '${json['kind'] ?? 'map'}',
    );
  }
}

class FriendEdge {
  const FriendEdge({
    required this.friendshipId,
    required this.status,
    required this.peer,
  });

  final String friendshipId;
  final String status;
  final FriendPeerSummary peer;

  factory FriendEdge.fromJson(Map<String, dynamic> json) {
    final peerRaw = json['peer'];
    return FriendEdge(
      friendshipId: '${json['friendshipId'] ?? ''}',
      status: '${json['status'] ?? ''}',
      peer: peerRaw is Map
          ? FriendPeerSummary.fromJson(Map<String, dynamic>.from(peerRaw))
          : const FriendPeerSummary(
              id: '',
              targetId: '',
              name: '',
              initials: '?',
            ),
    );
  }
}

class FriendsSnapshot {
  const FriendsSnapshot({
    required this.friends,
    required this.incoming,
    required this.outgoing,
  });

  final List<FriendEdge> friends;
  final List<FriendEdge> incoming;
  final List<FriendEdge> outgoing;

  static const empty = FriendsSnapshot(
    friends: [],
    incoming: [],
    outgoing: [],
  );

  factory FriendsSnapshot.fromJson(Map<String, dynamic> json) {
    List<FriendEdge> parse(String key) {
      final raw = json[key];
      if (raw is! List) return const [];
      return [
        for (final item in raw)
          if (item is Map)
            FriendEdge.fromJson(Map<String, dynamic>.from(item)),
      ];
    }

    return FriendsSnapshot(
      friends: parse('friends'),
      incoming: parse('incoming'),
      outgoing: parse('outgoing'),
    );
  }
}

/// Remote friends graph keyed by signed-in phone.
class FriendsApi {
  FriendsApi._();
  static final instance = FriendsApi._();

  /// Returns null when the friends API is unreachable / invalid so callers
  /// can keep the last good graph instead of wiping it.
  Future<FriendsSnapshot?> fetch(String phone) async {
    if (phone.trim().isEmpty) return FriendsSnapshot.empty;
    try {
      final uri = Uri.parse('${contentApiBaseUrl()}/api/friends').replace(
        queryParameters: {'phone': phone.trim()},
      );
      final res = await http
          .get(uri, headers: await apiAuthHeaders())
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      return FriendsSnapshot.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertProfile({
    required String phone,
    required String mapId,
    required String displayName,
    required String school,
    required String bio,
    required String grade,
    required String cityId,
    required List<String> subjects,
    String? tagline,
    String? moodEmoji,
    String? moodLabel,
  }) async {
    if (phone.trim().isEmpty) return;
    try {
      final uri = Uri.parse('${contentApiBaseUrl()}/api/friends/profile');
      await http
          .post(
            uri,
            headers: await apiAuthHeaders(),
            body: jsonEncode({
              'phone': phone.trim(),
              'mapId': mapId,
              'displayName': displayName,
              'school': school,
              'bio': bio,
              'grade': grade,
              'cityId': cityId,
              'subjects': subjects,
              'tagline': tagline,
              'moodEmoji': moodEmoji,
              'moodLabel': moodLabel,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<String?> request({
    required String phone,
    required String targetId,
  }) async {
    if (phone.trim().isEmpty || targetId.trim().isEmpty) return null;
    try {
      final uri = Uri.parse('${contentApiBaseUrl()}/api/friends/request');
      final res = await http
          .post(
            uri,
            headers: await apiAuthHeaders(),
            body: jsonEncode({
              'phone': phone.trim(),
              'targetId': targetId.trim(),
            }),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      return '${decoded['state'] ?? ''}';
    } catch (_) {
      return null;
    }
  }

  Future<String?> respond({
    required String phone,
    required String friendshipId,
    required String action,
  }) async {
    if (phone.trim().isEmpty || friendshipId.trim().isEmpty) return null;
    try {
      final uri = Uri.parse('${contentApiBaseUrl()}/api/friends/respond');
      final res = await http
          .post(
            uri,
            headers: await apiAuthHeaders(),
            body: jsonEncode({
              'phone': phone.trim(),
              'friendshipId': friendshipId.trim(),
              'action': action,
            }),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      return '${decoded['state'] ?? ''}';
    } catch (_) {
      return null;
    }
  }

  Future<bool> remove({
    required String phone,
    String? targetId,
    String? friendshipId,
  }) async {
    if (phone.trim().isEmpty) return false;
    try {
      final uri = Uri.parse('${contentApiBaseUrl()}/api/friends/remove');
      final res = await http
          .post(
            uri,
            headers: await apiAuthHeaders(),
            body: jsonEncode({
              'phone': phone.trim(),
              if (targetId != null) 'targetId': targetId.trim(),
              if (friendshipId != null) 'friendshipId': friendshipId.trim(),
            }),
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Notifies the target that [viewerPhone] opened their profile (rate-limited).
  Future<void> reportProfileView({
    required String viewerPhone,
    required String targetId,
  }) async {
    if (viewerPhone.trim().isEmpty || targetId.trim().isEmpty) return;
    try {
      final uri = Uri.parse('${contentApiBaseUrl()}/api/friends/view');
      await http
          .post(
            uri,
            headers: await apiAuthHeaders(),
            body: jsonEncode({
              'viewerPhone': viewerPhone.trim(),
              'targetId': targetId.trim(),
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
}
