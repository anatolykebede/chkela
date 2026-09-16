import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_study_context.dart';
import 'api_auth_headers.dart';
import 'content/content_api.dart';

class AiQuota {
  const AiQuota({
    required this.used,
    required this.limit,
    required this.remaining,
  });

  final int used;
  final int limit;
  final int remaining;

  factory AiQuota.fromJson(Map<String, dynamic>? json, {int fallbackLimit = 3}) {
    return AiQuota(
      used: (json?['used'] as num?)?.toInt() ?? 0,
      limit: (json?['limit'] as num?)?.toInt() ?? fallbackLimit,
      remaining: (json?['remaining'] as num?)?.toInt() ?? fallbackLimit,
    );
  }
}

class AiTutorReply {
  const AiTutorReply({required this.reply, required this.quota});

  final String reply;
  final AiQuota quota;
}

class AiApiException implements Exception {
  AiApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AiApi {
  AiApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _base => contentApiBaseUrl();

  Future<AiQuota> fetchQuota({String feature = 'tutor'}) async {
    final uri = Uri.parse('$_base/api/ai/quota').replace(
      queryParameters: {'feature': feature},
    );
    final response = await _client
        .get(uri, headers: await apiAuthHeaders(json: false))
        .timeout(const Duration(seconds: 10));
    final body = _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return AiQuota.fromJson(body);
    }
    throw AiApiException(
      _errorMessage(body, fallback: 'Could not load AI quota'),
      statusCode: response.statusCode,
    );
  }

  Future<AiTutorReply> askTutor({
    required String message,
    required AiStudyContext context,
    List<String> weakSpots = const [],
  }) async {
    return _postFeature(
      path: '/api/ai/tutor',
      payload: {
        'message': message,
        'context': context.toJson(),
        'weakSpots': weakSpots,
      },
      fallbackLimit: 3,
    );
  }

  Future<AiTutorReply> coachWrongAnswer({
    required String question,
    required List<String> options,
    required String studentAnswer,
    required String correctAnswer,
    String explanation = '',
    AiStudyContext context = const AiStudyContext(),
  }) async {
    return _postFeature(
      path: '/api/ai/wrong-answer',
      payload: {
        'question': question,
        'options': options,
        'studentAnswer': studentAnswer,
        'correctAnswer': correctAnswer,
        'explanation': explanation,
        'context': context.toJson(),
      },
      fallbackLimit: 20,
    );
  }

  Future<AiTutorReply> explainSelection({
    required String selection,
    required AiStudyContext context,
  }) async {
    return _postFeature(
      path: '/api/ai/explain',
      payload: {
        'selection': selection,
        'context': context.toJson(),
      },
      fallbackLimit: 20,
    );
  }

  Future<AiTutorReply> translateText({
    required String text,
    required String target,
  }) async {
    return _postFeature(
      path: '/api/ai/translate',
      payload: {
        'text': text,
        'target': target,
      },
      fallbackLimit: 40,
    );
  }

  Future<AiTutorReply> _postFeature({
    required String path,
    required Map<String, dynamic> payload,
    required int fallbackLimit,
  }) async {
    final uri = Uri.parse('$_base$path');
    final response = await _client
        .post(
          uri,
          headers: await apiAuthHeaders(),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 45));
    final body = _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final reply = (body['reply'] as String?)?.trim() ?? '';
      if (reply.isEmpty) {
        throw AiApiException('Empty AI response');
      }
      return AiTutorReply(
        reply: reply,
        quota: AiQuota.fromJson(
          body['quota'] is Map
              ? Map<String, dynamic>.from(body['quota'] as Map)
              : null,
          fallbackLimit: fallbackLimit,
        ),
      );
    }
    throw AiApiException(
      _errorMessage(body, fallback: 'AI request failed'),
      statusCode: response.statusCode,
    );
  }

  String _errorMessage(
    Map<String, dynamic> body, {
    required String fallback,
  }) {
    final message = (body['message'] as String?)?.trim();
    if (message != null && message.isNotEmpty) return message;
    final error = (body['error'] as String?)?.trim();
    if (error != null &&
        error.isNotEmpty &&
        error.toLowerCase() != 'bad gateway' &&
        error.toLowerCase() != 'internal server error') {
      return error;
    }
    return fallback;
  }

  Map<String, dynamic> _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {};
  }
}

/// Local ring buffer of recent wrong answers for “weak spots”.
class AiWeakSpotStore {
  AiWeakSpotStore._();

  static const _key = 'chkela_ai_weak_spots';
  static const _max = 12;

  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    return raw.where((e) => e.trim().isNotEmpty).toList();
  }

  static Future<void> record({
    required String subject,
    required String chapter,
    required String question,
    required String studentAnswer,
    required String correctAnswer,
  }) async {
    final line =
        '${subject.isNotEmpty ? '$subject · ' : ''}${chapter.isNotEmpty ? '$chapter · ' : ''}'
        'Q: ${question.trim()} | You: ${studentAnswer.trim()} | Answer: ${correctAnswer.trim()}';
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key) ?? <String>[];
    current.insert(0, line.length > 220 ? '${line.substring(0, 220)}…' : line);
    while (current.length > _max) {
      current.removeLast();
    }
    await prefs.setStringList(_key, current);
  }
}
