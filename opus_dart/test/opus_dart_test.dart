import 'package:opus_dart/opus_dart.dart';
import 'package:test/test.dart';

void main() {
  group('maxDataBytes', () {
    test('equals 3 * 1275', () {
      expect(maxDataBytes, 3 * 1275);
    });
  });

  group('maxSamplesPerPacket', () {
    test('16kHz mono', () {
      expect(maxSamplesPerPacket(16000, 1), 1920);
    });

    test('48kHz stereo', () {
      expect(maxSamplesPerPacket(48000, 2), 11520);
    });

    test('8kHz mono', () {
      expect(maxSamplesPerPacket(8000, 1), 960);
    });

    test('formula: ceil(sampleRate * channels * 120 / 1000)', () {
      for (final rate in [8000, 12000, 16000, 24000, 48000]) {
        for (final ch in [1, 2]) {
          final expected = ((rate * ch * 120) / 1000).ceil();
          expect(maxSamplesPerPacket(rate, ch), expected);
        }
      }
    });
  });

  group('OpusDestroyedError', () {
    test('encoder message', () {
      final error = OpusDestroyedError.encoder();
      expect(error, isA<StateError>());
      expect(error.message, contains('OpusEncoder'));
      expect(error.message, contains('already destroyed'));
    });

    test('decoder message', () {
      final error = OpusDestroyedError.decoder();
      expect(error, isA<StateError>());
      expect(error.message, contains('OpusDecoder'));
      expect(error.message, contains('already destroyed'));
    });
  });

  group('OpusException', () {
    test('stores error code', () {
      const exception = OpusException(-1);
      expect(exception.errorCode, -1);
      expect(exception, isA<Exception>());
    });

    test('different error codes are distinct', () {
      const a = OpusException(-1);
      const b = OpusException(-2);
      expect(a.errorCode, isNot(b.errorCode));
    });
  });

  group('Application enum', () {
    test('has exactly 3 values', () {
      expect(Application.values.length, 3);
    });

    test('contains voip, audio, restrictedLowdely', () {
      expect(Application.values, contains(Application.voip));
      expect(Application.values, contains(Application.audio));
      expect(Application.values, contains(Application.restrictedLowdely));
    });
  });

  group('FrameTime enum', () {
    test('has exactly 6 values', () {
      expect(FrameTime.values.length, 6);
    });

    test('contains all frame durations', () {
      expect(FrameTime.values, contains(FrameTime.ms2_5));
      expect(FrameTime.values, contains(FrameTime.ms5));
      expect(FrameTime.values, contains(FrameTime.ms10));
      expect(FrameTime.values, contains(FrameTime.ms20));
      expect(FrameTime.values, contains(FrameTime.ms40));
      expect(FrameTime.values, contains(FrameTime.ms60));
    });
  });
}
