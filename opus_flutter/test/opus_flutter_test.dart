import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;
import 'package:opus_flutter_platform_interface/opus_flutter_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockOpusFlutterPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements OpusFlutterPlatform {
  int loadCallCount = 0;
  final Object _result = Object();

  @override
  Future<Object> load() async {
    loadCallCount++;
    return _result;
  }
}

class FailingOpusFlutterPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements OpusFlutterPlatform {
  @override
  Future<Object> load() async {
    throw StateError('native library corrupted');
  }
}

class DelayedOpusFlutterPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements OpusFlutterPlatform {
  final Object _result = Object();

  @override
  Future<Object> load() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return _result;
  }
}

void main() {
  group('load()', () {
    test('delegates to OpusFlutterPlatform.instance', () async {
      final mock = MockOpusFlutterPlatform();
      OpusFlutterPlatform.instance = mock;

      final result = await opus_flutter.load();

      expect(mock.loadCallCount, 1);
      expect(result, mock._result);
    });

    test('returns the exact object from the platform (identity)', () async {
      final mock = MockOpusFlutterPlatform();
      OpusFlutterPlatform.instance = mock;

      final result = await opus_flutter.load();

      expect(identical(result, mock._result), isTrue);
    });

    test('throws UnsupportedError on unsupported platform', () {
      OpusFlutterPlatform.instance = OpusFlutterPlatformUnsupported();
      expect(opus_flutter.load, throwsUnsupportedError);
    });

    test('propagates platform exceptions', () async {
      OpusFlutterPlatform.instance = FailingOpusFlutterPlatform();

      expect(opus_flutter.load(), throwsStateError);
    });

    test('each call invokes the platform again', () async {
      final mock = MockOpusFlutterPlatform();
      OpusFlutterPlatform.instance = mock;

      await opus_flutter.load();
      await opus_flutter.load();
      await opus_flutter.load();

      expect(mock.loadCallCount, 3);
    });

    test('returns a Future<Object>', () {
      final mock = MockOpusFlutterPlatform();
      OpusFlutterPlatform.instance = mock;

      final result = opus_flutter.load();

      expect(result, isA<Future<Object>>());
    });

    test('works with an async platform that delays', () async {
      final delayed = DelayedOpusFlutterPlatform();
      OpusFlutterPlatform.instance = delayed;

      final result = await opus_flutter.load();

      expect(identical(result, delayed._result), isTrue);
    });

    test('uses the current platform instance at call time', () async {
      final first = MockOpusFlutterPlatform();
      final second = MockOpusFlutterPlatform();

      OpusFlutterPlatform.instance = first;
      await opus_flutter.load();
      expect(first.loadCallCount, 1);
      expect(second.loadCallCount, 0);

      OpusFlutterPlatform.instance = second;
      await opus_flutter.load();
      expect(first.loadCallCount, 1);
      expect(second.loadCallCount, 1);
    });

    test('UnsupportedError message describes the issue', () {
      OpusFlutterPlatform.instance = OpusFlutterPlatformUnsupported();

      expect(
        opus_flutter.load,
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains('not supported'),
          ),
        ),
      );
    });
  });
}
