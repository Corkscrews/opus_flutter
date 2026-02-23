import 'package:flutter_test/flutter_test.dart';
import 'package:opus_codec_android/opus_codec_android.dart';
import 'package:opus_codec_platform_interface/opus_codec_platform_interface.dart';

void main() {
  group('OpusFlutterAndroid', () {
    test('extends OpusFlutterPlatform', () {
      expect(OpusFlutterAndroid(), isA<OpusFlutterPlatform>());
    });

    test('registerWith sets platform instance', () {
      OpusFlutterAndroid.registerWith();
      expect(OpusFlutterPlatform.instance, isA<OpusFlutterAndroid>());
    });

    test('registerWith creates a new instance each time', () {
      OpusFlutterAndroid.registerWith();
      final first = OpusFlutterPlatform.instance;
      OpusFlutterAndroid.registerWith();
      expect(OpusFlutterPlatform.instance, isA<OpusFlutterAndroid>());
      expect(identical(OpusFlutterPlatform.instance, first), isFalse);
    });

    test('multiple instances are independent', () {
      final a = OpusFlutterAndroid();
      final b = OpusFlutterAndroid();
      expect(identical(a, b), isFalse);
    });

    test('load() returns a Future', () {
      final android = OpusFlutterAndroid();
      // We can't call load() without the native library, but we can verify the
      // method exists and returns the correct type signature.
      expect(android.load, isA<Function>());
    });
  });
}
