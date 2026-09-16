import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/app_remote_config.dart';

Future<bool> _launchExternal(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

/// Opens Chkela Telegram support using live admin config when available.
Future<bool> openTelegramSupport({AppRemoteConfig? config}) async {
  final cfg = config ?? await AppRemoteConfigStore.loadCachedOrDefaults();
  final deepLink = Uri.parse(cfg.telegramDeepLink);
  if (await _launchExternal(deepLink)) return true;
  return _launchExternal(Uri.parse(cfg.telegramUrl));
}

Future<void> copyTelegramSupportLink({AppRemoteConfig? config}) async {
  final cfg = config ?? await AppRemoteConfigStore.loadCachedOrDefaults();
  await Clipboard.setData(ClipboardData(text: cfg.telegramHandle));
}
