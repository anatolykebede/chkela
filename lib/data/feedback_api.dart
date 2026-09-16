import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'content/content_api.dart';

class FeedbackApi {
  FeedbackApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<bool> submit({
    required String message,
    String? phone,
  }) async {
    try {
      final uri = Uri.parse('${contentApiBaseUrl()}/api/feedback');
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': message,
              if (phone != null && phone.isNotEmpty) 'phone': phone,
            }),
          )
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e, st) {
      debugPrint('FeedbackApi.submit failed: $e\n$st');
      return false;
    }
  }
}
