import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the CMS catalog on device for offline use.
///
/// After a successful background CMS sync, the full catalog JSON is stored
/// locally and used as the fast path on the next cold start (before network).
class ContentLocalCache {
  ContentLocalCache._();

  static final ContentLocalCache instance = ContentLocalCache._();

  static const _prefsKey = 'cms_content_catalog_v1';
  static const _metaKey = 'cms_content_catalog_saved_at';

  /// Saves catalog JSON after a successful CMS fetch.
  Future<void> save(Map<String, dynamic> catalogJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(catalogJson));
    await prefs.setString(_metaKey, DateTime.now().toIso8601String());
  }

  /// Loads previously cached catalog JSON, or null if missing.
  Future<Map<String, dynamic>?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<DateTime?> savedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_metaKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    await prefs.remove(_metaKey);
  }
}
