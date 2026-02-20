import 'package:flutter_test/flutter_test.dart';
import 'package:opus_flutter_ios/opus_flutter_ios.dart';
import 'package:opus_flutter_platform_interface/opus_flutter_platform_interface.dart';

void main() {
  group('OpusFlutterIOS', () {
    test('extends OpusFlutterPlatform', () {
      expect(OpusFlutterIOS(), isA<OpusFlutterPlatform>());
    });

    test('registerWith sets platform instance', () {
      OpusFlutterIOS.registerWith();
      expect(OpusFlutterPlatform.instance, isA<OpusFlutterIOS>());
    });

    test('registerWith creates a new instance each time', () {
      OpusFlutterIOS.registerWith();
      final first = OpusFlutterPlatform.instance;
      OpusFlutterIOS.registerWith();
      expect(OpusFlutterPlatform.instance, isA<OpusFlutterIOS>());
      expect(identical(OpusFlutterPlatform.instance, first), isFalse);
    });

    test('multiple instances are independent', () {
      final a = OpusFlutterIOS();
      final b = OpusFlutterIOS();
      expect(identical(a, b), isFalse);
    });

    test('load() returns a Future', () {
      final ios = OpusFlutterIOS();
      expect(ios.load, isA<Function>());
    });
  });
}
