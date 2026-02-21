import 'package:flutter_test/flutter_test.dart';
import 'package:opus_flutter_platform_interface/opus_flutter_platform_interface.dart';
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

class ExtendsOpusFlutterPlatform extends OpusFlutterPlatform {}

class FailingPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements OpusFlutterPlatform {
  @override
  Future<Object> load() async {
    throw StateError('load failed');
  }
}

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

    test('setting instance replaces the previous one', () {
      final first = MockOpusFlutterPlatform();
      final second = MockOpusFlutterPlatform();

      OpusFlutterPlatform.instance = first;
      expect(OpusFlutterPlatform.instance, first);

      OpusFlutterPlatform.instance = second;
      expect(OpusFlutterPlatform.instance, second);
      expect(OpusFlutterPlatform.instance, isNot(first));
    });

    test('base class load() throws UnimplementedError', () {
      final base = ExtendsOpusFlutterPlatform();
      expect(base.load, throwsUnimplementedError);
    });

    test('mock load() can be called and tracked', () async {
      final mock = MockOpusFlutterPlatform();
      OpusFlutterPlatform.instance = mock;

      await OpusFlutterPlatform.instance.load();
      await OpusFlutterPlatform.instance.load();

      expect(mock.loadCallCount, 2);
    });

    test('load() returns Future<Object>', () {
      final mock = MockOpusFlutterPlatform();
      OpusFlutterPlatform.instance = mock;

      expect(OpusFlutterPlatform.instance.load(), isA<Future<Object>>());
    });

    test('opusVersion is 1.5.2', () {
      expect(OpusFlutterPlatform.opusVersion, '1.5.2');
    });

    test('opusVersion is a non-empty semver string', () {
      expect(OpusFlutterPlatform.opusVersion, isNotEmpty);
      expect(
        RegExp(r'^\d+\.\d+\.\d+$').hasMatch(OpusFlutterPlatform.opusVersion),
        isTrue,
      );
    });
  });

  group('OpusFlutterPlatformUnsupported', () {
    test('extends OpusFlutterPlatform', () {
      expect(OpusFlutterPlatformUnsupported(), isA<OpusFlutterPlatform>());
    });

    test('load() throws UnsupportedError', () {
      final unsupported = OpusFlutterPlatformUnsupported();
      expect(unsupported.load, throwsUnsupportedError);
    });

    test('error message describes the issue', () {
      final unsupported = OpusFlutterPlatformUnsupported();
      expect(
        unsupported.load,
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains('not supported'),
          ),
        ),
      );
    });

    test('can be set as the platform instance', () {
      final unsupported = OpusFlutterPlatformUnsupported();
      OpusFlutterPlatform.instance = unsupported;
      expect(
          OpusFlutterPlatform.instance, isA<OpusFlutterPlatformUnsupported>());
    });
  });
}
