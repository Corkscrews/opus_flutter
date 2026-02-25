import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:opus_codec_dart/src/opus_dart_misc.dart';
import 'package:opus_codec_dart/wrappers/opus_decoder.dart' as opus_decoder;
import 'package:opus_codec_dart/wrappers/opus_encoder.dart' as opus_encoder;
import 'package:opus_codec_dart/wrappers/opus_libinfo.dart' as opus_libinfo;
import 'package:opus_codec_dart/wrappers/opus_defines.dart';
import 'package:opus_codec_dart/opus_dart.dart';
import 'package:test/test.dart';

import 'opus_dart_mock_test.mocks.dart';

Pointer<Uint8> _allocNullTerminated(String s) {
  final bytes = utf8.encode(s);
  final ptr = malloc.call<Uint8>(bytes.length + 1);
  ptr.asTypedList(bytes.length).setAll(0, bytes);
  ptr[bytes.length] = 0;
  return ptr;
}

@GenerateMocks([
  opus_decoder.OpusDecoderFunctions,
  opus_encoder.OpusEncoderFunctions,
  opus_libinfo.OpusLibInfoFunctions,
])
void main() {
  late MockOpusDecoderFunctions mockDecoder;
  late MockOpusEncoderFunctions mockEncoder;
  late MockOpusLibInfoFunctions mockLibInfo;

  setUp(() {
    provideDummy<Pointer<opus_decoder.OpusDecoder>>(Pointer.fromAddress(0));
    provideDummy<Pointer<opus_encoder.OpusEncoder>>(Pointer.fromAddress(0));
    provideDummy<Pointer<Uint8>>(Pointer.fromAddress(0));

    mockDecoder = MockOpusDecoderFunctions();
    mockEncoder = MockOpusEncoderFunctions();
    mockLibInfo = MockOpusLibInfoFunctions();
    opus = ApiObject.test(
      libinfo: mockLibInfo,
      encoder: mockEncoder,
      decoder: mockDecoder,
      allocator: malloc,
    );
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  SimpleOpusEncoder createEncoder({
    int sampleRate = 48000,
    int channels = 2,
    Application application = Application.voip,
  }) {
    when(mockEncoder.opus_encoder_create(any, any, any, any)).thenAnswer((inv) {
      (inv.positionalArguments[3] as Pointer<Int32>).value = OPUS_OK;
      return Pointer<opus_encoder.OpusEncoder>.fromAddress(0xDEAD);
    });
    return SimpleOpusEncoder(
      sampleRate: sampleRate,
      channels: channels,
      application: application,
    );
  }

  SimpleOpusDecoder createDecoder({
    int sampleRate = 48000,
    int channels = 2,
  }) {
    when(mockDecoder.opus_decoder_create(any, any, any)).thenAnswer((inv) {
      (inv.positionalArguments[2] as Pointer<Int32>).value = OPUS_OK;
      return Pointer<opus_decoder.OpusDecoder>.fromAddress(0xDEAD);
    });
    return SimpleOpusDecoder(sampleRate: sampleRate, channels: channels);
  }

  BufferedOpusEncoder createBufferedEncoder({
    int sampleRate = 48000,
    int channels = 2,
    Application application = Application.audio,
  }) {
    when(mockEncoder.opus_encoder_create(any, any, any, any)).thenAnswer((inv) {
      (inv.positionalArguments[3] as Pointer<Int32>).value = OPUS_OK;
      return Pointer<opus_encoder.OpusEncoder>.fromAddress(0xDEAD);
    });
    return BufferedOpusEncoder(
      sampleRate: sampleRate,
      channels: channels,
      application: application,
    );
  }

  BufferedOpusDecoder createBufferedDecoder({
    int sampleRate = 48000,
    int channels = 2,
  }) {
    when(mockDecoder.opus_decoder_create(any, any, any)).thenAnswer((inv) {
      (inv.positionalArguments[2] as Pointer<Int32>).value = OPUS_OK;
      return Pointer<opus_decoder.OpusDecoder>.fromAddress(0xDEAD);
    });
    return BufferedOpusDecoder(sampleRate: sampleRate, channels: channels);
  }

  // ---------------------------------------------------------------------------
  // SimpleOpusEncoder
  // ---------------------------------------------------------------------------

  group('SimpleOpusEncoder', () {
    test('creates successfully when native returns OPUS_OK', () {
      final encoder = createEncoder();
      expect(encoder.sampleRate, 48000);
      expect(encoder.channels, 2);
      expect(encoder.application, Application.voip);
      expect(encoder.destroyed, isFalse);
      verify(mockEncoder.opus_encoder_create(
              48000, 2, OPUS_APPLICATION_VOIP, any))
          .called(1);
      encoder.destroy();
    });

    test('maps Application.audio correctly', () {
      final encoder = createEncoder(application: Application.audio);
      expect(encoder.application, Application.audio);
      verify(mockEncoder.opus_encoder_create(
              any, any, OPUS_APPLICATION_AUDIO, any))
          .called(1);
      encoder.destroy();
    });

    test('maps Application.restrictedLowdely correctly', () {
      final encoder = createEncoder(application: Application.restrictedLowdely);
      expect(encoder.application, Application.restrictedLowdely);
      verify(mockEncoder.opus_encoder_create(
              any, any, OPUS_APPLICATION_RESTRICTED_LOWDELAY, any))
          .called(1);
      encoder.destroy();
    });

    test('throws OpusException when native returns an error', () {
      when(mockEncoder.opus_encoder_create(any, any, any, any))
          .thenAnswer((inv) {
        (inv.positionalArguments[3] as Pointer<Int32>).value = OPUS_BAD_ARG;
        return Pointer<opus_encoder.OpusEncoder>.fromAddress(0);
      });
      expect(
        () => SimpleOpusEncoder(
            sampleRate: 48000, channels: 2, application: Application.voip),
        throwsA(isA<OpusException>()),
      );
    });

    test('encode returns encoded bytes', () {
      final encoder = createEncoder();
      when(mockEncoder.opus_encode(any, any, any, any, any)).thenAnswer((inv) {
        final outputPtr = inv.positionalArguments[3] as Pointer<Uint8>;
        outputPtr[0] = 0xAA;
        outputPtr[1] = 0xBB;
        outputPtr[2] = 0xCC;
        return 3;
      });

      final input = Int16List.fromList(List.filled(1920, 0));
      final result = encoder.encode(input: input);

      expect(result, hasLength(3));
      expect(result[0], 0xAA);
      expect(result[1], 0xBB);
      expect(result[2], 0xCC);
      verify(mockEncoder.opus_encode(any, any, 960, any, maxDataBytes))
          .called(1);
      encoder.destroy();
    });

    test('encode throws OpusException on native error', () {
      final encoder = createEncoder();
      when(mockEncoder.opus_encode(any, any, any, any, any))
          .thenReturn(OPUS_INTERNAL_ERROR);

      expect(
        () => encoder.encode(input: Int16List.fromList(List.filled(1920, 0))),
        throwsA(isA<OpusException>()),
      );
      encoder.destroy();
    });

    test('encodeFloat returns encoded bytes', () {
      final encoder = createEncoder();
      when(mockEncoder.opus_encode_float(any, any, any, any, any))
          .thenAnswer((inv) {
        final outputPtr = inv.positionalArguments[3] as Pointer<Uint8>;
        outputPtr[0] = 0x11;
        outputPtr[1] = 0x22;
        return 2;
      });

      final input = Float32List.fromList(List.filled(1920, 0.0));
      final result = encoder.encodeFloat(input: input);

      expect(result, hasLength(2));
      expect(result[0], 0x11);
      expect(result[1], 0x22);
      verify(mockEncoder.opus_encode_float(any, any, 960, any, maxDataBytes))
          .called(1);
      encoder.destroy();
    });

    test('encodeFloat throws OpusException on native error', () {
      final encoder = createEncoder();
      when(mockEncoder.opus_encode_float(any, any, any, any, any))
          .thenReturn(OPUS_BUFFER_TOO_SMALL);

      expect(
        () => encoder.encodeFloat(
            input: Float32List.fromList(List.filled(1920, 0.0))),
        throwsA(isA<OpusException>()),
      );
      encoder.destroy();
    });

    test('encode respects custom maxOutputSizeBytes', () {
      final encoder = createEncoder();
      when(mockEncoder.opus_encode(any, any, any, any, any)).thenReturn(1);

      encoder.encode(
          input: Int16List.fromList(List.filled(1920, 0)),
          maxOutputSizeBytes: 512);

      verify(mockEncoder.opus_encode(any, any, any, any, 512)).called(1);
      encoder.destroy();
    });

    test('destroy calls opus_encoder_destroy exactly once', () {
      when(mockEncoder.opus_encoder_destroy(any)).thenReturn(null);
      final encoder = createEncoder();
      encoder.destroy();
      encoder.destroy();
      verify(mockEncoder.opus_encoder_destroy(any)).called(1);
    });

    test('destroyed flag is true after destroy', () {
      final encoder = createEncoder();
      expect(encoder.destroyed, isFalse);
      encoder.destroy();
      expect(encoder.destroyed, isTrue);
    });

    test('encode after destroy throws OpusDestroyedError', () {
      final encoder = createEncoder();
      encoder.destroy();
      expect(
        () => encoder.encode(input: Int16List.fromList(List.filled(1920, 0))),
        throwsA(isA<OpusDestroyedError>()),
      );
    });

    test('encodeFloat after destroy throws OpusDestroyedError', () {
      final encoder = createEncoder();
      encoder.destroy();
      expect(
        () => encoder.encodeFloat(
            input: Float32List.fromList(List.filled(1920, 0.0))),
        throwsA(isA<OpusDestroyedError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // SimpleOpusDecoder
  // ---------------------------------------------------------------------------

  group('SimpleOpusDecoder', () {
    test('creates successfully when native returns OPUS_OK', () {
      final decoder = createDecoder();
      expect(decoder.sampleRate, 48000);
      expect(decoder.channels, 2);
      expect(decoder.destroyed, isFalse);
      expect(decoder.lastPacketDurationMs, isNull);
      verify(mockDecoder.opus_decoder_create(48000, 2, any)).called(1);
      decoder.destroy();
    });

    test('throws OpusException when native returns an error', () {
      when(mockDecoder.opus_decoder_create(any, any, any)).thenAnswer((inv) {
        (inv.positionalArguments[2] as Pointer<Int32>).value = OPUS_BAD_ARG;
        return Pointer<opus_decoder.OpusDecoder>.fromAddress(0);
      });
      expect(
        () => SimpleOpusDecoder(sampleRate: 48000, channels: 2),
        throwsA(isA<OpusException>()),
      );
    });

    test('decode returns Int16List with correct samples', () {
      final decoder = createDecoder();
      when(mockDecoder.opus_decode(any, any, any, any, any, any))
          .thenAnswer((inv) {
        final pcmPtr = inv.positionalArguments[3] as Pointer<Int16>;
        pcmPtr[0] = 100;
        pcmPtr[1] = 200;
        pcmPtr[2] = 300;
        pcmPtr[3] = 400;
        return 2; // 2 samples per channel, stereo = 4 total
      });

      final input = Uint8List.fromList([0x01, 0x02, 0x03]);
      final result = decoder.decode(input: input);

      expect(result, hasLength(4));
      expect(result[0], 100);
      expect(result[1], 200);
      expect(result[2], 300);
      expect(result[3], 400);
      decoder.destroy();
    });

    test('decode updates lastPacketDurationMs', () {
      final decoder = createDecoder(sampleRate: 48000, channels: 2);
      when(mockDecoder.opus_decode(any, any, any, any, any, any))
          .thenReturn(960); // 960 samples/ch = 10ms at 48kHz stereo

      decoder.decode(input: Uint8List.fromList([0x01]));

      expect(decoder.lastPacketDurationMs, 10);
      decoder.destroy();
    });

    test('decode throws OpusException on native error', () {
      final decoder = createDecoder();
      when(mockDecoder.opus_decode(any, any, any, any, any, any))
          .thenReturn(OPUS_INVALID_PACKET);

      expect(
        () => decoder.decode(input: Uint8List.fromList([0x01])),
        throwsA(isA<OpusException>()),
      );
      decoder.destroy();
    });

    test('decode with null input signals packet loss', () {
      final decoder = createDecoder();
      // First decode a real packet to set lastPacketDurationMs
      when(mockDecoder.opus_decode(any, any, any, any, any, any))
          .thenReturn(960);
      decoder.decode(input: Uint8List.fromList([0x01]));

      // Now signal packet loss with null input
      decoder.decode(input: null);

      // The second call should pass nullptr and fec=0
      final calls =
          verify(mockDecoder.opus_decode(any, any, any, any, any, any))
              .callCount;
      expect(calls, 2);
      decoder.destroy();
    });

    test('decode with null input and no prior packet throws StateError', () {
      final decoder = createDecoder();
      expect(
        () => decoder.decode(input: null),
        throwsA(isA<StateError>()),
      );
      decoder.destroy();
    });

    test('decode with null input uses explicit loss parameter', () {
      final decoder = createDecoder();
      when(mockDecoder.opus_decode(any, any, any, any, any, any))
          .thenReturn(960);

      decoder.decode(input: null, loss: 20);

      verify(mockDecoder.opus_decode(any, any, 0, any, 20, 0)).called(1);
      decoder.destroy();
    });

    test('decode with fec=true passes fec flag to native', () {
      final decoder = createDecoder();
      when(mockDecoder.opus_decode(any, any, any, any, any, any))
          .thenReturn(960);

      decoder.decode(input: Uint8List.fromList([0x01]), fec: true, loss: 20);

      verify(mockDecoder.opus_decode(any, any, 1, any, 20, 1)).called(1);
      decoder.destroy();
    });

    test('decodeFloat returns Float32List with correct samples', () {
      final decoder = createDecoder();
      when(mockDecoder.opus_decode_float(any, any, any, any, any, any))
          .thenAnswer((inv) {
        final pcmPtr = inv.positionalArguments[3] as Pointer<Float>;
        pcmPtr[0] = 0.5;
        pcmPtr[1] = -0.5;
        return 1; // 1 sample per channel, stereo = 2 total
      });

      final input = Uint8List.fromList([0x01, 0x02]);
      final result = decoder.decodeFloat(input: input);

      expect(result, hasLength(2));
      expect(result[0], closeTo(0.5, 0.001));
      expect(result[1], closeTo(-0.5, 0.001));
      decoder.destroy();
    });

    test('decodeFloat throws OpusException on native error', () {
      final decoder = createDecoder();
      when(mockDecoder.opus_decode_float(any, any, any, any, any, any))
          .thenReturn(OPUS_INVALID_PACKET);

      expect(
        () => decoder.decodeFloat(input: Uint8List.fromList([0x01])),
        throwsA(isA<OpusException>()),
      );
      decoder.destroy();
    });

    test('decodeFloat with autoSoftClip calls opus_pcm_soft_clip', () {
      final decoder = createDecoder();
      when(mockDecoder.opus_decode_float(any, any, any, any, any, any))
          .thenReturn(960);
      when(mockDecoder.opus_pcm_soft_clip(any, any, any, any)).thenReturn(null);

      decoder.decodeFloat(
          input: Uint8List.fromList([0x01]), autoSoftClip: true);

      verify(mockDecoder.opus_pcm_soft_clip(any, any, 2, any)).called(1);
      decoder.destroy();
    });

    test('decodeFloat without autoSoftClip does not call soft clip', () {
      final decoder = createDecoder();
      when(mockDecoder.opus_decode_float(any, any, any, any, any, any))
          .thenReturn(960);

      decoder.decodeFloat(input: Uint8List.fromList([0x01]));

      verifyNever(mockDecoder.opus_pcm_soft_clip(any, any, any, any));
      decoder.destroy();
    });

    test('decodeFloat with null input signals packet loss', () {
      final decoder = createDecoder();
      when(mockDecoder.opus_decode_float(any, any, any, any, any, any))
          .thenReturn(960);

      decoder.decodeFloat(input: Uint8List.fromList([0x01]));
      decoder.decodeFloat(input: null);

      expect(
          verify(mockDecoder.opus_decode_float(any, any, any, any, any, any))
              .callCount,
          2);
      decoder.destroy();
    });

    test('decodeFloat with null input and no prior packet throws StateError',
        () {
      final decoder = createDecoder();
      expect(
        () => decoder.decodeFloat(input: null),
        throwsA(isA<StateError>()),
      );
      decoder.destroy();
    });

    test('decodeFloat with null input uses explicit loss parameter', () {
      final decoder = createDecoder();
      when(mockDecoder.opus_decode_float(any, any, any, any, any, any))
          .thenReturn(960);

      decoder.decodeFloat(input: null, loss: 20);

      verify(mockDecoder.opus_decode_float(any, any, 0, any, 20, 0)).called(1);
      decoder.destroy();
    });

    test('decodeFloat with fec=true passes fec flag to native', () {
      final decoder = createDecoder();
      when(mockDecoder.opus_decode_float(any, any, any, any, any, any))
          .thenReturn(960);

      decoder.decodeFloat(
          input: Uint8List.fromList([0x01]), fec: true, loss: 20);

      verify(mockDecoder.opus_decode_float(any, any, 1, any, 20, 1)).called(1);
      decoder.destroy();
    });

    test('decodeFloat updates lastPacketDurationMs', () {
      final decoder = createDecoder(sampleRate: 48000, channels: 2);
      when(mockDecoder.opus_decode_float(any, any, any, any, any, any))
          .thenReturn(960);

      decoder.decodeFloat(input: Uint8List.fromList([0x01]));

      expect(decoder.lastPacketDurationMs, 10);
      decoder.destroy();
    });

    test('destroy calls opus_decoder_destroy exactly once', () {
      when(mockDecoder.opus_decoder_destroy(any)).thenReturn(null);
      final decoder = createDecoder();
      decoder.destroy();
      decoder.destroy();
      verify(mockDecoder.opus_decoder_destroy(any)).called(1);
    });

    test('destroyed flag is true after destroy', () {
      final decoder = createDecoder();
      expect(decoder.destroyed, isFalse);
      decoder.destroy();
      expect(decoder.destroyed, isTrue);
    });

    test('decode after destroy throws OpusDestroyedError', () {
      final decoder = createDecoder();
      decoder.destroy();
      expect(
        () => decoder.decode(input: Uint8List.fromList([0x01])),
        throwsA(isA<OpusDestroyedError>()),
      );
    });

    test('decodeFloat after destroy throws OpusDestroyedError', () {
      final decoder = createDecoder();
      decoder.destroy();
      expect(
        () => decoder.decodeFloat(input: Uint8List.fromList([0x01])),
        throwsA(isA<OpusDestroyedError>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // BufferedOpusEncoder
  // ---------------------------------------------------------------------------

  group('BufferedOpusEncoder', () {
    test('creates successfully and exposes buffers', () {
      final encoder = createBufferedEncoder();
      expect(encoder.sampleRate, 48000);
      expect(encoder.channels, 2);
      expect(encoder.application, Application.audio);
      expect(encoder.inputBufferIndex, 0);
      expect(encoder.destroyed, isFalse);
      expect(encoder.maxOutputBufferSizeBytes, maxDataBytes);
      encoder.destroy();
    });

    test('throws OpusException when native returns an error', () {
      when(mockEncoder.opus_encoder_create(any, any, any, any))
          .thenAnswer((inv) {
        (inv.positionalArguments[3] as Pointer<Int32>).value = OPUS_ALLOC_FAIL;
        return Pointer<opus_encoder.OpusEncoder>.fromAddress(0);
      });
      expect(
        () => BufferedOpusEncoder(
            sampleRate: 48000, channels: 2, application: Application.voip),
        throwsA(isA<OpusException>()),
      );
    });

    test('encode writes to output buffer and returns it', () {
      final encoder = createBufferedEncoder();
      when(mockEncoder.opus_encode(any, any, any, any, any)).thenAnswer((inv) {
        final outputPtr = inv.positionalArguments[3] as Pointer<Uint8>;
        outputPtr[0] = 0xDE;
        outputPtr[1] = 0xAD;
        return 2;
      });

      // 1920 samples * 2 bytes = 3840 bytes for 20ms stereo 48kHz s16le
      encoder.inputBufferIndex = 3840;
      final result = encoder.encode();

      expect(result, hasLength(2));
      expect(result[0], 0xDE);
      expect(result[1], 0xAD);
      verify(mockEncoder.opus_encode(any, any, 960, any, any)).called(1);
      encoder.destroy();
    });

    test('encode throws OpusException on native error', () {
      final encoder = createBufferedEncoder();
      when(mockEncoder.opus_encode(any, any, any, any, any))
          .thenReturn(OPUS_INTERNAL_ERROR);

      encoder.inputBufferIndex = 3840;
      expect(() => encoder.encode(), throwsA(isA<OpusException>()));
      encoder.destroy();
    });

    test('encodeFloat writes to output buffer and returns it', () {
      final encoder = createBufferedEncoder();
      when(mockEncoder.opus_encode_float(any, any, any, any, any))
          .thenAnswer((inv) {
        final outputPtr = inv.positionalArguments[3] as Pointer<Uint8>;
        outputPtr[0] = 0xFF;
        return 1;
      });

      // 1920 samples * 4 bytes = 7680 bytes for 20ms stereo 48kHz float
      encoder.inputBufferIndex = 7680;
      final result = encoder.encodeFloat();

      expect(result, hasLength(1));
      expect(result[0], 0xFF);
      verify(mockEncoder.opus_encode_float(any, any, 960, any, any)).called(1);
      encoder.destroy();
    });

    test('encodeFloat throws OpusException on native error', () {
      final encoder = createBufferedEncoder();
      when(mockEncoder.opus_encode_float(any, any, any, any, any))
          .thenReturn(OPUS_INTERNAL_ERROR);

      encoder.inputBufferIndex = 7680;
      expect(() => encoder.encodeFloat(), throwsA(isA<OpusException>()));
      encoder.destroy();
    });

    test('encoderCtl forwards request to native', () {
      final encoder = createBufferedEncoder();
      when(mockEncoder.opus_encoder_ctl(any, any, any)).thenReturn(OPUS_OK);

      final result =
          encoder.encoderCtl(request: OPUS_SET_BITRATE_REQUEST, value: 64000);

      expect(result, OPUS_OK);
      verify(mockEncoder.opus_encoder_ctl(any, OPUS_SET_BITRATE_REQUEST, 64000))
          .called(1);
      encoder.destroy();
    });

    test('destroy calls opus_encoder_destroy exactly once', () {
      when(mockEncoder.opus_encoder_destroy(any)).thenReturn(null);
      final encoder = createBufferedEncoder();
      encoder.destroy();
      encoder.destroy();
      verify(mockEncoder.opus_encoder_destroy(any)).called(1);
    });

    test('destroyed flag is true after destroy', () {
      final encoder = createBufferedEncoder();
      expect(encoder.destroyed, isFalse);
      encoder.destroy();
      expect(encoder.destroyed, isTrue);
    });

    test('encode after destroy throws OpusDestroyedError', () {
      final encoder = createBufferedEncoder();
      encoder.inputBufferIndex = 3840;
      encoder.destroy();
      expect(() => encoder.encode(), throwsA(isA<OpusDestroyedError>()));
    });

    test('encodeFloat after destroy throws OpusDestroyedError', () {
      final encoder = createBufferedEncoder();
      encoder.inputBufferIndex = 7680;
      encoder.destroy();
      expect(() => encoder.encodeFloat(), throwsA(isA<OpusDestroyedError>()));
    });

    test('encoderCtl after destroy throws OpusDestroyedError', () {
      final encoder = createBufferedEncoder();
      encoder.destroy();
      expect(
        () => encoder.encoderCtl(
            request: OPUS_SET_BITRATE_REQUEST, value: 64000),
        throwsA(isA<OpusDestroyedError>()),
      );
    });

    test('respects custom buffer sizes', () {
      when(mockEncoder.opus_encoder_create(any, any, any, any))
          .thenAnswer((inv) {
        (inv.positionalArguments[3] as Pointer<Int32>).value = OPUS_OK;
        return Pointer<opus_encoder.OpusEncoder>.fromAddress(0xDEAD);
      });

      final encoder = BufferedOpusEncoder(
        sampleRate: 48000,
        channels: 2,
        application: Application.voip,
        maxInputBufferSizeBytes: 4096,
        maxOutputBufferSizeBytes: 1024,
      );

      expect(encoder.maxInputBufferSizeBytes, 4096);
      expect(encoder.maxOutputBufferSizeBytes, 1024);
      encoder.destroy();
    });
  });

  // ---------------------------------------------------------------------------
  // BufferedOpusDecoder
  // ---------------------------------------------------------------------------

  group('BufferedOpusDecoder', () {
    test('creates successfully and exposes buffers', () {
      final decoder = createBufferedDecoder();
      expect(decoder.sampleRate, 48000);
      expect(decoder.channels, 2);
      expect(decoder.inputBufferIndex, 0);
      expect(decoder.destroyed, isFalse);
      expect(decoder.lastPacketDurationMs, isNull);
      expect(decoder.maxInputBufferSizeBytes, maxDataBytes);
      decoder.destroy();
    });

    test('default output buffer is large enough for float decode', () {
      final decoder = createBufferedDecoder(sampleRate: 48000, channels: 2);
      // 4 bytes/float * maxSamplesPerPacket ensures a 120ms frame fits
      expect(decoder.maxOutputBufferSizeBytes,
          4 * maxSamplesPerPacket(48000, 2));
      decoder.destroy();
    });

    test('default output buffer is large enough for float decode (mono)', () {
      final decoder = createBufferedDecoder(sampleRate: 8000, channels: 1);
      expect(decoder.maxOutputBufferSizeBytes,
          4 * maxSamplesPerPacket(8000, 1));
      decoder.destroy();
    });

    test('decodeFloat succeeds with max frame size using default buffer', () {
      final decoder = createBufferedDecoder(sampleRate: 48000, channels: 2);
      // 120ms at 48kHz stereo = 5760 samples per channel
      const samplesPerChannel = 5760;
      when(mockDecoder.opus_decode_float(any, any, any, any, any, any))
          .thenReturn(samplesPerChannel);

      decoder.inputBufferIndex = 10;
      final result = decoder.decodeFloat();

      expect(result, hasLength(samplesPerChannel * 2));
      decoder.destroy();
    });

    test('throws OpusException when native returns an error', () {
      when(mockDecoder.opus_decoder_create(any, any, any)).thenAnswer((inv) {
        (inv.positionalArguments[2] as Pointer<Int32>).value = OPUS_ALLOC_FAIL;
        return Pointer<opus_decoder.OpusDecoder>.fromAddress(0);
      });
      expect(
        () => BufferedOpusDecoder(sampleRate: 48000, channels: 2),
        throwsA(isA<OpusException>()),
      );
    });

    test('decode returns Int16List from output buffer', () {
      final decoder = createBufferedDecoder();
      when(mockDecoder.opus_decode(any, any, any, any, any, any))
          .thenAnswer((inv) {
        final pcmPtr = inv.positionalArguments[3] as Pointer<Int16>;
        pcmPtr[0] = 1000;
        pcmPtr[1] = 2000;
        pcmPtr[2] = 3000;
        pcmPtr[3] = 4000;
        return 2; // 2 samples per channel
      });

      decoder.inputBufferIndex = 10;
      final result = decoder.decode();

      expect(result, hasLength(4));
      expect(result[0], 1000);
      expect(result[1], 2000);
      expect(result[2], 3000);
      expect(result[3], 4000);
      decoder.destroy();
    });

    test('decode updates lastPacketDurationMs', () {
      final decoder = createBufferedDecoder(sampleRate: 48000, channels: 2);
      when(mockDecoder.opus_decode(any, any, any, any, any, any))
          .thenReturn(960);

      decoder.inputBufferIndex = 10;
      decoder.decode();

      expect(decoder.lastPacketDurationMs, 10);
      decoder.destroy();
    });

    test('decode throws OpusException on native error', () {
      final decoder = createBufferedDecoder();
      when(mockDecoder.opus_decode(any, any, any, any, any, any))
          .thenReturn(OPUS_INVALID_PACKET);

      decoder.inputBufferIndex = 10;
      expect(() => decoder.decode(), throwsA(isA<OpusException>()));
      decoder.destroy();
    });

    test('decode with inputBufferIndex=0 signals packet loss', () {
      final decoder = createBufferedDecoder();
      when(mockDecoder.opus_decode(any, any, any, any, any, any))
          .thenReturn(960);

      // First decode to set lastPacketDurationMs
      decoder.inputBufferIndex = 10;
      decoder.decode();

      // Now signal loss
      decoder.inputBufferIndex = 0;
      decoder.decode();

      expect(
          verify(mockDecoder.opus_decode(any, any, any, any, any, any))
              .callCount,
          2);
      decoder.destroy();
    });

    test('decode with inputBufferIndex=0 and no prior packet throws', () {
      final decoder = createBufferedDecoder();
      decoder.inputBufferIndex = 0;
      expect(() => decoder.decode(), throwsA(isA<StateError>()));
      decoder.destroy();
    });

    test('decodeFloat returns Float32List from output buffer', () {
      final decoder = createBufferedDecoder();
      when(mockDecoder.opus_decode_float(any, any, any, any, any, any))
          .thenAnswer((inv) {
        final pcmPtr = inv.positionalArguments[3] as Pointer<Float>;
        pcmPtr[0] = 0.25;
        pcmPtr[1] = -0.75;
        return 1; // 1 sample per channel
      });

      decoder.inputBufferIndex = 10;
      final result = decoder.decodeFloat();

      expect(result, hasLength(2));
      expect(result[0], closeTo(0.25, 0.001));
      expect(result[1], closeTo(-0.75, 0.001));
      decoder.destroy();
    });

    test('decodeFloat throws OpusException on native error', () {
      final decoder = createBufferedDecoder();
      when(mockDecoder.opus_decode_float(any, any, any, any, any, any))
          .thenReturn(OPUS_INVALID_PACKET);

      decoder.inputBufferIndex = 10;
      expect(() => decoder.decodeFloat(), throwsA(isA<OpusException>()));
      decoder.destroy();
    });

    test('decode with fec=true passes fec flag to native', () {
      final decoder = createBufferedDecoder();
      when(mockDecoder.opus_decode(any, any, any, any, any, any))
          .thenReturn(960);

      decoder.inputBufferIndex = 10;
      decoder.decode(fec: true);

      verify(mockDecoder.opus_decode(any, any, 10, any, any, 1)).called(1);
      decoder.destroy();
    });

    test('decode with inputBufferIndex=0 uses explicit loss parameter', () {
      final decoder = createBufferedDecoder();
      when(mockDecoder.opus_decode(any, any, any, any, any, any))
          .thenReturn(960);

      decoder.inputBufferIndex = 0;
      decoder.decode(loss: 20);

      verify(mockDecoder.opus_decode(any, any, 0, any, 20, 0)).called(1);
      decoder.destroy();
    });

    test('decodeFloat with autoSoftClip calls pcmSoftClipOutputBuffer', () {
      final decoder = createBufferedDecoder();
      when(mockDecoder.opus_decode_float(any, any, any, any, any, any))
          .thenReturn(960);
      when(mockDecoder.opus_pcm_soft_clip(any, any, any, any)).thenReturn(null);

      decoder.inputBufferIndex = 10;
      decoder.decodeFloat(autoSoftClip: true);

      verify(mockDecoder.opus_pcm_soft_clip(any, any, 2, any)).called(1);
      decoder.destroy();
    });

    test('decodeFloat without autoSoftClip does not call soft clip', () {
      final decoder = createBufferedDecoder();
      when(mockDecoder.opus_decode_float(any, any, any, any, any, any))
          .thenReturn(960);

      decoder.inputBufferIndex = 10;
      decoder.decodeFloat();

      verifyNever(mockDecoder.opus_pcm_soft_clip(any, any, any, any));
      decoder.destroy();
    });

    test('decodeFloat updates lastPacketDurationMs', () {
      final decoder = createBufferedDecoder(sampleRate: 48000, channels: 2);
      when(mockDecoder.opus_decode_float(any, any, any, any, any, any))
          .thenReturn(960);

      decoder.inputBufferIndex = 10;
      decoder.decodeFloat();

      expect(decoder.lastPacketDurationMs, 10);
      decoder.destroy();
    });

    test('decodeFloat with inputBufferIndex=0 signals packet loss', () {
      final decoder = createBufferedDecoder();
      when(mockDecoder.opus_decode_float(any, any, any, any, any, any))
          .thenReturn(960);

      decoder.inputBufferIndex = 10;
      decoder.decodeFloat();

      decoder.inputBufferIndex = 0;
      decoder.decodeFloat();

      expect(
          verify(mockDecoder.opus_decode_float(any, any, any, any, any, any))
              .callCount,
          2);
      decoder.destroy();
    });

    test('decodeFloat with inputBufferIndex=0 and no prior packet throws', () {
      final decoder = createBufferedDecoder();
      decoder.inputBufferIndex = 0;
      expect(() => decoder.decodeFloat(), throwsA(isA<StateError>()));
      decoder.destroy();
    });

    test('decodeFloat with inputBufferIndex=0 uses explicit loss parameter',
        () {
      final decoder = createBufferedDecoder();
      when(mockDecoder.opus_decode_float(any, any, any, any, any, any))
          .thenReturn(960);

      decoder.inputBufferIndex = 0;
      decoder.decodeFloat(loss: 20);

      verify(mockDecoder.opus_decode_float(any, any, 0, any, 20, 0)).called(1);
      decoder.destroy();
    });

    test('decodeFloat with fec=true passes fec flag to native', () {
      final decoder = createBufferedDecoder();
      when(mockDecoder.opus_decode_float(any, any, any, any, any, any))
          .thenReturn(960);

      decoder.inputBufferIndex = 10;
      decoder.decodeFloat(fec: true);

      verify(mockDecoder.opus_decode_float(any, any, 10, any, any, 1))
          .called(1);
      decoder.destroy();
    });

    test('pcmSoftClipOutputBuffer applies soft clipping to output buffer', () {
      final decoder = createBufferedDecoder();
      when(mockDecoder.opus_decode_float(any, any, any, any, any, any))
          .thenReturn(960);
      when(mockDecoder.opus_pcm_soft_clip(any, any, any, any)).thenReturn(null);

      decoder.inputBufferIndex = 10;
      decoder.decodeFloat();
      final result = decoder.pcmSoftClipOutputBuffer();

      verify(mockDecoder.opus_pcm_soft_clip(any, any, 2, any)).called(1);
      expect(result, isA<Float32List>());
      decoder.destroy();
    });

    test('inputBuffer has correct size', () {
      final decoder = createBufferedDecoder();
      expect(decoder.inputBuffer.length, maxDataBytes);
      decoder.destroy();
    });

    test('outputBuffer reflects decoded bytes', () {
      final decoder = createBufferedDecoder();
      when(mockDecoder.opus_decode(any, any, any, any, any, any))
          .thenAnswer((inv) {
        final pcmPtr = inv.positionalArguments[3] as Pointer<Int16>;
        pcmPtr[0] = 42;
        pcmPtr[1] = 43;
        return 1;
      });

      decoder.inputBufferIndex = 10;
      decoder.decode();

      expect(decoder.outputBuffer.length, 4);
      decoder.destroy();
    });

    test('outputBufferAsFloat32List after decodeFloat', () {
      final decoder = createBufferedDecoder();
      when(mockDecoder.opus_decode_float(any, any, any, any, any, any))
          .thenAnswer((inv) {
        final pcmPtr = inv.positionalArguments[3] as Pointer<Float>;
        pcmPtr[0] = 0.5;
        pcmPtr[1] = -0.5;
        return 1;
      });

      decoder.inputBufferIndex = 10;
      decoder.decodeFloat();

      final floats = decoder.outputBufferAsFloat32List;
      expect(floats, hasLength(2));
      expect(floats[0], closeTo(0.5, 0.001));
      expect(floats[1], closeTo(-0.5, 0.001));
      decoder.destroy();
    });

    test('destroy calls opus_decoder_destroy exactly once', () {
      when(mockDecoder.opus_decoder_destroy(any)).thenReturn(null);
      final decoder = createBufferedDecoder();
      decoder.destroy();
      decoder.destroy();
      verify(mockDecoder.opus_decoder_destroy(any)).called(1);
    });

    test('destroyed flag is true after destroy', () {
      final decoder = createBufferedDecoder();
      expect(decoder.destroyed, isFalse);
      decoder.destroy();
      expect(decoder.destroyed, isTrue);
    });

    test('decode after destroy throws OpusDestroyedError', () {
      final decoder = createBufferedDecoder();
      decoder.inputBufferIndex = 10;
      decoder.destroy();
      expect(() => decoder.decode(), throwsA(isA<OpusDestroyedError>()));
    });

    test('decodeFloat after destroy throws OpusDestroyedError', () {
      final decoder = createBufferedDecoder();
      decoder.inputBufferIndex = 10;
      decoder.destroy();
      expect(() => decoder.decodeFloat(), throwsA(isA<OpusDestroyedError>()));
    });

    test('pcmSoftClipOutputBuffer after destroy throws OpusDestroyedError', () {
      final decoder = createBufferedDecoder();
      decoder.destroy();
      expect(() => decoder.pcmSoftClipOutputBuffer(),
          throwsA(isA<OpusDestroyedError>()));
    });

    test('respects custom buffer sizes', () {
      when(mockDecoder.opus_decoder_create(any, any, any)).thenAnswer((inv) {
        (inv.positionalArguments[2] as Pointer<Int32>).value = OPUS_OK;
        return Pointer<opus_decoder.OpusDecoder>.fromAddress(0xDEAD);
      });

      final decoder = BufferedOpusDecoder(
        sampleRate: 48000,
        channels: 2,
        maxInputBufferSizeBytes: 2048,
        maxOutputBufferSizeBytes: 8192,
      );

      expect(decoder.maxInputBufferSizeBytes, 2048);
      expect(decoder.maxOutputBufferSizeBytes, 8192);
      decoder.destroy();
    });
  });

  // ---------------------------------------------------------------------------
  // Top-level functions
  // ---------------------------------------------------------------------------

  group('getOpusVersion', () {
    test('returns version string from native', () {
      final versionPtr = _allocNullTerminated('libopus 1.4');
      when(mockLibInfo.opus_get_version_string()).thenReturn(versionPtr);

      final version = getOpusVersion();
      expect(version, 'libopus 1.4');
      verify(mockLibInfo.opus_get_version_string()).called(1);

      malloc.free(versionPtr);
    });

    test('returns empty string when pointer starts with null terminator', () {
      final ptr = _allocNullTerminated('');
      when(mockLibInfo.opus_get_version_string()).thenReturn(ptr);

      expect(getOpusVersion(), '');

      malloc.free(ptr);
    });

    test('throws StateError when string exceeds maxStringLength', () {
      final ptr = malloc.call<Uint8>(maxStringLength + 1);
      for (int i = 0; i < maxStringLength + 1; i++) {
        ptr[i] = 0x41; // 'A', no null terminator
      }
      when(mockLibInfo.opus_get_version_string()).thenReturn(ptr);

      expect(() => getOpusVersion(), throwsStateError);

      malloc.free(ptr);
    });

    test('succeeds when string is exactly maxStringLength - 1 chars', () {
      final len = maxStringLength - 1;
      final ptr = malloc.call<Uint8>(len + 1);
      for (int i = 0; i < len; i++) {
        ptr[i] = 0x42; // 'B'
      }
      ptr[len] = 0;
      when(mockLibInfo.opus_get_version_string()).thenReturn(ptr);

      expect(getOpusVersion(), 'B' * len);

      malloc.free(ptr);
    });
  });

  group('OpusException.toString', () {
    test('includes error code and native error string', () {
      final errorMsgPtr = _allocNullTerminated('invalid argument');
      when(mockLibInfo.opus_strerror(OPUS_BAD_ARG)).thenReturn(errorMsgPtr);

      const exception = OpusException(OPUS_BAD_ARG);
      final str = exception.toString();

      expect(str, contains('$OPUS_BAD_ARG'));
      expect(str, contains('invalid argument'));
      verify(mockLibInfo.opus_strerror(OPUS_BAD_ARG)).called(1);

      malloc.free(errorMsgPtr);
    });
  });

  group('pcmSoftClip', () {
    test('calls opus_pcm_soft_clip and returns clipped data', () {
      when(mockDecoder.opus_pcm_soft_clip(any, any, any, any)).thenReturn(null);

      final input = Float32List.fromList([0.5, -0.5, 1.5, -1.5]);
      final result = pcmSoftClip(input: input, channels: 2);

      expect(result, hasLength(4));
      verify(mockDecoder.opus_pcm_soft_clip(any, 2, 2, any)).called(1);
    });

    test('passes correct frame_size for mono', () {
      when(mockDecoder.opus_pcm_soft_clip(any, any, any, any)).thenReturn(null);

      final input = Float32List.fromList([0.1, 0.2, 0.3]);
      pcmSoftClip(input: input, channels: 1);

      verify(mockDecoder.opus_pcm_soft_clip(any, 3, 1, any)).called(1);
    });
  });

  // ---------------------------------------------------------------------------
  // OpusPacketUtils
  // ---------------------------------------------------------------------------

  group('OpusPacketUtils.getSampleCount', () {
    final packet = Uint8List.fromList([0x78, 0x01, 0x02]);

    test('returns value from native', () {
      when(mockDecoder.opus_packet_get_nb_samples(any, any, any))
          .thenReturn(960);

      final result =
          OpusPacketUtils.getSampleCount(packet: packet, sampleRate: 48000);

      expect(result, 960);
      verify(mockDecoder.opus_packet_get_nb_samples(any, 3, 48000)).called(1);
    });

    test('forwards sampleRate to native', () {
      when(mockDecoder.opus_packet_get_nb_samples(any, any, any))
          .thenReturn(160);

      OpusPacketUtils.getSampleCount(packet: packet, sampleRate: 16000);

      verify(mockDecoder.opus_packet_get_nb_samples(any, 3, 16000)).called(1);
    });

    test('throws OpusException on native error', () {
      when(mockDecoder.opus_packet_get_nb_samples(any, any, any))
          .thenReturn(OPUS_INVALID_PACKET);

      expect(
        () => OpusPacketUtils.getSampleCount(packet: packet, sampleRate: 48000),
        throwsA(isA<OpusException>()),
      );
    });

    test('copies packet bytes into native memory', () {
      when(mockDecoder.opus_packet_get_nb_samples(any, any, any))
          .thenReturn(960);

      OpusPacketUtils.getSampleCount(packet: packet, sampleRate: 48000);

      verify(mockDecoder.opus_packet_get_nb_samples(any, packet.length, any))
          .called(1);
    });
  });

  group('OpusPacketUtils.getFrameCount', () {
    final packet = Uint8List.fromList([0x78, 0x01]);

    test('returns value from native', () {
      when(mockDecoder.opus_packet_get_nb_frames(any, any)).thenReturn(3);

      final result = OpusPacketUtils.getFrameCount(packet: packet);

      expect(result, 3);
      verify(mockDecoder.opus_packet_get_nb_frames(any, 2)).called(1);
    });

    test('forwards packet length to native', () {
      final longPacket = Uint8List.fromList([0x78, 0x01, 0x02, 0x03]);
      when(mockDecoder.opus_packet_get_nb_frames(any, any)).thenReturn(1);

      OpusPacketUtils.getFrameCount(packet: longPacket);

      verify(mockDecoder.opus_packet_get_nb_frames(any, 4)).called(1);
    });

    test('throws OpusException on native error', () {
      when(mockDecoder.opus_packet_get_nb_frames(any, any))
          .thenReturn(OPUS_INVALID_PACKET);

      expect(
        () => OpusPacketUtils.getFrameCount(packet: packet),
        throwsA(isA<OpusException>()),
      );
    });
  });

  group('OpusPacketUtils.getSamplesPerFrame', () {
    final packet = Uint8List.fromList([0x78, 0x01]);

    test('returns value from native', () {
      when(mockDecoder.opus_packet_get_samples_per_frame(any, any))
          .thenReturn(480);

      final result =
          OpusPacketUtils.getSamplesPerFrame(packet: packet, sampleRate: 48000);

      expect(result, 480);
      verify(mockDecoder.opus_packet_get_samples_per_frame(any, 48000))
          .called(1);
    });

    test('forwards sampleRate to native', () {
      when(mockDecoder.opus_packet_get_samples_per_frame(any, any))
          .thenReturn(80);

      OpusPacketUtils.getSamplesPerFrame(packet: packet, sampleRate: 8000);

      verify(mockDecoder.opus_packet_get_samples_per_frame(any, 8000))
          .called(1);
    });

    test('throws OpusException on native error', () {
      when(mockDecoder.opus_packet_get_samples_per_frame(any, any))
          .thenReturn(OPUS_INVALID_PACKET);

      expect(
        () => OpusPacketUtils.getSamplesPerFrame(
            packet: packet, sampleRate: 48000),
        throwsA(isA<OpusException>()),
      );
    });
  });

  group('OpusPacketUtils.getChannelCount', () {
    final packet = Uint8List.fromList([0x78, 0x01]);

    test('returns 1 for mono', () {
      when(mockDecoder.opus_packet_get_nb_channels(any)).thenReturn(1);

      final result = OpusPacketUtils.getChannelCount(packet: packet);

      expect(result, 1);
      verify(mockDecoder.opus_packet_get_nb_channels(any)).called(1);
    });

    test('returns 2 for stereo', () {
      when(mockDecoder.opus_packet_get_nb_channels(any)).thenReturn(2);

      final result = OpusPacketUtils.getChannelCount(packet: packet);

      expect(result, 2);
    });

    test('throws OpusException on native error', () {
      when(mockDecoder.opus_packet_get_nb_channels(any))
          .thenReturn(OPUS_INVALID_PACKET);

      expect(
        () => OpusPacketUtils.getChannelCount(packet: packet),
        throwsA(isA<OpusException>()),
      );
    });
  });

  group('OpusPacketUtils.getBandwidth', () {
    final packet = Uint8List.fromList([0x78, 0x01]);

    test('returns bandwidth constant from native', () {
      when(mockDecoder.opus_packet_get_bandwidth(any))
          .thenReturn(OPUS_BANDWIDTH_FULLBAND);

      final result = OpusPacketUtils.getBandwidth(packet: packet);

      expect(result, OPUS_BANDWIDTH_FULLBAND);
      verify(mockDecoder.opus_packet_get_bandwidth(any)).called(1);
    });

    test('returns OPUS_BANDWIDTH_NARROWBAND correctly', () {
      when(mockDecoder.opus_packet_get_bandwidth(any))
          .thenReturn(OPUS_BANDWIDTH_NARROWBAND);

      expect(
        OpusPacketUtils.getBandwidth(packet: packet),
        OPUS_BANDWIDTH_NARROWBAND,
      );
    });

    test('throws OpusException on native error', () {
      when(mockDecoder.opus_packet_get_bandwidth(any))
          .thenReturn(OPUS_INVALID_PACKET);

      expect(
        () => OpusPacketUtils.getBandwidth(packet: packet),
        throwsA(isA<OpusException>()),
      );
    });
  });
}
