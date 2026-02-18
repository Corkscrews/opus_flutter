import 'package:flutter_test/flutter_test.dart';
import 'package:opus_flutter_web/opus_flutter_web.dart';
import 'package:opus_flutter_platform_interface/opus_flutter_platform_interface.dart';

void main() {
  group('OpusFlutterWeb', () {
    test('extends OpusFlutterPlatform', () {
      expect(OpusFlutterWeb(), isA<OpusFlutterPlatform>());
    });
  });
}
