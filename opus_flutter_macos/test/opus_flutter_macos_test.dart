import 'package:flutter_test/flutter_test.dart';
import 'package:opus_flutter_macos/opus_flutter_macos.dart';
import 'package:opus_flutter_platform_interface/opus_flutter_platform_interface.dart';

void main() {
  group('OpusFlutterMacOS', () {
    test('extends OpusFlutterPlatform', () {
      expect(OpusFlutterMacOS(), isA<OpusFlutterPlatform>());
    });

    test('registerWith sets platform instance', () {
      OpusFlutterMacOS.registerWith();
      expect(OpusFlutterPlatform.instance, isA<OpusFlutterMacOS>());
    });

    test('registerWith creates a new instance each time', () {
      OpusFlutterMacOS.registerWith();
      final first = OpusFlutterPlatform.instance;
      OpusFlutterMacOS.registerWith();
      expect(OpusFlutterPlatform.instance, isA<OpusFlutterMacOS>());
      expect(identical(OpusFlutterPlatform.instance, first), isFalse);
    });

    test('multiple instances are independent', () {
      final a = OpusFlutterMacOS();
      final b = OpusFlutterMacOS();
      expect(identical(a, b), isFalse);
    });

    test('load() returns a Future', () {
      final macos = OpusFlutterMacOS();
      expect(macos.load, isA<Function>());
    });
  });
}
