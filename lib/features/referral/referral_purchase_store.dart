import 'package:shared_preferences/shared_preferences.dart';

import '../../data/referral_api.dart';

/// Local flags for invitee purchase discount after referral redeem.
abstract final class ReferralPurchaseStore {
  static const _discountPercentKey = 'chkela_referral_purchase_discount';

  static Future<int> discountPercent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_discountPercentKey) ?? 0;
  }

  static Future<bool> isEligible() async {
    return (await discountPercent()) > 0;
  }

  static Future<void> markEligible({
    int percent = kInviteePurchaseDiscountPercent,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_discountPercentKey, percent);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_discountPercentKey);
  }
}
