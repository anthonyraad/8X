import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'ui/game_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Do not block the first frame on Firebase. A hang or throw here leaves the
  // Android splash up (white/black) and looks like the app never opens.
  runApp(const MyApp());
  unawaited(_initFirebaseInBackground());
}

Future<void> _initFirebaseInBackground() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 8));
    }
    await FirebaseAuth.instance
        .signInAnonymously()
        .timeout(const Duration(seconds: 8));
  } catch (e, st) {
    debugPrint('Firebase startup failed (AI / local play still works): $e\n$st');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '8X',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const GameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}