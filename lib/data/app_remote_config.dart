import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'content/content_api.dart';

/// Live contact/social config from the admin dashboard (with offline cache).
class AppRemoteConfig {
  const AppRemoteConfig({
    required this.supportEmail,
    required this.supportPhoneDisplay,
    required this.supportPhoneTel,
    required this.website,
    required this.telegramUsername,
    required this.instagramUrl,
    required this.tiktokUrl,
    required this.youtubeUrl,
    required this.facebookUrl,
    required this.xUrl,
  });

  final String supportEmail;
  final String supportPhoneDisplay;
  final String supportPhoneTel;
  final String website;
  final String telegramUsername;
  final String instagramUrl;
  final String tiktokUrl;
  final String youtubeUrl;
  final String facebookUrl;
  final String xUrl;

  String get telegramHandle =>
      telegramUsername.startsWith('@') ? telegramUsername : '@$telegramUsername';

  String get telegramUrl => 'https://t.me/$telegramUsername';

  String get telegramDeepLink => 'tg://resolve?domain=$telegramUsername';

  static const defaults = AppRemoteConfig(
    supportEmail: 'contact@chkela.com',
    supportPhoneDisplay: '+251 947 819 388',
    supportPhoneTel: '+251947819388',
    website: 'https://www.chkela.com',
    telegramUsername: 'chkelaadmin',
    instagramUrl: 'https://www.instagram.com/chkela.app',
    tiktokUrl: 'https://www.tiktok.com/@chkela.app',
    youtubeUrl: 'https://www.youtube.com/@chkela',
    facebookUrl: 'https://www.facebook.com/chkela.app',
    xUrl: 'https://x.com/chkela_app',
  );

  factory AppRemoteConfig.fromJson(Map<String, dynamic> json) {
    final contact = (json['contact'] as Map<String, dynamic>?) ?? {};
    final social = (json['social'] as Map<String, dynamic>?) ?? {};
    final username = (contact['telegramUsername'] as String? ??
            defaults.telegramUsername)
        .trim()
        .replaceFirst(RegExp(r'^@'), '');
    return AppRemoteConfig(
      supportEmail:
          (contact['supportEmail'] as String?)?.trim() ?? defaults.supportEmail,
      supportPhoneDisplay: (contact['supportPhoneDisplay'] as String?)?.trim() ??
          defaults.supportPhoneDisplay,
      supportPhoneTel: (contact['supportPhoneTel'] as String?)
              ?.replaceAll(RegExp(r'[^\d+]'), '')
              .trim() ??
          defaults.supportPhoneTel,
      website: (contact['website'] as String?)?.trim() ?? defaults.website,
      telegramUsername:
          username.isEmpty ? defaults.telegramUsername : username,
      instagramUrl:
          (social['instagramUrl'] as String?)?.trim() ?? defaults.instagramUrl,
      tiktokUrl: (social['tiktokUrl'] as String?)?.trim() ?? defaults.tiktokUrl,
      youtubeUrl:
          (social['youtubeUrl'] as String?)?.trim() ?? defaults.youtubeUrl,
      facebookUrl:
          (social['facebookUrl'] as String?)?.trim() ?? defaults.facebookUrl,
      xUrl: (social['xUrl'] as String?)?.trim() ?? defaults.xUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'contact': {
          'supportEmail': supportEmail,
          'supportPhoneDisplay': supportPhoneDisplay,
          'supportPhoneTel': supportPhoneTel,
          'website': website,
          'telegramUsername': telegramUsername,
        },
        'social': {
          'instagramUrl': instagramUrl,
          'tiktokUrl': tiktokUrl,
          'youtubeUrl': youtubeUrl,
          'facebookUrl': facebookUrl,
          'xUrl': xUrl,
        },
      };
}

abstract final class AppRemoteConfigStore {
  static const _cacheKey = 'chkela_app_remote_config';

  static Future<AppRemoteConfig> loadCachedOrDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return AppRemoteConfig.defaults;
    try {
      return AppRemoteConfig.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return AppRemoteConfig.defaults;
    }
  }

  static Future<void> saveCache(AppRemoteConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(config.toJson()));
  }

  static Future<AppRemoteConfig> fetchAndCache({http.Client? client}) async {
    final httpClient = client ?? http.Client();
    try {
      final uri = Uri.parse('${contentApiBaseUrl()}/api/app-config');
      final response =
          await httpClient.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) {
        return loadCachedOrDefaults();
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final configJson =
          (decoded['config'] as Map<String, dynamic>?) ?? decoded;
      final config = AppRemoteConfig.fromJson(configJson);
      await saveCache(config);
      return config;
    } catch (e, st) {
      debugPrint('AppRemoteConfigStore.fetch failed: $e\n$st');
      return loadCachedOrDefaults();
    }
  }
}

final appRemoteConfigProvider =
    StateNotifierProvider<AppRemoteConfigNotifier, AppRemoteConfig>((ref) {
  return AppRemoteConfigNotifier()..refresh();
});

class AppRemoteConfigNotifier extends StateNotifier<AppRemoteConfig> {
  AppRemoteConfigNotifier() : super(AppRemoteConfig.defaults);

  Future<void> refresh() async {
    final cached = await AppRemoteConfigStore.loadCachedOrDefaults();
    state = cached;
    final remote = await AppRemoteConfigStore.fetchAndCache();
    state = remote;
  }
}
