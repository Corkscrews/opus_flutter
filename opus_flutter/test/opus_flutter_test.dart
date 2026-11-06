import 'package:flutter_test/flutter_test.dart';
import 'package:opus_codec/opus_codec.dart' as opus_flutter;
import 'package:opus_codec_platform_interface/opus_codec_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockOpusFlutterPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements OpusFlutterPlatform {
  int loadCallCount = 0;

  @override
  Future<Object> load() async {
    loadCallCount++;
    return Object();
  }
}

void main() {
  group('initializeOpus()', () {
    // The test VM is not the web, so these exercise the native path.
    test('does not consult the platform plugin on native', () async {
      final mock = MockOpusFlutterPlatform();
      OpusFlutterPlatform.instance = mock;

      await opus_flutter.initializeOpus();

      expect(mock.loadCallCount, 0);
    });

    test('can be called more than once', () async {
      await opus_flutter.initializeOpus();
      await opus_flutter.initializeOpus();
    });
  });
}
