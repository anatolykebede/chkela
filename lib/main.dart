import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/notifications/push_notification_service.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Keep the native black launch frame up until SplashScreen is ready to
  // show the first video frame (avoids a blank gap after process start).
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await PushNotificationService.instance.init();

  runApp(
    const ProviderScope(
      child: ChkelaApp(),
    ),
  );
}
