import 'dart:convert';
import 'dart:math' show min;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;
import 'package:opus_dart/opus_dart.dart';
import 'package:share_plus/share_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initOpus(await opus_flutter.load());
  runApp(const OpusFlutter());
}

/// Simulates a chunked byte stream from a bundled raw PCM asset,
/// mimicking the behaviour of a network stream.
Stream<List<int>> _loadRawAudioStream(BuildContext context) async* {
  const portionSize = 65535;
  final data = await DefaultAssetBundle.of(context)
      .load('assets/s16le_16000hz_mono.raw');
  var offset = 0;
  while (offset < data.lengthInBytes) {
    final chunk = min(portionSize, data.lengthInBytes - offset);
    yield data.buffer.asUint8List(data.offsetInBytes + offset, chunk);
    offset += chunk;
    await Future.delayed(const Duration(milliseconds: 10));
  }
}

class OpusFlutter extends StatelessWidget {
  const OpusFlutter({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('opus_flutter')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text('Version: ${getOpusVersion()}'),
              const OpusExample(),
            ],
          ),
        ),
      ),
    );
  }
}

class OpusExample extends StatefulWidget {
  const OpusExample({super.key});

  @override
  State<OpusExample> createState() => _OpusExampleState();
}

class _OpusExampleState extends State<OpusExample> {
  var _processing = false;

  Future<void> _onPressed() async {
    setState(() => _processing = true);
    try {
      final data = await _encodeDecodePcm(_loadRawAudioStream(context));
      await _shareWav(data);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_processing) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [CircularProgressIndicator(), Text('Processing...')],
      );
    }
    return ElevatedButton(
      onPressed: _onPressed,
      child: const Text('Start'),
    );
  }
}

const _sampleRate = 16000;
const _channels = 1;

/// Encodes raw PCM input with Opus then immediately decodes it back,
/// returning a complete WAV file as bytes.
Future<Uint8List> _encodeDecodePcm(Stream<List<int>> input) async {
  final output = <Uint8List>[Uint8List(_wavHeaderSize)];

  await input
      .transform(StreamOpusEncoder.bytes(
        floatInput: false,
        frameTime: FrameTime.ms20,
        sampleRate: _sampleRate,
        channels: _channels,
        application: Application.audio,
        copyOutput: true,
        fillUpLastFrame: true,
      ))
      .cast<Uint8List?>()
      .transform(StreamOpusDecoder.bytes(
        floatOutput: false,
        sampleRate: _sampleRate,
        channels: _channels,
        copyOutput: true,
        forwardErrorCorrection: false,
      ))
      .cast<Uint8List>()
      .forEach(output.add);

  final length = output.fold<int>(0, (sum, chunk) => sum + chunk.length);
  output[0] = _buildWavHeader(
    channels: _channels,
    sampleRate: _sampleRate,
    fileSize: length,
  );

  final flat = Uint8List(length);
  var offset = 0;
  for (final chunk in output) {
    flat.setAll(offset, chunk);
    offset += chunk.length;
  }
  return flat;
}

const _wavHeaderSize = 44;
// Opus always outputs 16-bit PCM in this example.
const _sampleBits = 16;

Uint8List _buildWavHeader({
  required int sampleRate,
  required int channels,
  required int fileSize,
}) {
  const endian = Endian.little;
  final frameSize = ((_sampleBits + 7) ~/ 8) * channels;
  final data = ByteData(_wavHeaderSize);
  data.setUint32(4, fileSize - 4, endian);
  data.setUint32(16, 16, endian);
  data.setUint16(20, 1, endian);
  data.setUint16(22, channels, endian);
  data.setUint32(24, sampleRate, endian);
  data.setUint32(28, sampleRate * frameSize, endian);
  data.setUint16(30, frameSize, endian);
  data.setUint16(34, _sampleBits, endian);
  data.setUint32(40, fileSize - 44, endian);
  final bytes = data.buffer.asUint8List();
  bytes.setAll(0, ascii.encode('RIFF'));
  bytes.setAll(8, ascii.encode('WAVE'));
  bytes.setAll(12, ascii.encode('fmt '));
  bytes.setAll(36, ascii.encode('data'));
  return bytes;
}

Future<void> _shareWav(Uint8List data) async {
  final file = XFile.fromData(
    data,
    mimeType: 'audio/wav',
    name: 'output.wav',
    length: data.length,
  );
  await Share.shareXFiles([file]);
}
