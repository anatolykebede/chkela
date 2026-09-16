import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_auth_headers.dart';
import 'content/content_api.dart';

class RemoteLeaderboardEntry {
  const RemoteLeaderboardEntry({
    required this.phone,
    required this.name,
    required this.grade,
    required this.points,
  });

  final String phone;
  final String name;
  final String grade;
  final int points;

  factory RemoteLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    final name = (json['displayName'] as String?)?.trim().isNotEmpty == true
        ? (json['displayName'] as String).trim()
        : ((json['name'] as String?)?.trim() ?? 'Student');
    return RemoteLeaderboardEntry(
      phone: json['phone'] as String? ?? '',
      name: name,
      grade: json['grade'] as String? ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
    );
  }
}

class LeaderboardApi {
  LeaderboardApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _base => contentApiBaseUrl();

  Future<void> upsertScore({
    required String phoneE164,
    required String displayName,
    required String grade,
    required int points,
  }) async {
    final uri = Uri.parse('$_base/api/leaderboard/score');
    final response = await _client
        .post(
          uri,
          headers: await apiAuthHeaders(),
          body: jsonEncode({
            'phone': phoneE164,
            'displayName': displayName,
            'grade': grade,
            'points': points,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('leaderboard_upsert_failed');
    }
  }

  Future<List<RemoteLeaderboardEntry>> listByGrade(String grade) async {
    final uri = Uri.parse('$_base/api/leaderboard').replace(
      queryParameters: {'grade': grade, 'limit': '100'},
    );
    final response = await _client
        .get(uri, headers: await apiAuthHeaders(json: false))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('leaderboard_list_failed');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return const [];
    final raw = decoded['entries'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          RemoteLeaderboardEntry.fromJson(Map<String, dynamic>.from(item)),
    ];
  }
}
