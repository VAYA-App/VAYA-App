import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Generated for project: vaya-app26
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCM1VpaSJec9N8OFmjmvVm3_0us057y8ls',
    appId: '1:694490566732:android:8cb8b1bdcdfae53465a4e9',
    messagingSenderId: '694490566732',
    projectId: 'vaya-app26',
    storageBucket: 'vaya-app26.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCM1VpaSJec9N8OFmjmvVm3_0us057y8ls',
    appId: '1:694490566732:web:placeholder',
    messagingSenderId: '694490566732',
    projectId: 'vaya-app26',
    storageBucket: 'vaya-app26.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCM1VpaSJec9N8OFmjmvVm3_0us057y8ls',
    appId: '1:694490566732:ios:placeholder',
    messagingSenderId: '694490566732',
    projectId: 'vaya-app26',
    storageBucket: 'vaya-app26.firebasestorage.app',
    iosBundleId: 'com.vaya.vayaApp',
  );
}
