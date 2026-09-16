import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_auth_headers.dart';
import 'content/content_api.dart';

/// Auth OTP via dashboard proxy → social API → AfroMessage.
String authApiBaseUrl() => contentApiBaseUrl();

class AuthOtpException implements Exception {
  AuthOtpException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthRemoteUser {
  const AuthRemoteUser({
    required this.phone,
    required this.onboardingComplete,
    this.displayName = '',
    this.grade = '',
    this.birthdate,
    this.interests = const [],
  });

  final String phone;
  final bool onboardingComplete;
  final String displayName;
  final String grade;
  final String? birthdate;
  final List<String> interests;

  factory AuthRemoteUser.fromJson(Map<String, dynamic> json) {
    final interestsRaw = json['interests'];
    return AuthRemoteUser(
      phone: json['phone'] as String? ?? '',
      onboardingComplete: json['onboardingComplete'] == true,
      displayName: (json['displayName'] as String?)?.trim().isNotEmpty == true
          ? (json['displayName'] as String).trim()
          : ((json['name'] as String?)?.trim() ?? ''),
      grade: json['grade'] as String? ?? '',
      birthdate: json['birthdate'] as String?,
      interests: interestsRaw is List
          ? interestsRaw.map((e) => e.toString()).toList()
          : const [],
    );
  }
}

class AuthVerifyResult {
  const AuthVerifyResult({
    required this.phone,
    required this.onboardingComplete,
    this.user,
    this.token,
  });

  final String phone;
  final bool onboardingComplete;
  final AuthRemoteUser? user;
  final String? token;
}

class AuthApi {
  AuthApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<void> sendOtp(String phoneE164) async {
    final uri = Uri.parse('${authApiBaseUrl()}/api/auth/otp/send');
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'phone': phoneE164}),
        )
        .timeout(const Duration(seconds: 20));

    final body = _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body['ok'] == true) return;
    }
    throw AuthOtpException(_errorMessage(body, 'Could not send SMS code'));
  }

  Future<AuthVerifyResult> verifyOtp({
    required String phoneE164,
    required String code,
  }) async {
    final uri = Uri.parse('${authApiBaseUrl()}/api/auth/otp/verify');
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'phone': phoneE164, 'code': code}),
        )
        .timeout(const Duration(seconds: 20));

    final body = _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body['ok'] == true && body['verified'] == true) {
        final userJson = body['user'];
        final user = userJson is Map<String, dynamic>
            ? AuthRemoteUser.fromJson(userJson)
            : userJson is Map
                ? AuthRemoteUser.fromJson(Map<String, dynamic>.from(userJson))
                : null;
        return AuthVerifyResult(
          phone: body['phone'] as String? ?? phoneE164,
          onboardingComplete: user?.onboardingComplete == true,
          user: user,
          token: (body['token'] as String?)?.trim(),
        );
      }
    }
    throw AuthOtpException(
      _friendlyOtpError(
        body,
        statusCode: response.statusCode,
        fallback: 'Incorrect code. Try again.',
      ),
    );
  }

  Future<AuthRemoteUser?> fetchMe(String phoneE164) async {
    final uri = Uri.parse('${authApiBaseUrl()}/api/auth/me').replace(
      queryParameters: {'phone': phoneE164},
    );
    final response = await _client
        .get(uri, headers: await apiAuthHeaders(json: false))
        .timeout(const Duration(seconds: 12));
    final body = _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final userJson = body['user'];
      if (userJson == null) return null;
      if (userJson is Map<String, dynamic>) {
        return AuthRemoteUser.fromJson(userJson);
      }
      if (userJson is Map) {
        return AuthRemoteUser.fromJson(Map<String, dynamic>.from(userJson));
      }
    }
    return null;
  }

  Future<void> syncProfile({
    required String phoneE164,
    String? displayName,
    String? grade,
    DateTime? birthdate,
    Set<String>? interests,
    bool? onboardingComplete,
  }) async {
    final uri = Uri.parse('${authApiBaseUrl()}/api/auth/profile');
    final payload = <String, dynamic>{
      'phone': phoneE164,
      if (displayName != null) 'displayName': displayName,
      if (grade != null) 'grade': grade,
      if (birthdate != null)
        'birthdate': birthdate.toIso8601String().split('T').first,
      if (interests != null) 'interests': interests.toList(),
      if (onboardingComplete != null)
        'onboardingComplete': onboardingComplete,
    };

    final response = await _client
        .post(
          uri,
          headers: await apiAuthHeaders(),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));

    final body = _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body['ok'] == true) return;
    }
    throw AuthOtpException(_errorMessage(body, 'Could not sync profile'));
  }

  Future<void> deleteAccount(String phoneE164) async {
    final uri = Uri.parse('${authApiBaseUrl()}/api/auth/account/delete');
    final response = await _client
        .post(
          uri,
          headers: await apiAuthHeaders(),
          body: jsonEncode({'phone': phoneE164}),
        )
        .timeout(const Duration(seconds: 20));

    final body = _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body['ok'] == true) return;
    }
    throw AuthOtpException(_errorMessage(body, 'Could not delete account'));
  }

  Map<String, dynamic> _decode(String raw) {
    if (raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {};
  }

  String _errorMessage(Map<String, dynamic> body, String fallback) {
    final message = body['message'];
    if (message is String && message.trim().isNotEmpty) {
      return _humanizeProviderMessage(message.trim());
    }
    final error = body['error'];
    if (error is String && error.trim().isNotEmpty) {
      final trimmed = error.trim();
      // Fastify puts status text in `error` and the real reason in `message`.
      if (RegExp(
        r'^(bad gateway|bad request|unauthorized|forbidden|not found|internal server error)$',
        caseSensitive: false,
      ).hasMatch(trimmed)) {
        return fallback;
      }
      return _humanizeProviderMessage(trimmed);
    }
    return fallback;
  }

  String _humanizeProviderMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('unverified contact')) {
      return 'This number is not verified for SMS yet. In AfroMessage (beta), open Contacts, find the number, and tap Verify. Then try again.';
    }
    if (lower.contains('afromessage_not_configured') ||
        lower.contains('sms provider is not configured')) {
      return 'SMS is not configured on the server yet.';
    }
    return raw;
  }

  /// Maps opaque HTTP / provider errors to clear OTP copy.
  String _friendlyOtpError(
    Map<String, dynamic> body, {
    required int statusCode,
    required String fallback,
  }) {
    final raw = _errorMessage(body, '');
    final lower = raw.toLowerCase();

    if (raw.isEmpty ||
        RegExp(
          r'^(bad request|unauthorized|forbidden|not found|internal server error|http error|error)$',
          caseSensitive: false,
        ).hasMatch(lower) ||
        lower.contains('bad request') ||
        lower.contains('afromessage_http_4')) {
      if (statusCode == 429) {
        return 'Too many attempts. Wait a moment and try again.';
      }
      if (statusCode >= 500) {
        return 'Could not verify code right now. Try again.';
      }
      return fallback;
    }

    if (RegExp(
      r'invalid|incorrect|expire|mismatch|wrong|code',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return 'Incorrect code. Try again.';
    }

    return raw;
  }
}
