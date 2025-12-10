import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAMEqonrFeWjQsn0nBBbjRLgaVeY6-N9g0',
    appId: '1:763109943495:web:893100513b9c5ef1f9f6e2',
    messagingSenderId: '763109943495',
    projectId: 'x-multiplayer',
    authDomain: 'x-multiplayer.firebaseapp.com',
    databaseURL: 'https://x-multiplayer-default-rtdb.firebaseio.com',
    storageBucket: 'x-multiplayer.firebasestorage.app',
    measurementId: 'G-7PP1XZ6GJS',
  );

  // Android uses google-services.json, but we provide fallback
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAMEqonrFeWjQsn0nBBbjRLgaVeY6-N9g0',
    appId: '1:763109943495:web:893100513b9c5ef1f9f6e2',
    messagingSenderId: '763109943495',
    projectId: 'x-multiplayer',
    databaseURL: 'https://x-multiplayer-default-rtdb.firebaseio.com',
    storageBucket: 'x-multiplayer.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAMEqonrFeWjQsn0nBBbjRLgaVeY6-N9g0',
    appId: '1:763109943495:web:893100513b9c5ef1f9f6e2',
    messagingSenderId: '763109943495',
    projectId: 'x-multiplayer',
    databaseURL: 'https://x-multiplayer-default-rtdb.firebaseio.com',
    storageBucket: 'x-multiplayer.firebasestorage.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAMEqonrFeWjQsn0nBBbjRLgaVeY6-N9g0',
    appId: '1:763109943495:web:893100513b9c5ef1f9f6e2',
    messagingSenderId: '763109943495',
    projectId: 'x-multiplayer',
    databaseURL: 'https://x-multiplayer-default-rtdb.firebaseio.com',
    storageBucket: 'x-multiplayer.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAMEqonrFeWjQsn0nBBbjRLgaVeY6-N9g0',
    appId: '1:763109943495:web:893100513b9c5ef1f9f6e2',
    messagingSenderId: '763109943495',
    projectId: 'x-multiplayer',
    databaseURL: 'https://x-multiplayer-default-rtdb.firebaseio.com',
    storageBucket: 'x-multiplayer.firebasestorage.app',
  );
}

