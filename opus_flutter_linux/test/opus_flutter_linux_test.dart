import 'package:flutter_test/flutter_test.dart';
import 'package:opus_flutter_linux/opus_flutter_linux.dart';
import 'package:opus_flutter_platform_interface/opus_flutter_platform_interface.dart';

void main() {
  group('OpusFlutterLinux', () {
    test('extends OpusFlutterPlatform', () {
      expect(OpusFlutterLinux(), isA<OpusFlutterPlatform>());
    });

    test('registerWith sets platform instance', () {
      OpusFlutterLinux.registerWith();
      expect(OpusFlutterPlatform.instance, isA<OpusFlutterLinux>());
    });

    test('registerWith creates a new instance each time', () {
      OpusFlutterLinux.registerWith();
      final first = OpusFlutterPlatform.instance;
      OpusFlutterLinux.registerWith();
      expect(OpusFlutterPlatform.instance, isA<OpusFlutterLinux>());
      expect(identical(OpusFlutterPlatform.instance, first), isFalse);
    });

    test('multiple instances are independent', () {
      final a = OpusFlutterLinux();
      final b = OpusFlutterLinux();
      expect(identical(a, b), isFalse);
    });

    test('load() returns a Future', () {
      final linux = OpusFlutterLinux();
      expect(linux.load, isA<Function>());
    });
  });
}
