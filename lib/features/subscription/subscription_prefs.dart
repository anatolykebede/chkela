import 'package:shared_preferences/shared_preferences.dart';

/// Local flags that control subscription UX (walkthrough, home nudge).
abstract final class SubscriptionPrefs {
  static const _walkthroughSeenKey = 'chkela_sub_walkthrough_seen';
  static const _nudgeDismissedAtKey = 'chkela_sub_nudge_dismissed_at';

  /// Hide the marketing walkthrough after the first view.
  static Future<bool> hasSeenWalkthrough() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_walkthroughSeenKey) ?? false;
  }

  static Future<void> markWalkthroughSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_walkthroughSeenKey, true);
  }

  /// Soft home nudge — hidden for [cooldown] after dismiss.
  static Future<bool> shouldShowHomeNudge({
    Duration cooldown = const Duration(days: 7),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_nudgeDismissedAtKey);
    if (raw == null) return true;
    final dismissedAt = DateTime.fromMillisecondsSinceEpoch(raw);
    return DateTime.now().difference(dismissedAt) >= cooldown;
  }

  static Future<void> dismissHomeNudge() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _nudgeDismissedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}
