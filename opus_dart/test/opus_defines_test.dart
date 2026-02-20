import 'package:test/test.dart';
import 'package:opus_dart/src/opus_dart_misc.dart' show maxDataBytes;

// Import the raw defines so we can verify every constant against the official
// opus C header values.  A mismatch here means someone changed a constant
// accidentally and broke wire compatibility.
import 'package:opus_dart/wrappers/opus_defines.dart';

void main() {
  group('Error codes', () {
    test('OPUS_OK is 0', () => expect(OPUS_OK, 0));
    test('OPUS_BAD_ARG is -1', () => expect(OPUS_BAD_ARG, -1));
    test('OPUS_BUFFER_TOO_SMALL is -2',
        () => expect(OPUS_BUFFER_TOO_SMALL, -2));
    test('OPUS_INTERNAL_ERROR is -3', () => expect(OPUS_INTERNAL_ERROR, -3));
    test('OPUS_INVALID_PACKET is -4', () => expect(OPUS_INVALID_PACKET, -4));
    test('OPUS_UNIMPLEMENTED is -5', () => expect(OPUS_UNIMPLEMENTED, -5));
    test('OPUS_INVALID_STATE is -6', () => expect(OPUS_INVALID_STATE, -6));
    test('OPUS_ALLOC_FAIL is -7', () => expect(OPUS_ALLOC_FAIL, -7));
  });

  group('Application types', () {
    test('OPUS_APPLICATION_VOIP is 2048',
        () => expect(OPUS_APPLICATION_VOIP, 2048));
    test('OPUS_APPLICATION_AUDIO is 2049',
        () => expect(OPUS_APPLICATION_AUDIO, 2049));
    test('OPUS_APPLICATION_RESTRICTED_LOWDELAY is 2051',
        () => expect(OPUS_APPLICATION_RESTRICTED_LOWDELAY, 2051));

    test('application types are distinct', () {
      final values = {
        OPUS_APPLICATION_VOIP,
        OPUS_APPLICATION_AUDIO,
        OPUS_APPLICATION_RESTRICTED_LOWDELAY,
      };
      expect(values.length, 3);
    });
  });

  group('Signal types', () {
    test('OPUS_SIGNAL_VOICE is 3001', () => expect(OPUS_SIGNAL_VOICE, 3001));
    test('OPUS_SIGNAL_MUSIC is 3002', () => expect(OPUS_SIGNAL_MUSIC, 3002));
  });

  group('Bandwidth constants', () {
    test('OPUS_BANDWIDTH_NARROWBAND is 1101',
        () => expect(OPUS_BANDWIDTH_NARROWBAND, 1101));
    test('OPUS_BANDWIDTH_MEDIUMBAND is 1102',
        () => expect(OPUS_BANDWIDTH_MEDIUMBAND, 1102));
    test('OPUS_BANDWIDTH_WIDEBAND is 1103',
        () => expect(OPUS_BANDWIDTH_WIDEBAND, 1103));
    test('OPUS_BANDWIDTH_SUPERWIDEBAND is 1104',
        () => expect(OPUS_BANDWIDTH_SUPERWIDEBAND, 1104));
    test('OPUS_BANDWIDTH_FULLBAND is 1105',
        () => expect(OPUS_BANDWIDTH_FULLBAND, 1105));

    test('bandwidths form a contiguous ascending range', () {
      expect(OPUS_BANDWIDTH_NARROWBAND + 1, OPUS_BANDWIDTH_MEDIUMBAND);
      expect(OPUS_BANDWIDTH_MEDIUMBAND + 1, OPUS_BANDWIDTH_WIDEBAND);
      expect(OPUS_BANDWIDTH_WIDEBAND + 1, OPUS_BANDWIDTH_SUPERWIDEBAND);
      expect(OPUS_BANDWIDTH_SUPERWIDEBAND + 1, OPUS_BANDWIDTH_FULLBAND);
    });
  });

  group('Frame size constants', () {
    test('OPUS_FRAMESIZE_ARG is 5000', () => expect(OPUS_FRAMESIZE_ARG, 5000));
    test('OPUS_FRAMESIZE_2_5_MS is 5001',
        () => expect(OPUS_FRAMESIZE_2_5_MS, 5001));
    test('OPUS_FRAMESIZE_5_MS is 5002',
        () => expect(OPUS_FRAMESIZE_5_MS, 5002));
    test('OPUS_FRAMESIZE_10_MS is 5003',
        () => expect(OPUS_FRAMESIZE_10_MS, 5003));
    test('OPUS_FRAMESIZE_20_MS is 5004',
        () => expect(OPUS_FRAMESIZE_20_MS, 5004));
    test('OPUS_FRAMESIZE_40_MS is 5005',
        () => expect(OPUS_FRAMESIZE_40_MS, 5005));
    test('OPUS_FRAMESIZE_60_MS is 5006',
        () => expect(OPUS_FRAMESIZE_60_MS, 5006));
    test('OPUS_FRAMESIZE_80_MS is 5007',
        () => expect(OPUS_FRAMESIZE_80_MS, 5007));
    test('OPUS_FRAMESIZE_100_MS is 5008',
        () => expect(OPUS_FRAMESIZE_100_MS, 5008));
    test('OPUS_FRAMESIZE_120_MS is 5009',
        () => expect(OPUS_FRAMESIZE_120_MS, 5009));

    test('frame size constants are sequential from ARG', () {
      final expected = List.generate(10, (i) => 5000 + i);
      final actual = [
        OPUS_FRAMESIZE_ARG,
        OPUS_FRAMESIZE_2_5_MS,
        OPUS_FRAMESIZE_5_MS,
        OPUS_FRAMESIZE_10_MS,
        OPUS_FRAMESIZE_20_MS,
        OPUS_FRAMESIZE_40_MS,
        OPUS_FRAMESIZE_60_MS,
        OPUS_FRAMESIZE_80_MS,
        OPUS_FRAMESIZE_100_MS,
        OPUS_FRAMESIZE_120_MS,
      ];
      expect(actual, expected);
    });
  });

  group('Auto / misc constants', () {
    test('OPUS_AUTO is -1000', () => expect(OPUS_AUTO, -1000));
    test('OPUS_BITRATE_MAX is -1', () => expect(OPUS_BITRATE_MAX, -1));
  });

  group('Encoder CTL request IDs', () {
    test('SET/GET pairs differ by 1', () {
      expect(OPUS_GET_APPLICATION_REQUEST - OPUS_SET_APPLICATION_REQUEST, 1);
      expect(OPUS_GET_BITRATE_REQUEST - OPUS_SET_BITRATE_REQUEST, 1);
      expect(OPUS_GET_MAX_BANDWIDTH_REQUEST - OPUS_SET_MAX_BANDWIDTH_REQUEST, 1);
      expect(OPUS_GET_VBR_REQUEST - OPUS_SET_VBR_REQUEST, 1);
      expect(OPUS_GET_BANDWIDTH_REQUEST - OPUS_SET_BANDWIDTH_REQUEST, 1);
      expect(OPUS_GET_COMPLEXITY_REQUEST - OPUS_SET_COMPLEXITY_REQUEST, 1);
      expect(OPUS_GET_INBAND_FEC_REQUEST - OPUS_SET_INBAND_FEC_REQUEST, 1);
      expect(
          OPUS_GET_PACKET_LOSS_PERC_REQUEST - OPUS_SET_PACKET_LOSS_PERC_REQUEST,
          1);
      expect(OPUS_GET_DTX_REQUEST - OPUS_SET_DTX_REQUEST, 1);
      expect(
          OPUS_GET_VBR_CONSTRAINT_REQUEST - OPUS_SET_VBR_CONSTRAINT_REQUEST, 1);
      expect(
          OPUS_GET_FORCE_CHANNELS_REQUEST - OPUS_SET_FORCE_CHANNELS_REQUEST, 1);
      expect(OPUS_GET_SIGNAL_REQUEST - OPUS_SET_SIGNAL_REQUEST, 1);
      expect(OPUS_GET_LSB_DEPTH_REQUEST - OPUS_SET_LSB_DEPTH_REQUEST, 1);
      expect(
        OPUS_GET_PREDICTION_DISABLED_REQUEST -
            OPUS_SET_PREDICTION_DISABLED_REQUEST,
        1,
      );
      expect(
        OPUS_GET_PHASE_INVERSION_DISABLED_REQUEST -
            OPUS_SET_PHASE_INVERSION_DISABLED_REQUEST,
        1,
      );
    });

    test('SET request IDs are even', () {
      final sets = [
        OPUS_SET_APPLICATION_REQUEST,
        OPUS_SET_BITRATE_REQUEST,
        OPUS_SET_MAX_BANDWIDTH_REQUEST,
        OPUS_SET_VBR_REQUEST,
        OPUS_SET_BANDWIDTH_REQUEST,
        OPUS_SET_COMPLEXITY_REQUEST,
        OPUS_SET_INBAND_FEC_REQUEST,
        OPUS_SET_PACKET_LOSS_PERC_REQUEST,
        OPUS_SET_DTX_REQUEST,
        OPUS_SET_VBR_CONSTRAINT_REQUEST,
        OPUS_SET_FORCE_CHANNELS_REQUEST,
        OPUS_SET_SIGNAL_REQUEST,
        OPUS_SET_GAIN_REQUEST,
        OPUS_SET_LSB_DEPTH_REQUEST,
        OPUS_SET_EXPERT_FRAME_DURATION_REQUEST,
        OPUS_SET_PREDICTION_DISABLED_REQUEST,
        OPUS_SET_PHASE_INVERSION_DISABLED_REQUEST,
      ];
      for (final id in sets) {
        expect(id.isEven, isTrue, reason: 'CTL SET $id should be even');
      }
    });

    test('GET request IDs are odd', () {
      final gets = [
        OPUS_GET_APPLICATION_REQUEST,
        OPUS_GET_BITRATE_REQUEST,
        OPUS_GET_MAX_BANDWIDTH_REQUEST,
        OPUS_GET_VBR_REQUEST,
        OPUS_GET_BANDWIDTH_REQUEST,
        OPUS_GET_COMPLEXITY_REQUEST,
        OPUS_GET_INBAND_FEC_REQUEST,
        OPUS_GET_PACKET_LOSS_PERC_REQUEST,
        OPUS_GET_DTX_REQUEST,
        OPUS_GET_VBR_CONSTRAINT_REQUEST,
        OPUS_GET_FORCE_CHANNELS_REQUEST,
        OPUS_GET_SIGNAL_REQUEST,
        OPUS_GET_LOOKAHEAD_REQUEST,
        OPUS_GET_SAMPLE_RATE_REQUEST,
        OPUS_GET_FINAL_RANGE_REQUEST,
        OPUS_GET_PITCH_REQUEST,
        OPUS_GET_GAIN_REQUEST,
        OPUS_GET_LSB_DEPTH_REQUEST,
        OPUS_GET_LAST_PACKET_DURATION_REQUEST,
        OPUS_GET_EXPERT_FRAME_DURATION_REQUEST,
        OPUS_GET_PREDICTION_DISABLED_REQUEST,
        OPUS_GET_PHASE_INVERSION_DISABLED_REQUEST,
        OPUS_GET_IN_DTX_REQUEST,
      ];
      for (final id in gets) {
        expect(id.isOdd, isTrue, reason: 'CTL GET $id should be odd');
      }
    });
  });

  group('maxDataBytes', () {
    test('matches 3 * 1275 from opus spec', () {
      expect(maxDataBytes, 3825);
      expect(maxDataBytes, 3 * 1275);
    });
  });
}
