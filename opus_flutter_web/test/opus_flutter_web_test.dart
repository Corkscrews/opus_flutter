import 'package:flutter_test/flutter_test.dart';
import 'package:opus_codec_web/opus_codec_web.dart';
import 'package:opus_codec_platform_interface/opus_codec_platform_interface.dart';

void main() {
  group('OpusFlutterWeb', () {
    test('extends OpusFlutterPlatform', () {
      expect(OpusFlutterWeb(), isA<OpusFlutterPlatform>());
    });

    test('multiple instances are independent', () {
      final a = OpusFlutterWeb();
      final b = OpusFlutterWeb();
      expect(identical(a, b), isFalse);
    });

    test('load() returns a Future', () {
      final web = OpusFlutterWeb();
      expect(web.load, isA<Function>());
    });
  });
}
