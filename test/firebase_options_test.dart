import 'package:flutter_test/flutter_test.dart';
import 'package:scssrs/firebase_options.dart';

void main() {
  test('Android Firebase options use the Android app id, not the web one', () {
    expect(DefaultFirebaseOptions.android.appId, contains(':android:'));
    expect(DefaultFirebaseOptions.android.appId, isNot(contains(':web:')));
    expect(
      DefaultFirebaseOptions.android.appId,
      '1:763109943495:android:7ee914140c4e6624f9f6e2',
    );
  });
}
