import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/home_mock_data.dart';
import '../../data/payments_api.dart';

/// Canonical paid entitlements (G11/G12 streams are separate).
const subscriptionEntitlements = selectableGrades;

/// Normalize a grade / stream label to a paid entitlement key.
String? subscriptionEntitlementKey(String? raw) {
  if (raw == null) return null;
  final text = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty) return null;

  final lower = text.toLowerCase();
  if (lower.startsWith('grade 9')) return 'Grade 9';
  if (lower.startsWith('grade 10')) return 'Grade 10';

  final is11 = lower.startsWith('grade 11');
  final is12 = lower.startsWith('grade 12');
  if (!is11 && !is12) return text;

  final base = is11 ? 'Grade 11' : 'Grade 12';
  if (RegExp(r'\bnatural\b', caseSensitive: false).hasMatch(text)) {
    return '$base · Natural';
  }
  if (RegExp(r'\bsocial\b', caseSensitive: false).hasMatch(text)) {
    return '$base · Social';
  }
  // Bare Grade 11 / 12 is not enough — Natural and Social are separate.
  return null;
}

List<String> normalizeSubscriptionEntitlements(Iterable<String> grades) {
  final out = <String>[];
  final seen = <String>{};
  for (final item in grades) {
    final key = subscriptionEntitlementKey(item);
    if (key == null || seen.contains(key)) continue;
    seen.add(key);
    out.add(key);
  }
  return out;
}

/// Local entitlement cache; refreshed from `/api/subscriptions/me` when online.
abstract final class SubscriptionAccessStore {
  static const _activeKey = 'chkela_subscription_active';
  static const _gradesKey = 'chkela_subscription_grades_v1';
  static const _planKey = 'chkela_subscription_plan_v1';

  static Future<bool> isActive() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_activeKey) != true) return false;
    final plan = prefs.getString(_planKey);
    if (plan == 'bundle' || plan == 'all') return true;
    final grades = await paidGrades();
    return grades.isNotEmpty;
  }

  static Future<List<String>> paidGrades() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_gradesKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return normalizeSubscriptionEntitlements([
        for (final item in decoded)
          if (item != null) item.toString(),
      ]);
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> hasAccessForGrade(String gradeSelection) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_activeKey) != true) return false;
    final plan = prefs.getString(_planKey);
    if (plan == 'bundle' || plan == 'all') return true;
    final paid = await paidGrades();
    if (paid.isEmpty) return false;
    final wanted = subscriptionEntitlementKey(gradeSelection);
    if (wanted == null) return false;
    return paid.contains(wanted);
  }

  static Future<void> markSubscribed({
    List<String> grades = const [],
    String plan = 'plus',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final unique = normalizeSubscriptionEntitlements(grades);
    final isBundle = plan == 'bundle' ||
        plan == 'all' ||
        subscriptionEntitlements.every(unique.contains);
    final storedGrades =
        isBundle ? List<String>.from(subscriptionEntitlements) : unique;

    await prefs.setBool(_activeKey, true);
    await prefs.setString(_planKey, isBundle ? 'bundle' : plan);
    await prefs.setString(_gradesKey, jsonEncode(storedGrades));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeKey);
    await prefs.remove(_gradesKey);
    await prefs.remove(_planKey);
  }

  static Future<void> clearForTesting() => clear();

  /// Pull paid status from the social API and update local cache.
  static Future<bool> syncFromServer({PaymentsApi? api}) async {
    try {
      final status = await (api ?? PaymentsApi()).fetchMySubscription();
      if (status.paid) {
        await markSubscribed(
          grades: status.grades,
          plan: status.plan ?? 'plus',
        );
      } else {
        await clear();
      }
      return status.paid;
    } catch (_) {
      return isActive();
    }
  }
}
