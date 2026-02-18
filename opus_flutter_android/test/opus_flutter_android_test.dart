import 'package:flutter_test/flutter_test.dart';
import 'package:opus_flutter_android/opus_flutter_android.dart';
import 'package:opus_flutter_platform_interface/opus_flutter_platform_interface.dart';

void main() {
  group('OpusFlutterAndroid', () {
    test('extends OpusFlutterPlatform', () {
      expect(OpusFlutterAndroid(), isA<OpusFlutterPlatform>());
    });

    test('registerWith sets platform instance', () {
      OpusFlutterAndroid.registerWith();
      expect(OpusFlutterPlatform.instance, isA<OpusFlutterAndroid>());
    });

    test('registerWith is idempotent', () {
      OpusFlutterAndroid.registerWith();
      final first = OpusFlutterPlatform.instance;
      OpusFlutterAndroid.registerWith();
      expect(OpusFlutterPlatform.instance, isA<OpusFlutterAndroid>());
      expect(
        identical(OpusFlutterPlatform.instance, first),
        isFalse,
        reason: 'registerWith creates a new instance each time',
      );
    });
  });
}
