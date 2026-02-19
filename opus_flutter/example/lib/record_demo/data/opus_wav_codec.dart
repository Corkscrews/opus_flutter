import 'dart:convert';
import 'dart:typed_data';

import 'package:opus_dart/opus_dart.dart';

import '../core/audio_constants.dart';

class OpusWavCodec {
  static Future<Uint8List> decodePacketsToWav(List<Uint8List> packets) async {
    final output = <Uint8List>[Uint8List(demoWavHeaderSize)];

    await Stream<Uint8List?>.fromIterable(packets)
        .transform(StreamOpusDecoder.bytes(
          floatOutput: false,
          sampleRate: demoSampleRate,
          channels: demoChannels,
          copyOutput: true,
        ))
        .cast<Uint8List>()
        .forEach(output.add);

    final fileSize = output.fold<int>(0, (sum, chunk) => sum + chunk.length);
    output[0] = _buildWavHeader(
      channels: demoChannels,
      sampleRate: demoSampleRate,
      fileSize: fileSize,
    );

    final wavBytes = Uint8List(fileSize);
    var index = 0;
    for (final chunk in output) {
      wavBytes.setAll(index, chunk);
      index += chunk.length;
    }
    return wavBytes;
  }

  static Uint8List _buildWavHeader({
    required int sampleRate,
    required int channels,
    required int fileSize,
  }) {
    const endian = Endian.little;
    final frameSize = ((demoSampleBits + 7) ~/ 8) * channels;
    final data = ByteData(demoWavHeaderSize);
    data.setUint32(4, fileSize - 4, endian);
    data.setUint32(16, 16, endian);
    data.setUint16(20, 1, endian);
    data.setUint16(22, channels, endian);
    data.setUint32(24, sampleRate, endian);
    data.setUint32(28, sampleRate * frameSize, endian);
    data.setUint16(30, frameSize, endian);
    data.setUint16(34, demoSampleBits, endian);
    data.setUint32(40, fileSize - 44, endian);
    final header = data.buffer.asUint8List();
    header.setAll(0, ascii.encode('RIFF'));
    header.setAll(8, ascii.encode('WAVE'));
    header.setAll(12, ascii.encode('fmt '));
    header.setAll(36, ascii.encode('data'));
    return header;
  }
}
