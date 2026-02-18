import 'package:flutter_test/flutter_test.dart';
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;
import 'package:opus_flutter_platform_interface/opus_flutter_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockOpusFlutterPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements OpusFlutterPlatform {
  bool loadCalled = false;
  final Object _result = Object();

  @override
  Future<Object> load() async {
    loadCalled = true;
    return _result;
  }
}

void main() {
  group('opus_flutter', () {
    test('load() delegates to OpusFlutterPlatform.instance', () async {
      final mock = MockOpusFlutterPlatform();
      OpusFlutterPlatform.instance = mock;

      final result = await opus_flutter.load();

      expect(mock.loadCalled, isTrue);
      expect(result, mock._result);
    });

    test('load() throws when platform is unsupported', () {
      OpusFlutterPlatform.instance = OpusFlutterPlatformUnsupported();
      expect(opus_flutter.load, throwsUnsupportedError);
    });
  });
}
