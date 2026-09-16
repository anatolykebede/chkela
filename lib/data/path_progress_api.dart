import 'dart:convert';

import 'package:http/http.dart' as http;

import 'content/content_api.dart' show contentApiBaseUrl;

/// Shared with dashboard `CHKELA_PATH_PROGRESS_SECRET`.
String pathProgressSecret() {
  const fromEnv = String.fromEnvironment(
    'CHKELA_PATH_PROGRESS_SECRET',
    defaultValue: 'chkela-local-path-progress',
  );
  return fromEnv;
}

/// Pushes / pulls Path progress (by phone) with a shared secret.
class PathProgressApi {
  PathProgressApi._();
  static final instance = PathProgressApi._();

  Map<String, String> get _headers {
    final secret = pathProgressSecret();
    return {
      'Content-Type': 'application/json',
      // Dashboard accepts either header or Bearer (see shared/path/vitePlugin.mjs).
      'X-Chkela-Path-Secret': secret,
      'Authorization': 'Bearer $secret',
    };
  }

  Future<Map<String, dynamic>?> fetchByPhone(String phone) async {
    if (phone.trim().isEmpty) return null;
    try {
      final uri = Uri.parse('${contentApiBaseUrl()}/api/path/progress').replace(
        queryParameters: {'phone': phone.trim()},
      );
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      final progress = decoded['progress'];
      if (progress is Map<String, dynamic>) return progress;
      if (progress is Map) return Map<String, dynamic>.from(progress);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> upsert({
    required String phone,
    required String currentLevelId,
    required int currentLevelNumber,
    required String currentLevelTitle,
    required int clearedCount,
    required int totalStars,
    required int streak,
    required int xp,
    required Map<String, int> stars,
    required Map<String, int> weakSkills,
    String? dailyDoneDay,
  }) async {
    if (phone.trim().isEmpty) return;
    try {
      final uri = Uri.parse('${contentApiBaseUrl()}/api/path/progress');
      await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              'phone': phone,
              'currentLevelId': currentLevelId,
              'currentLevelNumber': currentLevelNumber,
              'currentLevelTitle': currentLevelTitle,
              'clearedCount': clearedCount,
              'totalStars': totalStars,
              'streak': streak,
              'xp': xp,
              'stars': stars,
              'weakSkills': weakSkills,
              'dailyDoneDay': dailyDoneDay,
            }),
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // Offline / dashboard down: local progress still saved.
    }
  }
}
