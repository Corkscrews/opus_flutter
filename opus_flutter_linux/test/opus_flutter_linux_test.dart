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
  });
}
