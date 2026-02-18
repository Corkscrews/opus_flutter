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
  });
}
