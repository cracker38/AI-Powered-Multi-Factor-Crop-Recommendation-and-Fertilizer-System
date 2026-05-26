// Generated from android/app/google-services.json (project: edissaproject)
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      case TargetPlatform.macOS:
        return macos;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAhqYyWDFv1jeG5NDRDURo9IZV44JQFx9s',
    appId: '1:589495549005:android:a720fb125c573f454ff004',
    messagingSenderId: '589495549005',
    projectId: 'edissaproject',
    storageBucket: 'edissaproject.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAhqYyWDFv1jeG5NDRDURo9IZV44JQFx9s',
    appId: '1:589495549005:android:a720fb125c573f454ff004',
    messagingSenderId: '589495549005',
    projectId: 'edissaproject',
    storageBucket: 'edissaproject.firebasestorage.app',
    iosBundleId: 'com.example.cropsRecommendation',
  );

  static const FirebaseOptions macos = ios;

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAhqYyWDFv1jeG5NDRDURo9IZV44JQFx9s',
    appId: '1:589495549005:android:a720fb125c573f454ff004',
    messagingSenderId: '589495549005',
    projectId: 'edissaproject',
    storageBucket: 'edissaproject.firebasestorage.app',
    authDomain: 'edissaproject.firebaseapp.com',
  );
}
