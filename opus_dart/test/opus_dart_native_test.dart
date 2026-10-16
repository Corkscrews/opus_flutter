import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:opus_codec_dart/opus_codec_dart.dart';
import 'package:opus_codec_dart/wrappers/opus_defines.dart';
import 'package:test/test.dart';

/// Runs against the libopus code asset built by hook/build.dart. The mock
/// tests cannot catch a hook or binding failure; these can.

const _sampleRate = 48000;
const _frameSize = 960; // 20 ms at 48 kHz

double _rms(List<int> samples) {
  var sum = 0.0;
  for (final sample in samples) {
    sum += sample * sample;
  }
  return sqrt(sum / samples.length);
}

void main() {
  // Runs before the group's setUpAll, which initializes the bundled backend.
  // initOpus is idempotent, so this must come first in the isolate.
  test('refuses a library passed on native platforms', () {
    expect(() => initOpus(Object()), throwsArgumentError);
  });

  group('bundled libopus', () {
    setUpAll(() => initOpus());

    test('reports the version pinned in native/libopus.json', () {
      final manifest =
          jsonDecode(File('native/libopus.json').readAsStringSync())
              as Map<String, dynamic>;
      // A float build reports exactly this; "unknown" means config.h was
      // not included, "-fixed" would mean the wrong source set.
      expect(getOpusVersion(), 'libopus ${manifest['version']}');
    });

    test('maps error codes through opus_strerror', () {
      expect(const OpusException(OPUS_BAD_ARG).toString(), contains('-1'));
      expect(
        const OpusException(OPUS_BAD_ARG).toString(),
        isNot(contains('unknown error')),
      );
    });

    test('inspects an encoded packet', () {
      final encoder = SimpleOpusEncoder(
        sampleRate: _sampleRate,
        channels: 2,
        application: Application.audio,
      );
      final packet = encoder.encode(input: Int16List(_frameSize * 2));
      encoder.destroy();

      expect(OpusPacketUtils.getChannelCount(packet: packet), 2);
      expect(OpusPacketUtils.getFrameCount(packet: packet), 1);
      expect(
        OpusPacketUtils.getSampleCount(packet: packet, sampleRate: _sampleRate),
        _frameSize,
      );
      expect(
        OpusPacketUtils.getSamplesPerFrame(
          packet: packet,
          sampleRate: _sampleRate,
        ),
        _frameSize,
      );
      expect(OpusPacketUtils.getBandwidth(packet: packet), greaterThan(0));
    });

    test('soft-clips float samples into [-1, 1]', () {
      final clipped = pcmSoftClip(
        input: Float32List.fromList([2.0, -2.0, 0.5, -0.5]),
        channels: 2,
      );
      for (final sample in clipped) {
        expect(sample, inInclusiveRange(-1.0, 1.0));
      }
    });

    test('round-trips 20 ms of a tone with comparable energy', () {
      final encoder = SimpleOpusEncoder(
        sampleRate: _sampleRate,
        channels: 1,
        application: Application.audio,
      );
      final decoder = SimpleOpusDecoder(sampleRate: _sampleRate, channels: 1);
      final input = Int16List.fromList([
        for (var i = 0; i < _frameSize; i++)
          (8000 * sin(2 * pi * 440 * i / _sampleRate)).round(),
      ]);

      // Opus has algorithmic delay, so decode several frames and compare the
      // last one. The tolerance is loose on purpose: this is lossy audio.
      Int16List output = Int16List(0);
      for (var frame = 0; frame < 10; frame++) {
        output = decoder.decode(input: encoder.encode(input: input));
      }

      expect(output.length, _frameSize);
      expect(_rms(output), closeTo(_rms(input), _rms(input) * 0.5));

      encoder.destroy();
      decoder.destroy();
    });

    test('accepts integer setter CTLs and rejects getters', () {
      final encoder = BufferedOpusEncoder(
        sampleRate: _sampleRate,
        channels: 1,
        application: Application.audio,
      );

      expect(
        encoder.encoderCtl(request: OPUS_SET_BITRATE_REQUEST, value: 64000),
        OPUS_OK,
      );
      expect(
        encoder.encoderCtl(request: OPUS_GET_BITRATE_REQUEST, value: 0),
        OPUS_BAD_ARG,
      );

      encoder.destroy();
    });
  });
}
