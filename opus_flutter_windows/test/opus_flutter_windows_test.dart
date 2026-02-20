import 'package:flutter_test/flutter_test.dart';
import 'package:opus_flutter_windows/opus_flutter_windows.dart';
import 'package:opus_flutter_platform_interface/opus_flutter_platform_interface.dart';

void main() {
  group('OpusFlutterWindows', () {
    test('extends OpusFlutterPlatform', () {
      expect(OpusFlutterWindows(), isA<OpusFlutterPlatform>());
    });

    test('registerWith sets platform instance', () {
      OpusFlutterWindows.registerWith();
      expect(OpusFlutterPlatform.instance, isA<OpusFlutterWindows>());
    });

    test('registerWith creates a new instance each time', () {
      OpusFlutterWindows.registerWith();
      final first = OpusFlutterPlatform.instance;
      OpusFlutterWindows.registerWith();
      expect(OpusFlutterPlatform.instance, isA<OpusFlutterWindows>());
      expect(identical(OpusFlutterPlatform.instance, first), isFalse);
    });

    test('multiple instances are independent', () {
      final a = OpusFlutterWindows();
      final b = OpusFlutterWindows();
      expect(identical(a, b), isFalse);
    });

    test('load() returns a Future', () {
      final windows = OpusFlutterWindows();
      expect(windows.load, isA<Function>());
    });
  });
}
