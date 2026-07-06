# Firebase Setup

The Firebase API key is not stored in the repository to avoid exposure in public source code.

## Local Development

Create `lib/firebase_options.dart` using one of these methods:

1. **Recommended:** Run `flutterfire configure` (requires [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/))
2. **Manual:** Copy `lib/firebase_options.dart.example` to `lib/firebase_options.dart` and replace the placeholder values with your Firebase project config from the [Firebase Console](https://console.firebase.google.com/)

## GitHub Actions (Web Deploy)

1. Go to your repo **Settings** → **Secrets and variables** → **Actions**
2. Add a new secret: **FIREBASE_OPTIONS_DART**
3. Value: The full contents of your `lib/firebase_options.dart` file (copy the entire file)

The deploy workflow will inject this before building the web app.

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
