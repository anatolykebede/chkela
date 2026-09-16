import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local profile for a phone number (survives app restarts).
class StoredUserProfile {
  const StoredUserProfile({
    required this.phoneE164,
    required this.onboardingComplete,
    this.fullName,
    this.grade,
    this.birthdate,
    this.interests = const {},
  });

  final String phoneE164;
  final bool onboardingComplete;
  final String? fullName;
  final String? grade;
  final DateTime? birthdate;
  final Set<String> interests;

  Map<String, dynamic> toJson() => {
        'phoneE164': phoneE164,
        'onboardingComplete': onboardingComplete,
        'fullName': fullName,
        'grade': grade,
        'birthdate': birthdate?.toIso8601String(),
        'interests': interests.toList(),
      };

  factory StoredUserProfile.fromJson(Map<String, dynamic> json) {
    final interestsRaw = json['interests'];
    return StoredUserProfile(
      phoneE164: json['phoneE164'] as String,
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      fullName: json['fullName'] as String?,
      grade: json['grade'] as String?,
      birthdate: json['birthdate'] != null
          ? DateTime.tryParse(json['birthdate'] as String)
          : null,
      interests: interestsRaw is List
          ? interestsRaw.map((e) => e.toString()).toSet()
          : {},
    );
  }
}

/// Persists the active session + per-phone profiles on device.
class AuthSessionStore {
  AuthSessionStore._();

  static const _sessionPhoneKey = 'chkela_session_phone';
  static const _sessionTokenKey = 'chkela_session_token';
  static const _profilesKey = 'chkela_user_profiles';
  static const _pendingReferralKey = 'chkela_pending_referral_code';

  static const _secure = FlutterSecureStorage();

  static Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  static Future<Map<String, StoredUserProfile>> loadProfiles() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_profilesKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(
          key,
          StoredUserProfile.fromJson(value as Map<String, dynamic>),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveProfile(StoredUserProfile profile) async {
    final prefs = await _prefs;
    final profiles = await loadProfiles();
    profiles[profile.phoneE164] = profile;
    final encoded = jsonEncode(
      profiles.map((key, value) => MapEntry(key, value.toJson())),
    );
    await prefs.setString(_profilesKey, encoded);
  }

  static Future<StoredUserProfile?> profileFor(String phoneE164) async {
    final profiles = await loadProfiles();
    return profiles[phoneE164];
  }

  static Future<String?> loadSessionPhone() async {
    final prefs = await _prefs;
    return prefs.getString(_sessionPhoneKey);
  }

  static Future<void> saveSessionPhone(String phoneE164) async {
    final prefs = await _prefs;
    await prefs.setString(_sessionPhoneKey, phoneE164);
  }

  static Future<String?> loadSessionToken() async {
    final secure = await _secure.read(key: _sessionTokenKey);
    if (secure != null && secure.trim().isNotEmpty) return secure.trim();

    // One-time migrate from older SharedPreferences storage.
    final prefs = await _prefs;
    final legacy = prefs.getString(_sessionTokenKey);
    if (legacy == null || legacy.trim().isEmpty) return null;
    await saveSessionToken(legacy);
    await prefs.remove(_sessionTokenKey);
    return legacy.trim();
  }

  static Future<void> saveSessionToken(String token) async {
    final trimmed = token.trim();
    await _secure.write(key: _sessionTokenKey, value: trimmed);
    final prefs = await _prefs;
    await prefs.remove(_sessionTokenKey);
  }

  static Future<void> clearSession() async {
    final prefs = await _prefs;
    await prefs.remove(_sessionPhoneKey);
    await prefs.remove(_sessionTokenKey);
    await _secure.delete(key: _sessionTokenKey);
  }

  static Future<void> deleteProfile(String phoneE164) async {
    final prefs = await _prefs;
    final profiles = await loadProfiles();
    profiles.remove(phoneE164);
    final encoded = jsonEncode(
      profiles.map((key, value) => MapEntry(key, value.toJson())),
    );
    await prefs.setString(_profilesKey, encoded);
    final session = await loadSessionPhone();
    if (session == phoneE164) {
      await prefs.remove(_sessionPhoneKey);
      await prefs.remove(_sessionTokenKey);
      await _secure.delete(key: _sessionTokenKey);
    }
  }

  static Future<String?> loadPendingReferralCode() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_pendingReferralKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim().toUpperCase();
  }

  static Future<void> savePendingReferralCode(String? code) async {
    final prefs = await _prefs;
    final trimmed = code?.trim().toUpperCase() ?? '';
    if (trimmed.isEmpty) {
      await prefs.remove(_pendingReferralKey);
      return;
    }
    await prefs.setString(_pendingReferralKey, trimmed);
  }

  static Future<void> clearPendingReferralCode() async {
    final prefs = await _prefs;
    await prefs.remove(_pendingReferralKey);
  }
}
