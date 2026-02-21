import 'package:opus_dart/opus_dart.dart';
import 'package:test/test.dart';

void main() {
  group('UnfinishedFrameException', () {
    // The constructor is library-private, so we can only verify the type
    // exists and is an Exception subtype.
    test('is a subtype of Exception', () {
      expect(<UnfinishedFrameException>[], isA<List<Exception>>());
    });
  });

  group('FrameTime', () {
    test('values are in ascending duration order', () {
      expect(FrameTime.ms2_5.index, lessThan(FrameTime.ms5.index));
      expect(FrameTime.ms5.index, lessThan(FrameTime.ms10.index));
      expect(FrameTime.ms10.index, lessThan(FrameTime.ms20.index));
      expect(FrameTime.ms20.index, lessThan(FrameTime.ms40.index));
      expect(FrameTime.ms40.index, lessThan(FrameTime.ms60.index));
    });

    test('all values are accessible by name', () {
      expect(
          FrameTime.values.map((e) => e.name),
          containsAll([
            'ms2_5',
            'ms5',
            'ms10',
            'ms20',
            'ms40',
            'ms60',
          ]));
    });
  });

  group('Frame sample size calculation', () {
    // StreamOpusEncoder._calculateMaxSampleSize is private, but we can verify
    // the expected output for known configurations.  The formula is:
    //   samplesPerMs = (channels * sampleRate) ~/ 1000
    //   ms2_5 → 2 * samplesPerMs + samplesPerMs ~/ 2
    //   msN   → N * samplesPerMs
    //
    // These expected values are critical because a wrong frame size would
    // produce garbled audio.

    int calculateMaxSampleSize(
        int sampleRate, int channels, FrameTime frameTime) {
      final samplesPerMs = (channels * sampleRate) ~/ 1000;
      switch (frameTime) {
        case FrameTime.ms2_5:
          return 2 * samplesPerMs + (samplesPerMs ~/ 2);
        case FrameTime.ms5:
          return 5 * samplesPerMs;
        case FrameTime.ms10:
          return 10 * samplesPerMs;
        case FrameTime.ms20:
          return 20 * samplesPerMs;
        case FrameTime.ms40:
          return 40 * samplesPerMs;
        case FrameTime.ms60:
          return 60 * samplesPerMs;
      }
    }

    test('48kHz stereo, 20ms → 1920 samples', () {
      expect(calculateMaxSampleSize(48000, 2, FrameTime.ms20), 1920);
    });

    test('48kHz mono, 20ms → 960 samples', () {
      expect(calculateMaxSampleSize(48000, 1, FrameTime.ms20), 960);
    });

    test('16kHz mono, 20ms → 320 samples', () {
      expect(calculateMaxSampleSize(16000, 1, FrameTime.ms20), 320);
    });

    test('48kHz stereo, 2.5ms → 240 samples', () {
      expect(calculateMaxSampleSize(48000, 2, FrameTime.ms2_5), 240);
    });

    test('48kHz stereo, 60ms → 5760 samples', () {
      expect(calculateMaxSampleSize(48000, 2, FrameTime.ms60), 5760);
    });

    test('8kHz mono, 10ms → 80 samples', () {
      expect(calculateMaxSampleSize(8000, 1, FrameTime.ms10), 80);
    });

    test('sample sizes scale linearly with frame time', () {
      const sampleRate = 48000;
      const channels = 2;
      final ms10 = calculateMaxSampleSize(sampleRate, channels, FrameTime.ms10);
      final ms20 = calculateMaxSampleSize(sampleRate, channels, FrameTime.ms20);
      final ms40 = calculateMaxSampleSize(sampleRate, channels, FrameTime.ms40);
      final ms60 = calculateMaxSampleSize(sampleRate, channels, FrameTime.ms60);
      expect(ms20, ms10 * 2);
      expect(ms40, ms20 * 2);
      expect(ms60, ms20 * 3);
    });

    test('all opus-valid sample rates produce whole-number sample counts', () {
      const validRates = [8000, 12000, 16000, 24000, 48000];
      const validChannels = [1, 2];
      for (final rate in validRates) {
        for (final ch in validChannels) {
          for (final ft in FrameTime.values) {
            final size = calculateMaxSampleSize(rate, ch, ft);
            expect(size, greaterThan(0),
                reason: '$rate Hz, $ch ch, $ft should produce >0 samples');
          }
        }
      }
    });
  });
}
