import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Values from published chkela101 Firebase project `chkela-25bd7`.
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  /// True when a real Firebase project id is present.
  static bool get isConfigured {
    final id = currentPlatform.projectId.trim();
    return id.isNotEmpty && id != 'YOUR_PROJECT_ID';
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_WEB_API_KEY',
    appId: 'YOUR_WEB_APP_ID',
    messagingSenderId: '658601426723',
    projectId: 'chkela-25bd7',
    authDomain: 'chkela-25bd7.firebaseapp.com',
    storageBucket: 'chkela-25bd7.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDkX7bXGPs75UXLAq8QVoRRcsRyBlFynNo',
    appId: '1:658601426723:android:3662640ae71bea30e9d696',
    messagingSenderId: '658601426723',
    projectId: 'chkela-25bd7',
    storageBucket: 'chkela-25bd7.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB5xFDaIVQAqqp50fvOU1bVrH82lL4hcGk',
    appId: '1:658601426723:ios:d97ecc67e49b984fe9d696',
    messagingSenderId: '658601426723',
    projectId: 'chkela-25bd7',
    storageBucket: 'chkela-25bd7.firebasestorage.app',
    iosBundleId: 'com.lolearn.chkela',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyB5xFDaIVQAqqp50fvOU1bVrH82lL4hcGk',
    appId: '1:658601426723:ios:d97ecc67e49b984fe9d696',
    messagingSenderId: '658601426723',
    projectId: 'chkela-25bd7',
    storageBucket: 'chkela-25bd7.firebasestorage.app',
    iosBundleId: 'com.lolearn.chkela',
  );
}
