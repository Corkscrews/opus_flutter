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

import 'opus_dart_streaming_mock_test.mocks.dart';

// ---------------------------------------------------------------------------
// Test configuration
//
// 8 kHz mono with FrameTime.ms10 keeps buffer sizes small:
//   s16le frame  = 80 samples * 2 bytes  = 160 bytes
//   float frame  = 80 samples * 4 bytes  = 320 bytes
//   maxOutputBuf = maxSamplesPerPacket(8000, 1) = 960 bytes
// ---------------------------------------------------------------------------
const _sampleRate = 8000;
const _channels = 1;
const _frameTime = FrameTime.ms10;

// 80 samples per frame
const _samplesPerFrame = 80;
const _s16leFrameBytes = _samplesPerFrame * 2;
const _floatFrameBytes = _samplesPerFrame * 4;

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

  /// Stubs encoder creation to succeed and returns a sentinel pointer.
  void stubEncoderCreate() {
    when(mockEncoder.opus_encoder_create(any, any, any, any)).thenAnswer((inv) {
      (inv.positionalArguments[3] as Pointer<Int32>).value = OPUS_OK;
      return Pointer<opus_encoder.OpusEncoder>.fromAddress(0xDEAD);
    });
  }

  /// Stubs decoder creation to succeed and returns a sentinel pointer.
  void stubDecoderCreate() {
    when(mockDecoder.opus_decoder_create(any, any, any)).thenAnswer((inv) {
      (inv.positionalArguments[2] as Pointer<Int32>).value = OPUS_OK;
      return Pointer<opus_decoder.OpusDecoder>.fromAddress(0xDEAD);
    });
  }

  /// Stubs `opus_encode` to write [outputBytes] into the native output buffer
  /// and return [outputBytes.length].
  void stubEncode(List<int> outputBytes) {
    when(mockEncoder.opus_encode(any, any, any, any, any)).thenAnswer((inv) {
      final ptr = inv.positionalArguments[3] as Pointer<Uint8>;
      for (var i = 0; i < outputBytes.length; i++) {
        ptr[i] = outputBytes[i];
      }
      return outputBytes.length;
    });
  }

  /// Stubs `opus_encode_float` to write [outputBytes] into the native output
  /// buffer and return [outputBytes.length].
  void stubEncodeFloat(List<int> outputBytes) {
    when(mockEncoder.opus_encode_float(any, any, any, any, any))
        .thenAnswer((inv) {
      final ptr = inv.positionalArguments[3] as Pointer<Uint8>;
      for (var i = 0; i < outputBytes.length; i++) {
        ptr[i] = outputBytes[i];
      }
      return outputBytes.length;
    });
  }

  /// Stubs `opus_decode` to write [pcmSamples] (Int16) into the native PCM
  /// buffer and return [pcmSamples.length] as samplesPerChannel.
  void stubDecode(List<int> pcmSamples) {
    when(mockDecoder.opus_decode(any, any, any, any, any, any))
        .thenAnswer((inv) {
      final ptr = inv.positionalArguments[3] as Pointer<Int16>;
      for (var i = 0; i < pcmSamples.length; i++) {
        ptr[i] = pcmSamples[i];
      }
      return pcmSamples.length; // samplesPerChannel (mono)
    });
  }

  /// Stubs `opus_decode_float` to write [pcmSamples] (Float) into the native
  /// PCM buffer and return [pcmSamples.length] as samplesPerChannel.
  void stubDecodeFloat(List<double> pcmSamples) {
    when(mockDecoder.opus_decode_float(any, any, any, any, any, any))
        .thenAnswer((inv) {
      final ptr = inv.positionalArguments[3] as Pointer<Float>;
      for (var i = 0; i < pcmSamples.length; i++) {
        ptr[i] = pcmSamples[i];
      }
      return pcmSamples.length;
    });
  }

  // ---------------------------------------------------------------------------
  // StreamOpusEncoder — properties
  // ---------------------------------------------------------------------------

  group('StreamOpusEncoder properties', () {
    test('exposes sampleRate, channels, application', () {
      stubEncoderCreate();
      final encoder = StreamOpusEncoder.s16le(
        frameTime: _frameTime,
        sampleRate: _sampleRate,
        channels: _channels,
        application: Application.audio,
      );
      expect(encoder.sampleRate, _sampleRate);
      expect(encoder.channels, _channels);
      expect(encoder.application, Application.audio);
      expect(encoder.frameTime, _frameTime);
      expect(encoder.floats, isFalse);
      expect(encoder.fillUpLastFrame, isTrue);
      expect(encoder.copyOutput, isTrue);
      encoder.destroy();
    });

    test('.float() sets floats=true', () {
      stubEncoderCreate();
      final encoder = StreamOpusEncoder.float(
        frameTime: _frameTime,
        sampleRate: _sampleRate,
        channels: _channels,
        application: Application.voip,
      );
      expect(encoder.floats, isTrue);
      encoder.destroy();
    });

    for (final ft in FrameTime.values) {
      test('constructs with FrameTime.${ft.name}', () {
        stubEncoderCreate();
        final encoder = StreamOpusEncoder.s16le(
          frameTime: ft,
          sampleRate: _sampleRate,
          channels: _channels,
          application: Application.audio,
        );
        expect(encoder.frameTime, ft);
        encoder.destroy();
      });
    }
  });

  // ---------------------------------------------------------------------------
  // StreamOpusEncoder.s16le — bind()
  // ---------------------------------------------------------------------------

  group('StreamOpusEncoder.s16le bind()', () {
    // The encoder always appends a trailing silence-flush frame when
    // fillUpLastFrame=true.  An exact frame during streaming + 1 flush = 2 total.
    test('exact single frame emits frame packet plus trailing flush', () async {
      stubEncoderCreate();
      stubEncode([0xDE, 0xAD]);

      final encoder = StreamOpusEncoder.s16le(
        frameTime: _frameTime,
        sampleRate: _sampleRate,
        channels: _channels,
        application: Application.voip,
      );

      final input = Int16List(_samplesPerFrame); // 80 zero samples
      final packets = await encoder.bind(Stream.value(input)).toList();

      // 1 encode while streaming + 1 trailing silence flush = 2
      expect(packets, hasLength(2));
      expect(packets[0], [0xDE, 0xAD]);
      verify(mockEncoder.opus_encode(any, any, _samplesPerFrame, any, any))
          .called(2);
    });

    test('two exact frames emit two frame packets plus trailing flush',
        () async {
      stubEncoderCreate();
      stubEncode([0xAA]);

      final encoder = StreamOpusEncoder.s16le(
        frameTime: _frameTime,
        sampleRate: _sampleRate,
        channels: _channels,
        application: Application.voip,
      );

      final input = Int16List(_samplesPerFrame * 2);
      final packets = await encoder.bind(Stream.value(input)).toList();

      // 2 encodes while streaming + 1 trailing flush = 3
      expect(packets, hasLength(3));
      verify(mockEncoder.opus_encode(any, any, any, any, any)).called(3);
    });

    test('data split across stream events buffers correctly', () async {
      stubEncoderCreate();
      stubEncode([0xBB]);

      final encoder = StreamOpusEncoder.s16le(
        frameTime: _frameTime,
        sampleRate: _sampleRate,
        channels: _channels,
        application: Application.voip,
      );

      // 40 samples in first event, 40 in second → 1 full frame during streaming
      // + 1 trailing flush = 2 packets total
      final half = Int16List(_samplesPerFrame ~/ 2);
      final packets =
          await encoder.bind(Stream.fromIterable([half, half])).toList();

      expect(packets, hasLength(2));
      verify(mockEncoder.opus_encode(any, any, any, any, any)).called(2);
    });

    test('partial frame with fillUpLastFrame=true pads and yields', () async {
      stubEncoderCreate();
      stubEncode([0xCC]);

      final encoder = StreamOpusEncoder.s16le(
        frameTime: _frameTime,
        sampleRate: _sampleRate,
        channels: _channels,
        application: Application.voip,
        fillUpLastFrame: true,
      );

      // Send half a frame — should be padded and encoded
      final half = Int16List(_samplesPerFrame ~/ 2);
      final packets = await encoder.bind(Stream.value(half)).toList();

      expect(packets, hasLength(1));
      verify(mockEncoder.opus_encode(any, any, any, any, any)).called(1);
    });

    test(
        'partial frame with fillUpLastFrame=false throws UnfinishedFrameException',
        () async {
      stubEncoderCreate();

      final encoder = StreamOpusEncoder.s16le(
        frameTime: _frameTime,
        sampleRate: _sampleRate,
        channels: _channels,
        application: Application.voip,
        fillUpLastFrame: false,
      );

      // Send half a frame — missingSamples = (_s16leFrameBytes - 80) ~/ 2 = 40
      final half = Int16List(_samplesPerFrame ~/ 2);
      await expectLater(
        encoder.bind(Stream.value(half)).toList(),
        throwsA(isA<UnfinishedFrameException>()),
      );
    });

    test('UnfinishedFrameException reports correct missingSamples', () async {
      stubEncoderCreate();

      final encoder = StreamOpusEncoder.s16le(
        frameTime: _frameTime,
        sampleRate: _sampleRate,
        channels: _channels,
        application: Application.voip,
        fillUpLastFrame: false,
      );

      final quarter = Int16List(_samplesPerFrame ~/ 4); // 20 samples = 40 bytes
      // missingSamples = (_s16leFrameBytes - 40) ~/ 2 = 60
      UnfinishedFrameException? caught;
      try {
        await encoder.bind(Stream.value(quarter)).toList();
      } on UnfinishedFrameException catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(caught!.missingSamples, _samplesPerFrame - _samplesPerFrame ~/ 4);
    });

    test('UnfinishedFrameException.toString() contains missing sample count',
        () async {
      stubEncoderCreate();

      final encoder = StreamOpusEncoder.s16le(
        frameTime: _frameTime,
        sampleRate: _sampleRate,
        channels: _channels,
        application: Application.voip,
        fillUpLastFrame: false,
      );

      final quarter = Int16List(_samplesPerFrame ~/ 4);
      UnfinishedFrameException? caught;
      try {
        await encoder.bind(Stream.value(quarter)).toList();
      } on UnfinishedFrameException catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      final message = caught.toString();
      expect(message, contains('UnfinishedFrameException'));
      expect(message, contains('${caught!.missingSamples}'));
    });

    test('encode error propagates as OpusException in stream', () async {
      stubEncoderCreate();
      when(mockEncoder.opus_encode(any, any, any, any, any))
          .thenReturn(OPUS_INTERNAL_ERROR);

      final encoder = StreamOpusEncoder.s16le(
        frameTime: _frameTime,
        sampleRate: _sampleRate,
        channels: _channels,
        application: Application.voip,
      );

      final input = Int16List(_samplesPerFrame);
      await expectLater(
        encoder.bind(Stream.value(input)).toList(),
        throwsA(isA<OpusException>()),
      );
    });

    test('destroy is called when stream ends normally', () async {
      stubEncoderCreate();
      stubEncode([0x01]);
      when(mockEncoder.opus_encoder_destroy(any)).thenReturn(null);

      final encoder = StreamOpusEncoder.s16le(
        frameTime: _frameTime,
        sampleRate: _sampleRate,
        channels: _channels,
        application: Application.voip,
      );

      await encoder.bind(Stream.value(Int16List(_samplesPerFrame))).toList();

      verify(mockEncoder.opus_encoder_destroy(any)).called(1);
    });

    test('destroy is called even when stream errors', () async {
      stubEncoderCreate();
      when(mockEncoder.opus_encoder_destroy(any)).thenReturn(null);

      final encoder = StreamOpusEncoder.s16le(
        frameTime: _frameTime,
        sampleRate: _sampleRate,
        channels: _channels,
        application: Application.voip,
        fillUpLastFrame: false,
      );

      // Partial frame triggers UnfinishedFrameException
      try {
        await encoder
            .bind(Stream.value(Int16List(_samplesPerFrame ~/ 2)))
            .toList();
      } catch (_) {}

      verify(mockEncoder.opus_encoder_destroy(any)).called(1);
    });

    test('copyOutput=true returns a copy of the output buffer', () async {
      stubEncoderCreate();
      stubEncode([0x11, 0x22]);

      final encoder = StreamOpusEncoder.s16le(
        frameTime: _frameTime,
        sampleRate: _sampleRate,
        channels: _channels,
        application: Application.voip,
        copyOutput: true,
      );

      final packets = await encoder
          .bind(Stream.value(Int16List(_samplesPerFrame)))
          .toList();

      expect(packets[0], [0x11, 0x22]);
    });

    test('copyOutput=false yields buffer without copying', () async {
      stubEncoderCreate();
      stubEncode([0x33, 0x44]);

      final encoder = StreamOpusEncoder.s16le(
        frameTime: _frameTime,
        sampleRate: _sampleRate,
        channels: _channels,
        application: Application.voip,
        copyOutput: false,
      );

      final packets = await encoder
          .bind(Stream.value(Int16List(_samplesPerFrame)))
          .toList();

      // With copyOutput=false all yielded lists share the same native buffer,
      // so we can only verify the count and type — content is overwritten by
      // the trailing flush.
      expect(packets, hasLength(2));
      expect(packets[0], isA<Uint8List>());
    });
  });

  // ---------------------------------------------------------------------------
  // StreamOpusEncoder.float — bind()
  // ---------------------------------------------------------------------------

  group('StreamOpusEncoder.float bind()', () {
    test('exact float frame calls encodeFloat and emits frame + flush',
        () async {
      stubEncoderCreate();
      stubEncodeFloat([0xFF, 0xEE]);

      final encoder = StreamOpusEncoder.float(
        frameTime: _frameTime,
        sampleRate: _sampleRate,
        channels: _channels,
        application: Application.voip,
      );

      final input = Float32List(_samplesPerFrame);
      final packets = await encoder.bind(Stream.value(input)).toList();

      // 1 encode during streaming + 1 trailing silence flush = 2
      expect(packets, hasLength(2));
      expect(packets[0], [0xFF, 0xEE]);
      verify(mockEncoder.opus_encode_float(
              any, any, _samplesPerFrame, any, any))
          .called(2);
      verifyNever(mockEncoder.opus_encode(any, any, any, any, any));
    });

    test('partial float frame with fillUpLastFrame=false throws', () async {
      stubEncoderCreate();

      final encoder = StreamOpusEncoder.float(
        frameTime: _frameTime,
        sampleRate: _sampleRate,
        channels: _channels,
        application: Application.voip,
        fillUpLastFrame: false,
      );

      final half = Float32List(_samplesPerFrame ~/ 2);
      await expectLater(
        encoder.bind(Stream.value(half)).toList(),
        throwsA(isA<UnfinishedFrameException>()),
      );
    });

    test('partial float frame with fillUpLastFrame=true pads and yields',
        () async {
      stubEncoderCreate();
      stubEncodeFloat([0xAB]);

      final encoder = StreamOpusEncoder.float(
        frameTime: _frameTime,
        sampleRate: _sampleRate,
        channels: _channels,
        application: Application.voip,
        fillUpLastFrame: true,
      );

      final half = Float32List(_samplesPerFrame ~/ 2);
      final packets = await encoder.bind(Stream.value(half)).toList();

      expect(packets, hasLength(1));
      verify(mockEncoder.opus_encode_float(any, any, any, any, any)).called(1);
    });

    test('copyOutput=false with float encoder yields buffer directly',
        () async {
      stubEncoderCreate();
      stubEncodeFloat([0xDD]);

      final encoder = StreamOpusEncoder.float(
        frameTime: _frameTime,
        sampleRate: _sampleRate,
        channels: _channels,
        application: Application.voip,
        copyOutput: false,
      );

      final input = Float32List(_samplesPerFrame);
      final packets = await encoder.bind(Stream.value(input)).toList();

      expect(packets, hasLength(2));
      expect(packets[0], isA<Uint8List>());
    });

    test('works with FrameTime.ms20', () async {
      stubEncoderCreate();
      stubEncodeFloat([0x01]);

      final encoder = StreamOpusEncoder.float(
        frameTime: FrameTime.ms20,
        sampleRate: _sampleRate,
        channels: _channels,
        application: Application.voip,
      );

      // 8kHz mono @ 20ms = 160 samples
      final input = Float32List(160);
      final packets = await encoder.bind(Stream.value(input)).toList();

      expect(packets, hasLength(2));
      verify(mockEncoder.opus_encode_float(any, any, 160, any, any)).called(2);
    });
  });

  // ---------------------------------------------------------------------------
  // StreamOpusEncoder.bytes — bind()
  // ---------------------------------------------------------------------------

  group('StreamOpusEncoder.bytes bind()', () {
    test('raw s16le bytes frame emits frame packet plus trailing flush',
        () async {
      stubEncoderCreate();
      stubEncode([0x77]);

      final encoder = StreamOpusEncoder.bytes(
        frameTime: _frameTime,
        floatInput: false,
        sampleRate: _sampleRate,
        channels: _channels,
        application: Application.voip,
      );

      final input =
          Uint8List(_s16leFrameBytes); // 160 raw bytes = 1 exact frame
      final packets = await encoder.bind(Stream.value(input)).toList();

      // 1 encode during streaming + 1 trailing flush = 2
      expect(packets, hasLength(2));
      verify(mockEncoder.opus_encode(any, any, any, any, any)).called(2);
    });

    test('raw float bytes frame calls encodeFloat and emits frame + flush',
        () async {
      stubEncoderCreate();
      stubEncodeFloat([0x88]);

      final encoder = StreamOpusEncoder.bytes(
        frameTime: _frameTime,
        floatInput: true,
        sampleRate: _sampleRate,
        channels: _channels,
        application: Application.voip,
      );

      final input =
          Uint8List(_floatFrameBytes); // 320 raw bytes = 1 exact frame
      final packets = await encoder.bind(Stream.value(input)).toList();

      // 1 encode during streaming + 1 trailing flush = 2
      expect(packets, hasLength(2));
      verify(mockEncoder.opus_encode_float(any, any, any, any, any)).called(2);
    });

    test('partial float bytes with fillUpLastFrame=true pads and yields',
        () async {
      stubEncoderCreate();
      stubEncodeFloat([0x99]);

      final encoder = StreamOpusEncoder.bytes(
        frameTime: _frameTime,
        floatInput: true,
        sampleRate: _sampleRate,
        channels: _channels,
        application: Application.voip,
        fillUpLastFrame: true,
      );

      final half = Uint8List(_floatFrameBytes ~/ 2);
      final packets = await encoder.bind(Stream.value(half)).toList();

      expect(packets, hasLength(1));
      verify(mockEncoder.opus_encode_float(any, any, any, any, any)).called(1);
    });

    test('partial float bytes with fillUpLastFrame=false throws', () async {
      stubEncoderCreate();

      final encoder = StreamOpusEncoder.bytes(
        frameTime: _frameTime,
        floatInput: true,
        sampleRate: _sampleRate,
        channels: _channels,
        application: Application.voip,
        fillUpLastFrame: false,
      );

      final half = Uint8List(_floatFrameBytes ~/ 2);
      await expectLater(
        encoder.bind(Stream.value(half)).toList(),
        throwsA(isA<UnfinishedFrameException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // StreamOpusDecoder — properties
  // ---------------------------------------------------------------------------

  group('StreamOpusDecoder properties', () {
    test('.s16le() exposes sampleRate, channels, floats=false', () {
      stubDecoderCreate();
      final decoder = StreamOpusDecoder.s16le(
        sampleRate: _sampleRate,
        channels: _channels,
      );
      expect(decoder.sampleRate, _sampleRate);
      expect(decoder.channels, _channels);
      expect(decoder.floats, isFalse);
      expect(decoder.forwardErrorCorrection, isFalse);
      expect(decoder.autoSoftClip, isFalse);
    });

    test('.float() sets floats=true', () {
      stubDecoderCreate();
      final decoder = StreamOpusDecoder.float(
        sampleRate: _sampleRate,
        channels: _channels,
      );
      expect(decoder.floats, isTrue);
    });

    test('.float() with autoSoftClip=true sets flag', () {
      stubDecoderCreate();
      final decoder = StreamOpusDecoder.float(
        sampleRate: _sampleRate,
        channels: _channels,
        autoSoftClip: true,
      );
      expect(decoder.autoSoftClip, isTrue);
    });

    test('.bytes() with floatOutput=false does not set autoSoftClip', () {
      stubDecoderCreate();
      final decoder = StreamOpusDecoder.bytes(
        floatOutput: false,
        sampleRate: _sampleRate,
        channels: _channels,
        autoSoftClip: true,
      );
      expect(decoder.autoSoftClip, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // StreamOpusDecoder.s16le — bind()
  // ---------------------------------------------------------------------------

  group('StreamOpusDecoder.s16le bind()', () {
    test('one packet emits one Int16List', () async {
      stubDecoderCreate();
      stubDecode([100, 200, 300]);

      final decoder = StreamOpusDecoder.s16le(
        sampleRate: _sampleRate,
        channels: _channels,
      );

      final packet = Uint8List.fromList([0x01, 0x02]);
      final results = await decoder.bind(Stream.value(packet)).toList();

      expect(results, hasLength(1));
      expect(results[0], isA<Int16List>());
      expect(results[0], [100, 200, 300]);
    });

    test('two packets emit two Int16Lists', () async {
      stubDecoderCreate();
      stubDecode([10, 20]);

      final decoder = StreamOpusDecoder.s16le(
        sampleRate: _sampleRate,
        channels: _channels,
      );

      final packet = Uint8List.fromList([0x01]);
      final results =
          await decoder.bind(Stream.fromIterable([packet, packet])).toList();

      expect(results, hasLength(2));
      verify(mockDecoder.opus_decode(any, any, any, any, any, any)).called(2);
    });

    test('decode error propagates as OpusException in stream', () async {
      stubDecoderCreate();
      when(mockDecoder.opus_decode(any, any, any, any, any, any))
          .thenReturn(OPUS_INVALID_PACKET);

      final decoder = StreamOpusDecoder.s16le(
        sampleRate: _sampleRate,
        channels: _channels,
      );

      await expectLater(
        decoder.bind(Stream.value(Uint8List.fromList([0x01]))).toList(),
        throwsA(isA<OpusException>()),
      );
    });

    test('null first packet (no FEC) propagates StateError', () async {
      stubDecoderCreate();

      final decoder = StreamOpusDecoder.s16le(
        sampleRate: _sampleRate,
        channels: _channels,
        forwardErrorCorrection: false,
      );

      // No prior packet → lastPacketDurationMs is null → StateError
      await expectLater(
        decoder.bind(Stream.value(null)).toList(),
        throwsA(isA<StateError>()),
      );
    });

    test('null packet after successful decode uses lastPacketDurationMs',
        () async {
      stubDecoderCreate();
      stubDecode([1, 2]);

      final decoder = StreamOpusDecoder.s16le(
        sampleRate: _sampleRate,
        channels: _channels,
        forwardErrorCorrection: false,
      );

      // Normal packet sets lastPacketDurationMs; null uses it for loss
      final packet = Uint8List.fromList([0x01]);
      final results =
          await decoder.bind(Stream.fromIterable([packet, null])).toList();

      // Only the first packet yields output; null triggers loss decode but
      // the result is discarded (no yield on packet loss)
      expect(results, hasLength(1));
      verify(mockDecoder.opus_decode(any, any, any, any, any, any)).called(2);
    });

    test('null packet does not emit output', () async {
      stubDecoderCreate();
      stubDecode([1]);

      final decoder = StreamOpusDecoder.s16le(
        sampleRate: _sampleRate,
        channels: _channels,
      );

      final packet = Uint8List.fromList([0x01]);
      final results =
          await decoder.bind(Stream.fromIterable([packet, null])).toList();

      // null is packet loss — no yield for it
      expect(results, hasLength(1));
    });

    test('consecutive nulls without FEC call loss decode for each', () async {
      stubDecoderCreate();
      stubDecode([1]);

      final decoder = StreamOpusDecoder.s16le(
        sampleRate: _sampleRate,
        channels: _channels,
        forwardErrorCorrection: false,
      );

      final packet = Uint8List.fromList([0x01]);
      final results = await decoder
          .bind(Stream.fromIterable([packet, null, null]))
          .toList();

      expect(results, hasLength(1));
      // 1 normal + 2 loss decodes = 3
      verify(mockDecoder.opus_decode(any, any, any, any, any, any)).called(3);
    });

    test('copyOutput=false yields buffer directly', () async {
      stubDecoderCreate();
      stubDecode([42, 43]);

      final decoder = StreamOpusDecoder.s16le(
        sampleRate: _sampleRate,
        channels: _channels,
        copyOutput: false,
      );

      final packet = Uint8List.fromList([0x01]);
      final results = await decoder.bind(Stream.value(packet)).toList();

      expect(results, hasLength(1));
      expect(results[0], isA<Int16List>());
    });
  });

  // ---------------------------------------------------------------------------
  // StreamOpusDecoder.float — bind()
  // ---------------------------------------------------------------------------

  group('StreamOpusDecoder.float bind()', () {
    test('packet emits Float32List', () async {
      stubDecoderCreate();
      stubDecodeFloat([0.5, -0.25]);

      final decoder = StreamOpusDecoder.float(
        sampleRate: _sampleRate,
        channels: _channels,
      );

      final packet = Uint8List.fromList([0x01, 0x02]);
      final results = await decoder.bind(Stream.value(packet)).toList();

      expect(results, hasLength(1));
      expect(results[0], isA<Float32List>());
      expect((results[0] as Float32List)[0], closeTo(0.5, 0.001));
      expect((results[0] as Float32List)[1], closeTo(-0.25, 0.001));
    });

    test('autoSoftClip calls opus_pcm_soft_clip per packet', () async {
      stubDecoderCreate();
      stubDecodeFloat([0.5]);
      when(mockDecoder.opus_pcm_soft_clip(any, any, any, any)).thenReturn(null);

      final decoder = StreamOpusDecoder.float(
        sampleRate: _sampleRate,
        channels: _channels,
        autoSoftClip: true,
      );

      final packet = Uint8List.fromList([0x01]);
      await decoder.bind(Stream.fromIterable([packet, packet])).toList();

      verify(mockDecoder.opus_pcm_soft_clip(any, any, any, any)).called(2);
    });

    test('without autoSoftClip does not call opus_pcm_soft_clip', () async {
      stubDecoderCreate();
      stubDecodeFloat([0.5]);

      final decoder = StreamOpusDecoder.float(
        sampleRate: _sampleRate,
        channels: _channels,
        autoSoftClip: false,
      );

      final packet = Uint8List.fromList([0x01]);
      await decoder.bind(Stream.value(packet)).toList();

      verifyNever(mockDecoder.opus_pcm_soft_clip(any, any, any, any));
    });

    test('null packet (no FEC) reports loss via decodeFloat', () async {
      stubDecoderCreate();
      stubDecodeFloat([0.1]);

      final decoder = StreamOpusDecoder.float(
        sampleRate: _sampleRate,
        channels: _channels,
        forwardErrorCorrection: false,
      );

      final packet = Uint8List.fromList([0x01]);
      final results =
          await decoder.bind(Stream.fromIterable([packet, null])).toList();

      expect(results, hasLength(1));
      verify(mockDecoder.opus_decode_float(any, any, any, any, any, any))
          .called(2);
    });

    test('null first packet (no FEC) with float propagates StateError',
        () async {
      stubDecoderCreate();

      final decoder = StreamOpusDecoder.float(
        sampleRate: _sampleRate,
        channels: _channels,
        forwardErrorCorrection: false,
      );

      await expectLater(
        decoder.bind(Stream.value(null)).toList(),
        throwsA(isA<StateError>()),
      );
    });

    test('copyOutput=false yields buffer directly', () async {
      stubDecoderCreate();
      stubDecodeFloat([0.5]);

      final decoder = StreamOpusDecoder.float(
        sampleRate: _sampleRate,
        channels: _channels,
        copyOutput: false,
      );

      final packet = Uint8List.fromList([0x01]);
      final results = await decoder.bind(Stream.value(packet)).toList();

      expect(results, hasLength(1));
      expect(results[0], isA<Float32List>());
    });
  });

  // ---------------------------------------------------------------------------
  // StreamOpusDecoder.bytes — bind()
  // ---------------------------------------------------------------------------

  group('StreamOpusDecoder.bytes bind()', () {
    test('s16le bytes packet emits Uint8List', () async {
      stubDecoderCreate();
      stubDecode([300, 400]);

      final decoder = StreamOpusDecoder.bytes(
        floatOutput: false,
        sampleRate: _sampleRate,
        channels: _channels,
      );

      final packet = Uint8List.fromList([0x01]);
      final results = await decoder.bind(Stream.value(packet)).toList();

      expect(results, hasLength(1));
      expect(results[0], isA<Uint8List>());
      // 2 samples * 2 bytes/sample = 4 bytes
      expect(results[0].length, 4);
    });

    test('float bytes packet emits Uint8List', () async {
      stubDecoderCreate();
      stubDecodeFloat([0.1, 0.2]);

      final decoder = StreamOpusDecoder.bytes(
        floatOutput: true,
        sampleRate: _sampleRate,
        channels: _channels,
      );

      final packet = Uint8List.fromList([0x01]);
      final results = await decoder.bind(Stream.value(packet)).toList();

      expect(results, hasLength(1));
      expect(results[0], isA<Uint8List>());
      // 2 float samples * 4 bytes/sample = 8 bytes
      expect(results[0].length, 8);
    });

    test('bytes with floatOutput=true and autoSoftClip=true calls soft clip',
        () async {
      stubDecoderCreate();
      stubDecodeFloat([0.5]);
      when(mockDecoder.opus_pcm_soft_clip(any, any, any, any)).thenReturn(null);

      final decoder = StreamOpusDecoder.bytes(
        floatOutput: true,
        sampleRate: _sampleRate,
        channels: _channels,
        autoSoftClip: true,
      );

      expect(decoder.autoSoftClip, isTrue);

      final packet = Uint8List.fromList([0x01]);
      await decoder.bind(Stream.value(packet)).toList();

      verify(mockDecoder.opus_pcm_soft_clip(any, any, any, any)).called(1);
    });
  });

  // ---------------------------------------------------------------------------
  // StreamOpusDecoder — forward error correction
  // ---------------------------------------------------------------------------

  group('StreamOpusDecoder forwardErrorCorrection', () {
    test('null first packet does not throw with FEC enabled', () async {
      stubDecoderCreate();

      final decoder = StreamOpusDecoder.s16le(
        sampleRate: _sampleRate,
        channels: _channels,
        forwardErrorCorrection: true,
      );

      // With FEC, first null just sets _lastPacketLost=true, no decode called
      final results = await decoder.bind(Stream.value(null)).toList();

      expect(results, isEmpty);
      verifyNever(mockDecoder.opus_decode(any, any, any, any, any, any));
    });

    test('packet after null with FEC decodes twice (FEC + normal)', () async {
      stubDecoderCreate();
      stubDecode([10, 20]);

      final decoder = StreamOpusDecoder.s16le(
        sampleRate: _sampleRate,
        channels: _channels,
        forwardErrorCorrection: true,
      );

      final packet = Uint8List.fromList([0x01, 0x02]);
      final stream = Stream.fromIterable(<Uint8List?>[packet, null, packet]);
      final results = await decoder.bind(stream).toList();

      // First packet: 1 decode → 1 output
      // null: no decode, no output
      // Second packet: FEC decode + normal decode → 2 outputs
      expect(results, hasLength(3));
      verify(mockDecoder.opus_decode(any, any, any, any, any, any)).called(3);
    });

    test('two consecutive nulls with FEC reports first loss on second null',
        () async {
      stubDecoderCreate();
      stubDecode([10]);

      final decoder = StreamOpusDecoder.s16le(
        sampleRate: _sampleRate,
        channels: _channels,
        forwardErrorCorrection: true,
      );

      // packet → decode(normal)
      // null   → _lastPacketLost=true, no decode
      // null   → _lastPacketLost=true → _reportPacketLoss → decode(loss)
      // packet → FEC decode + normal decode
      final packet = Uint8List.fromList([0x01]);
      final stream =
          Stream.fromIterable(<Uint8List?>[packet, null, null, packet]);
      final results = await decoder.bind(stream).toList();

      // packet1 → 1 output
      // null1   → 0 outputs
      // null2   → _reportPacketLoss (no yield) → 0 outputs
      // packet2 → FEC + normal → 2 outputs
      expect(results, hasLength(3));
      // decode called: 1 (packet1) + 1 (_reportPacketLoss) + 1 (FEC) + 1 (normal) = 4
      verify(mockDecoder.opus_decode(any, any, any, any, any, any)).called(4);
    });

    test('FEC decode uses fec=true flag', () async {
      stubDecoderCreate();

      final calls = <int>[]; // capture fec argument (5th positional = index 5)
      when(mockDecoder.opus_decode(any, any, any, any, any, any))
          .thenAnswer((inv) {
        calls.add(inv.positionalArguments[5] as int);
        return 1;
      });

      final decoder = StreamOpusDecoder.s16le(
        sampleRate: _sampleRate,
        channels: _channels,
        forwardErrorCorrection: true,
      );

      final packet = Uint8List.fromList([0x01]);
      final stream = Stream.fromIterable(<Uint8List?>[packet, null, packet]);
      await decoder.bind(stream).toList();

      // calls: [0 (first packet), 1 (FEC for second packet), 0 (second packet normal)]
      expect(calls, [0, 1, 0]);
    });

    test('float decoder with FEC decodes via decodeFloat with fec=true',
        () async {
      stubDecoderCreate();

      final fecArgs = <int>[];
      when(mockDecoder.opus_decode_float(any, any, any, any, any, any))
          .thenAnswer((inv) {
        fecArgs.add(inv.positionalArguments[5] as int);
        return 1;
      });

      final decoder = StreamOpusDecoder.float(
        sampleRate: _sampleRate,
        channels: _channels,
        forwardErrorCorrection: true,
      );

      final packet = Uint8List.fromList([0x01]);
      final stream = Stream.fromIterable(<Uint8List?>[packet, null, packet]);
      await decoder.bind(stream).toList();

      // fecArgs: [0 (normal), 1 (FEC recovery), 0 (normal)]
      expect(fecArgs, [0, 1, 0]);
      verifyNever(mockDecoder.opus_decode(any, any, any, any, any, any));
    });

    test(
        'float decoder with FEC and consecutive nulls reports loss via decodeFloat',
        () async {
      stubDecoderCreate();
      stubDecodeFloat([0.1]);

      final decoder = StreamOpusDecoder.float(
        sampleRate: _sampleRate,
        channels: _channels,
        forwardErrorCorrection: true,
      );

      final packet = Uint8List.fromList([0x01]);
      final stream =
          Stream.fromIterable(<Uint8List?>[packet, null, null, packet]);
      final results = await decoder.bind(stream).toList();

      // packet → normal(1), null → no decode, null → loss decode(1),
      // packet → FEC(1) + normal(1) = 4 decodeFloat calls total
      expect(results, hasLength(3));
      verify(mockDecoder.opus_decode_float(any, any, any, any, any, any))
          .called(4);
    });
  });
}
