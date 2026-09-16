import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_auth_headers.dart';
import 'content/content_api.dart';

/// Same dashboard base as the content CMS (127.0.0.1:5173 locally).
String referralApiBaseUrl() => contentApiBaseUrl();

const kInviteePurchaseDiscountPercent = 10;
const kReferrerPurchaseCpPercent = 20;

class ReferralMe {
  const ReferralMe({
    required this.code,
    required this.link,
    required this.referrerPhone,
    required this.inviteCount,
    required this.creditDaysEarned,
    required this.pointsEarned,
    required this.purchaseCpEarned,
    required this.cpBalance,
    required this.unlockDaysPerInvite,
    required this.pointsPerInvite,
    required this.inviteePointsPerRedeem,
    required this.inviteePurchaseDiscountPercent,
    required this.referrerPurchaseCpPercent,
  });

  final String code;
  final String link;
  final String referrerPhone;
  final int inviteCount;
  final int creditDaysEarned;
  final int pointsEarned;
  final int purchaseCpEarned;
  final int cpBalance;
  final int unlockDaysPerInvite;
  final int pointsPerInvite;
  final int inviteePointsPerRedeem;
  final int inviteePurchaseDiscountPercent;
  final int referrerPurchaseCpPercent;

  factory ReferralMe.fromJson(Map<String, dynamic> json) {
    final balance = (json['cpBalance'] as num?)?.toInt() ??
        (json['pointsBalance'] as num?)?.toInt() ??
        0;
    return ReferralMe(
      code: json['code'] as String? ?? '',
      link: json['link'] as String? ?? '',
      referrerPhone: json['referrerPhone'] as String? ?? '',
      inviteCount: (json['inviteCount'] as num?)?.toInt() ?? 0,
      creditDaysEarned: (json['creditDaysEarned'] as num?)?.toInt() ?? 0,
      pointsEarned: (json['pointsEarned'] as num?)?.toInt() ?? 0,
      purchaseCpEarned: (json['purchaseCpEarned'] as num?)?.toInt() ?? 0,
      cpBalance: balance,
      unlockDaysPerInvite: (json['unlockDaysPerInvite'] as num?)?.toInt() ?? 0,
      pointsPerInvite: (json['pointsPerInvite'] as num?)?.toInt() ?? 100,
      inviteePointsPerRedeem:
          (json['inviteePointsPerRedeem'] as num?)?.toInt() ?? 50,
      inviteePurchaseDiscountPercent:
          (json['inviteePurchaseDiscountPercent'] as num?)?.toInt() ??
              kInviteePurchaseDiscountPercent,
      referrerPurchaseCpPercent:
          (json['referrerPurchaseCpPercent'] as num?)?.toInt() ??
              kReferrerPurchaseCpPercent,
    );
  }
}

class ReferralRedeemResult {
  const ReferralRedeemResult({
    required this.ok,
    this.unlockDays = 0,
    this.inviteePoints = 0,
    this.referrerPoints = 0,
    this.purchaseDiscountPercent = 0,
    this.error,
  });

  final bool ok;
  final int unlockDays;
  final int inviteePoints;
  final int referrerPoints;
  final int purchaseDiscountPercent;
  final String? error;

  factory ReferralRedeemResult.fromJson(Map<String, dynamic> json) {
    return ReferralRedeemResult(
      ok: json['ok'] == true,
      unlockDays: (json['unlockDays'] as num?)?.toInt() ?? 0,
      inviteePoints: (json['inviteePoints'] as num?)?.toInt() ?? 0,
      referrerPoints: (json['referrerPoints'] as num?)?.toInt() ?? 0,
      purchaseDiscountPercent:
          (json['purchaseDiscountPercent'] as num?)?.toInt() ?? 0,
      error: json['error'] as String?,
    );
  }
}

class ReferralDiscountLookup {
  const ReferralDiscountLookup({
    required this.eligible,
    this.discountPercent = 0,
  });

  final bool eligible;
  final int discountPercent;
}

class ReferralPurchaseResult {
  const ReferralPurchaseResult({
    required this.ok,
    this.referrerCp = 0,
    this.error,
  });

  final bool ok;
  final int referrerCp;
  final String? error;
}

class ReferralApi {
  ReferralApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<ReferralMe?> fetchMe(String phoneE164) async {
    try {
      final uri = Uri.parse(
        '${referralApiBaseUrl()}/api/referrals/me',
      ).replace(queryParameters: {'phone': phoneE164});
      final response = await _client
          .get(uri, headers: await apiAuthHeaders(json: false))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return ReferralMe.fromJson(decoded);
    } catch (e, st) {
      debugPrint('ReferralApi.fetchMe failed: $e\n$st');
      return null;
    }
  }

  Future<ReferralRedeemResult> redeem({
    required String code,
    required String inviteePhone,
  }) async {
    try {
      final uri = Uri.parse('${referralApiBaseUrl()}/api/referrals/redeem');
      final response = await _client
          .post(
            uri,
            headers: await apiAuthHeaders(),
            body: jsonEncode({
              'code': code,
              'inviteePhone': inviteePhone,
            }),
          )
          .timeout(const Duration(seconds: 4));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return ReferralRedeemResult.fromJson(decoded);
    } catch (e, st) {
      debugPrint('ReferralApi.redeem failed: $e\n$st');
      return const ReferralRedeemResult(ok: false, error: 'network');
    }
  }

  Future<ReferralDiscountLookup> fetchDiscount(String phoneE164) async {
    try {
      final uri = Uri.parse(
        '${referralApiBaseUrl()}/api/referrals/discount',
      ).replace(queryParameters: {'phone': phoneE164});
      final response = await _client
          .get(uri, headers: await apiAuthHeaders(json: false))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) {
        return const ReferralDiscountLookup(eligible: false);
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return ReferralDiscountLookup(
        eligible: decoded['eligible'] == true,
        discountPercent: (decoded['discountPercent'] as num?)?.toInt() ?? 0,
      );
    } catch (e, st) {
      debugPrint('ReferralApi.fetchDiscount failed: $e\n$st');
      return const ReferralDiscountLookup(eligible: false);
    }
  }

  Future<ReferralPurchaseResult> recordPurchase({
    required String inviteePhone,
    required int amountEtb,
  }) async {
    try {
      final uri = Uri.parse('${referralApiBaseUrl()}/api/referrals/purchase');
      final response = await _client
          .post(
            uri,
            headers: await apiAuthHeaders(),
            body: jsonEncode({
              'inviteePhone': inviteePhone,
              'amountEtb': amountEtb,
            }),
          )
          .timeout(const Duration(seconds: 4));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return ReferralPurchaseResult(
        ok: decoded['ok'] == true,
        referrerCp: (decoded['referrerCp'] as num?)?.toInt() ?? 0,
        error: decoded['error'] as String?,
      );
    } catch (e, st) {
      debugPrint('ReferralApi.recordPurchase failed: $e\n$st');
      return const ReferralPurchaseResult(ok: false, error: 'network');
    }
  }
}

/// Applies invitee referral discount to a subscription total (ETB).
int applyReferralPurchaseDiscount(int amountEtb, int discountPercent) {
  if (discountPercent <= 0 || amountEtb <= 0) return amountEtb;
  return ((amountEtb * (100 - discountPercent)) / 100).round();
}

/// Referrer CP commission from an invitee purchase amount (ETB → CP 1:1).
int referrerCpFromPurchase(int amountEtb, int percent) {
  if (percent <= 0 || amountEtb <= 0) return 0;
  return ((amountEtb * percent) / 100).round();
}
