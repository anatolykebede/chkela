import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../../data/api_auth_headers.dart';
import '../../data/content/content_api.dart';
import '../../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty && DefaultFirebaseOptions.isConfigured) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
}

/// FCM bootstrap + token sync to the Chkela dashboard API.
class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  static const paymentApprovedType = 'payment_approved';

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();
  final _paymentApprovedController =
      StreamController<RemoteMessage>.broadcast();

  bool _ready = false;
  String? _lastPhone;
  bool _refreshBound = false;
  bool _handlersBound = false;

  bool get isReady => _ready;

  /// Fires when a payment-approved push arrives (foreground) or is opened.
  Stream<RemoteMessage> get onPaymentApproved =>
      _paymentApprovedController.stream;

  Future<void> init() async {
    if (kIsWeb) {
      debugPrint('Push: skipped on web for this pass');
      return;
    }
    if (!DefaultFirebaseOptions.isConfigured) {
      debugPrint(
        'Push: Firebase not configured yet. '
        'Run flutterfire configure or fill lib/firebase_options.dart',
      );
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await _setupLocalNotifications();
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (!_handlersBound) {
        _handlersBound = true;
        FirebaseMessaging.onMessage.listen(_onForegroundMessage);
        FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
      }

      _ready = true;
      debugPrint('Push: Firebase messaging ready');

      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        // Defer until UI is up.
        scheduleMicrotask(() => _onMessageOpened(initial));
      }
    } catch (e, st) {
      debugPrint('Push: init failed: $e\n$st');
      _ready = false;
    }
  }

  Future<void> syncTokenForPhone(String? phoneE164) async {
    if (!_ready || phoneE164 == null || phoneE164.isEmpty) return;
    _lastPhone = phoneE164;
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      await _register(token, phoneE164);
      if (!_refreshBound) {
        _refreshBound = true;
        _messaging.onTokenRefresh.listen((next) {
          final phone = _lastPhone;
          if (phone != null) {
            _register(next, phone);
          }
        });
      }
    } catch (e, st) {
      debugPrint('Push: token sync failed: $e\n$st');
    }
  }

  bool isPaymentApprovedMessage(RemoteMessage message) {
    final type = message.data['type']?.toString();
    return type == paymentApprovedType;
  }

  Future<void> _register(String token, String phone) async {
    try {
      final uri = Uri.parse('${contentApiBaseUrl()}/api/notifications/register');
      final platform = switch (defaultTargetPlatform) {
        TargetPlatform.iOS => 'ios',
        TargetPlatform.android => 'android',
        _ => 'other',
      };
      await http
          .post(
            uri,
            headers: await apiAuthHeaders(),
            body: jsonEncode({
              'token': token,
              'phone': phone,
              'platform': platform,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e, st) {
      debugPrint('Push: register API failed: $e\n$st');
    }
  }

  Future<void> _setupLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _local.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == paymentApprovedType) {
          _paymentApprovedController.add(
            const RemoteMessage(data: {'type': paymentApprovedType}),
          );
        }
      },
    );

    const channel = AndroidNotificationChannel(
      'chkela_default',
      'Chkela',
      description: 'General Chkela notifications',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    if (isPaymentApprovedMessage(message)) {
      _paymentApprovedController.add(message);
      return;
    }
    await _showLocalBanner(message);
  }

  void _onMessageOpened(RemoteMessage message) {
    if (isPaymentApprovedMessage(message)) {
      _paymentApprovedController.add(message);
    }
  }

  Future<void> _showLocalBanner(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _local.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'chkela_default',
          'Chkela',
          channelDescription: 'General Chkela notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data['type']?.toString(),
    );
  }
}
