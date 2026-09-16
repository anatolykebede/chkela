import 'package:shared_preferences/shared_preferences.dart';

/// Local free-period unlock earned via referral redeem (invitee) or credits.
abstract final class ReferralUnlockStore {
  static const _untilKey = 'chkela_referral_unlock_until';

  static Future<DateTime?> unlockUntil() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_untilKey);
    if (raw == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(raw);
  }

  static Future<bool> isActive() async {
    final until = await unlockUntil();
    if (until == null) return false;
    return until.isAfter(DateTime.now());
  }

  /// Extends unlock from now (or existing expiry) by [days].
  static Future<DateTime> grantDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await unlockUntil();
    final base =
        (current != null && current.isAfter(DateTime.now()))
            ? current
            : DateTime.now();
    final until = base.add(Duration(days: days));
    await prefs.setInt(_untilKey, until.millisecondsSinceEpoch);
    return until;
  }
}
