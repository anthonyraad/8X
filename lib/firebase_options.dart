import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase options for 8X multiplayer (x-multiplayer project).
///
/// The web API key is baked in (normal for Firebase client apps). Restrict it in
/// Google Cloud (HTTP referrers) and rely on Auth + RTDB rules.
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

  // From the last tracked android/app/google-services.json for
  // com.raadscapes.scssrs (removed from git in 4690ad8). Do not reuse the
  // web appId/apiKey here — that makes Android Firebase.initializeApp fail.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDcWK7ZZWziGfMBu9j5IQMxVEgi6jR5mck',
    appId: '1:763109943495:android:7ee914140c4e6624f9f6e2',
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
