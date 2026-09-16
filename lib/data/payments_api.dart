import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_auth_headers.dart';
import 'content/content_api.dart';
import 'subscription_data.dart';

String paymentsApiBaseUrl() => contentApiBaseUrl();

class PaymentSubmitResult {
  const PaymentSubmitResult({
    required this.id,
    required this.status,
  });

  final String id;
  final String status;
}

class SubscriptionMeStatus {
  const SubscriptionMeStatus({
    required this.paid,
    this.grades = const [],
    this.plan,
    this.latestPaymentStatus,
  });

  final bool paid;
  final List<String> grades;
  final String? plan;
  final String? latestPaymentStatus;
}

class PaymentsApi {
  PaymentsApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<PaymentSubmitResult> submitPayment({
    required SubscriptionPaymentMethod method,
    required int amountEtb,
    required String plan,
    required List<String> grades,
    required BillingPeriod billingPeriod,
    String? displayName,
    String? reference,
    File? receiptFile,
  }) async {
    String? receiptBase64;
    String? receiptMime;
    if (receiptFile != null) {
      final bytes = await receiptFile.readAsBytes();
      if (bytes.length > 4 * 1024 * 1024) {
        throw PaymentsApiException('Receipt is too large (max 4MB)');
      }
      receiptBase64 = base64Encode(bytes);
      final lower = receiptFile.path.toLowerCase();
      receiptMime = lower.endsWith('.png') ? 'image/png' : 'image/jpeg';
    }

    final uri = Uri.parse('${paymentsApiBaseUrl()}/api/payments');
    final response = await _client
        .post(
          uri,
          headers: await apiAuthHeaders(),
          body: jsonEncode({
            'method': method.label,
            'amount': amountEtb,
            'plan': plan,
            'grades': grades,
            'billingPeriod': billingPeriod.name,
            if (displayName != null && displayName.trim().isNotEmpty)
              'displayName': displayName.trim(),
            if (reference != null && reference.trim().isNotEmpty)
              'reference': reference.trim(),
            if (receiptBase64 != null) 'receiptBase64': receiptBase64,
            if (receiptMime != null) 'receiptMime': receiptMime,
          }),
        )
        .timeout(const Duration(seconds: 45));

    final body = _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payment = body['payment'];
      if (payment is Map) {
        return PaymentSubmitResult(
          id: payment['id']?.toString() ?? '',
          status: payment['status']?.toString() ?? 'pending',
        );
      }
      if (body['ok'] == true) {
        return const PaymentSubmitResult(id: '', status: 'pending');
      }
    }
    throw PaymentsApiException(
      body['message']?.toString() ??
          body['error']?.toString() ??
          'Could not submit payment',
    );
  }

  Future<SubscriptionMeStatus> fetchMySubscription() async {
    final uri = Uri.parse('${paymentsApiBaseUrl()}/api/subscriptions/me');
    final response = await _client
        .get(uri, headers: await apiAuthHeaders(json: false))
        .timeout(const Duration(seconds: 12));
    final body = _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final latest = body['latestPayment'];
      String? latestStatus;
      if (latest is Map) {
        latestStatus = latest['status']?.toString();
      }
      final gradesRaw = body['grades'];
      final grades = <String>[];
      if (gradesRaw is List) {
        for (final item in gradesRaw) {
          if (item == null) continue;
          final text = item.toString().trim();
          if (text.isNotEmpty) grades.add(text);
        }
      }
      final sub = body['subscription'];
      if (grades.isEmpty && sub is Map && sub['grades'] is List) {
        for (final item in sub['grades'] as List) {
          if (item == null) continue;
          final text = item.toString().trim();
          if (text.isNotEmpty) grades.add(text);
        }
      }
      final plan = body['plan']?.toString() ??
          (sub is Map ? sub['plan']?.toString() : null);
      return SubscriptionMeStatus(
        paid: body['paid'] == true,
        grades: grades,
        plan: plan,
        latestPaymentStatus: latestStatus,
      );
    }
    throw PaymentsApiException(
      body['message']?.toString() ??
          body['error']?.toString() ??
          'Could not load subscription',
    );
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
}

class PaymentsApiException implements Exception {
  PaymentsApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
