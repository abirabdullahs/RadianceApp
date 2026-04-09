// Replace with values from FlutterFire CLI (`dart pub global run flutterfire_cli:flutterfire configure`).
// This file allows the project to compile before you connect a real Firebase project.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions are not configured for web — run flutterfire configure.',
      );
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

  /// Values must match [android/app/google-services.json] (same Firebase Android app).
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC5e9DFCeRHU1cOLg87caagVCa6uuw943o',
    appId: '1:595891837980:android:5d3b448718136943a9d3d9',
    messagingSenderId: '595891837980',
    projectId: 'radiancebdapp',
    storageBucket: 'radiancebdapp.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDummy0000000000000000000000000',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'radiance-placeholder',
    storageBucket: 'radiance-placeholder.appspot.com',
    iosBundleId: 'com.example.radiance',
  );
}
