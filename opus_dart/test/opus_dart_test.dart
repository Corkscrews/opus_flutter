import 'package:opus_dart/opus_dart.dart';
import 'package:opus_dart/wrappers/opus_defines.dart';
import 'package:test/test.dart';

void main() {
  group('maxDataBytes', () {
    test('equals 3 * 1275', () {
      expect(maxDataBytes, 3 * 1275);
    });

    test('is large enough for any single opus packet', () {
      expect(maxDataBytes, greaterThanOrEqualTo(1275));
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

    test('12kHz mono', () {
      expect(maxSamplesPerPacket(12000, 1), 1440);
    });

    test('24kHz stereo', () {
      expect(maxSamplesPerPacket(24000, 2), 5760);
    });

    test('stereo is double mono for same sample rate', () {
      for (final rate in [8000, 12000, 16000, 24000, 48000]) {
        expect(
          maxSamplesPerPacket(rate, 2),
          maxSamplesPerPacket(rate, 1) * 2,
          reason: 'stereo should be 2x mono at $rate Hz',
        );
      }
    });

    test('higher sample rates produce more samples', () {
      final rates = [8000, 12000, 16000, 24000, 48000];
      for (int i = 0; i < rates.length - 1; i++) {
        expect(
          maxSamplesPerPacket(rates[i + 1], 1),
          greaterThan(maxSamplesPerPacket(rates[i], 1)),
          reason: '${rates[i + 1]} Hz should produce more samples than '
              '${rates[i]} Hz',
        );
      }
    });

    test('formula: ceil(sampleRate * channels * 120 / 1000)', () {
      for (final rate in [8000, 12000, 16000, 24000, 48000]) {
        for (final ch in [1, 2]) {
          final expected = ((rate * ch * 120) / 1000).ceil();
          expect(maxSamplesPerPacket(rate, ch), expected);
        }
      }
    });

    test('120ms is the maximum opus packet duration', () {
      // 48000 * 2 * 120 / 1000 = 11520 is the absolute max
      expect(maxSamplesPerPacket(48000, 2), 11520);
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

    test('encoder and decoder messages are distinct', () {
      final enc = OpusDestroyedError.encoder();
      final dec = OpusDestroyedError.decoder();
      expect(enc.message, isNot(dec.message));
    });

    test('can be caught as StateError', () {
      expect(
        () => throw OpusDestroyedError.encoder(),
        throwsA(isA<StateError>()),
      );
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

    test('can be const-constructed', () {
      const a = OpusException(OPUS_BAD_ARG);
      const b = OpusException(OPUS_BAD_ARG);
      expect(identical(a, b), isTrue);
    });

    test('stores all standard opus error codes', () {
      final errorCodes = [
        OPUS_BAD_ARG,
        OPUS_BUFFER_TOO_SMALL,
        OPUS_INTERNAL_ERROR,
        OPUS_INVALID_PACKET,
        OPUS_UNIMPLEMENTED,
        OPUS_INVALID_STATE,
        OPUS_ALLOC_FAIL,
      ];
      for (final code in errorCodes) {
        final e = OpusException(code);
        expect(e.errorCode, code);
      }
    });

    test('can be caught as Exception', () {
      expect(
        () => throw const OpusException(-1),
        throwsA(isA<Exception>()),
      );
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

    test('voip maps to OPUS_APPLICATION_VOIP (2048)', () {
      expect(OPUS_APPLICATION_VOIP, 2048);
    });

    test('audio maps to OPUS_APPLICATION_AUDIO (2049)', () {
      expect(OPUS_APPLICATION_AUDIO, 2049);
    });

    test(
        'restrictedLowdely maps to OPUS_APPLICATION_RESTRICTED_LOWDELAY (2051)',
        () {
      expect(OPUS_APPLICATION_RESTRICTED_LOWDELAY, 2051);
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
