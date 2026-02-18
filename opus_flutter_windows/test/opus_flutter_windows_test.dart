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
  });
}
