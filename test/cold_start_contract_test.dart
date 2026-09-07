import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Encodes the Play "doesn't open or load" mechanism without a device:
/// awaiting a hanging/throwing Firebase call *before* [runApp] means no frame.
void main() {
  testWidgets(
    'BROKEN launch path: hang before runApp never draws a Flutter frame',
    (tester) async {
      final auth = Completer<void>();

      unawaited(() async {
        await auth.future; // signInAnonymously hang
        runApp(const MaterialApp(home: Text('MENU')));
      }());

      await tester.pump(const Duration(seconds: 3));
      expect(find.text('MENU'), findsNothing,
          reason: 'No runApp => splash stays up (Play loading rejection).');
    },
  );

  testWidgets(
    'BROKEN launch path: throw before runApp never draws a Flutter frame',
    (tester) async {
      Object? error;
      await runZonedGuarded(() async {
        try {
          await Future<void>.error(StateError('FirebaseAuth failed'));
          runApp(const MaterialApp(home: Text('MENU')));
        } catch (e) {
          error = e;
        }
      }, (e, _) {});

      await tester.pump();
      expect(error, isA<StateError>());
      expect(find.text('MENU'), findsNothing);
    },
  );

  testWidgets(
    'FIXED launch path: UI appears even when auth hangs or throws',
    (tester) async {
      runApp(const MaterialApp(home: Scaffold(body: Text('MENU'))));
      unawaited(Future<void>.error(StateError('FirebaseAuth failed'))
          .timeout(const Duration(milliseconds: 10))
          .catchError((_) {}));

      await tester.pumpAndSettle();
      expect(find.text('MENU'), findsOneWidget);
    },
  );
}
