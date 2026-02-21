import 'dart:typed_data';

import 'recording_storage.dart';

class OpusPacketFile {
  static void writeLengthPrefixedPacket(
      RecordingDataSink sink, Uint8List packet) {
    final header = ByteData(4)..setUint32(0, packet.length, Endian.little);
    sink.add(header.buffer.asUint8List());
    sink.add(packet);
  }

  static List<Uint8List> readLengthPrefixedPackets(Uint8List bytes) {
    final packets = <Uint8List>[];
    var offset = 0;
    while (offset + 4 <= bytes.lengthInBytes) {
      final packetLength = ByteData.sublistView(bytes, offset, offset + 4)
          .getUint32(0, Endian.little);
      offset += 4;
      if (packetLength == 0 || offset + packetLength > bytes.lengthInBytes) {
        throw const FormatException('Corrupted opus packet stream.');
      }
      packets.add(Uint8List.sublistView(bytes, offset, offset + packetLength));
      offset += packetLength;
    }
    if (offset != bytes.lengthInBytes) {
      throw const FormatException('Trailing bytes after opus packet stream.');
    }
    return packets;
  }
}
