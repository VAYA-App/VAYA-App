import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Generated for project: vaya-app26
class DefaultFirebaseOptions {
  /// Only Android is registered in Firebase so far. Web and iOS throw, so
  /// `main.dart` skips Firebase there and the app keeps the mock sign-in
  /// instead of starting Firebase with an app id that does not exist.
  static FirebaseOptions get currentPlatform {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError(
        'DefaultFirebaseOptions are not supported for this platform.',
      );
    }
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCM1VpaSJec9N8OFmjmvVm3_0us057y8ls',
    appId: '1:694490566732:android:8cb8b1bdcdfae53465a4e9',
    messagingSenderId: '694490566732',
    projectId: 'vaya-app26',
    storageBucket: 'vaya-app26.firebasestorage.app',
  );
}
