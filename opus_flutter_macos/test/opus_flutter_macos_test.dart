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
  });
}
