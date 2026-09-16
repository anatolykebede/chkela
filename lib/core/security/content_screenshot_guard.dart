import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Blocks screenshots / screen recording on study content screens.
///
/// Android: [FLAG_SECURE].
/// iOS: skipped for now. Apple has no stable API for this; the common
/// secure-layer workaround crashes Flutter in this app.
class ContentScreenshotGuard {
  ContentScreenshotGuard._();

  static const _channel = MethodChannel('com.chkela/content_security');
  static int _depth = 0;

  static Future<void> enable() async {
    if (kIsWeb || !Platform.isAndroid) return;

    _depth += 1;
    if (_depth > 1) return;
    try {
      await _channel.invokeMethod<void>('enable');
    } catch (e) {
      debugPrint('ContentScreenshotGuard.enable failed: $e');
    }
  }

  static Future<void> disable() async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (_depth == 0) return;
    _depth -= 1;
    if (_depth > 0) return;
    try {
      await _channel.invokeMethod<void>('disable');
    } catch (e) {
      debugPrint('ContentScreenshotGuard.disable failed: $e');
    }
  }
}
