import 'package:flutter_test/flutter_test.dart';
import 'package:opus_flutter_platform_interface/opus_flutter_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockOpusFlutterPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements OpusFlutterPlatform {
  bool loadCalled = false;

  @override
  Future<Object> load() async {
    loadCalled = true;
    return Object();
  }
}

class ExtendsOpusFlutterPlatform extends OpusFlutterPlatform {}

void main() {
  group('OpusFlutterPlatform', () {
    test('default instance is OpusFlutterPlatformUnsupported', () {
      expect(
        OpusFlutterPlatform.instance,
        isA<OpusFlutterPlatformUnsupported>(),
      );
    });

    test('can set instance with a valid mock', () {
      final mock = MockOpusFlutterPlatform();
      OpusFlutterPlatform.instance = mock;
      expect(OpusFlutterPlatform.instance, mock);
    });

    test('can set instance with a class that extends OpusFlutterPlatform', () {
      final impl = ExtendsOpusFlutterPlatform();
      OpusFlutterPlatform.instance = impl;
      expect(OpusFlutterPlatform.instance, impl);
    });

    test('base class load() throws UnimplementedError', () {
      final base = ExtendsOpusFlutterPlatform();
      expect(base.load, throwsUnimplementedError);
    });

    test('opusVersion is 1.5.2', () {
      expect(OpusFlutterPlatform.opusVersion, '1.5.2');
    });
  });

  group('OpusFlutterPlatformUnsupported', () {
    test('load() throws UnsupportedError', () {
      final unsupported = OpusFlutterPlatformUnsupported();
      expect(unsupported.load, throwsUnsupportedError);
    });
  });
}
