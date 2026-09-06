# Firebase Setup

`lib/firebase_options.dart` is committed. Firebase web API keys are client-side by design (they ship in the compiled JS). Restrict the key in Google Cloud (HTTP referrers for `anthonyraad.github.io`) and rely on Auth + Realtime Database rules.

Native files `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist` stay gitignored. Android client values for `com.raadscapes.scssrs` live in `lib/firebase_options.dart` (`:android:` app id + Android API key) so release AABs can initialize without relying on a local json file at runtime.

## Local Development

If you need to regenerate options:

1. **Recommended:** Run `flutterfire configure` (requires [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/))
2. **Manual:** Copy `lib/firebase_options.dart.example` and fill in values from the [Firebase Console](https://console.firebase.google.com/)

## GitHub Pages

The deploy workflow builds with `--base-href="/8X/"` and publishes `build/web`. No Actions secret is required for Firebase.

## Arcade Leaderboard (Realtime Database)

The arcade leaderboard uses Firebase Realtime Database. Add an index on `score` for the `arcadeLeaderboard` node so queries work correctly. In Firebase Console → Realtime Database → Rules, ensure your rules allow read/write for authenticated users (or your security model), and add:

```json
{
  "rules": {
    "arcadeLeaderboard": {
      ".indexOn": ["score"]
    }
  }
}
```

Or add the index via Firebase Console → Realtime Database → Indexes.
