import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';

abstract class RecordingDataSink {
  void add(List<int> data);
  Future<void> flush();
  Future<void> close();
}

abstract class RecordingStorage {
  String get label;

  RecordingDataSink openWrite();
  Future<Uint8List> readAsBytes();
  Future<bool> exists();
  Future<void> delete();

  static Future<RecordingStorage> create(String name) async {
    if (kIsWeb) return MemoryRecordingStorage(name);
    final directory = await getApplicationDocumentsDirectory();
    return FileRecordingStorage(File('${directory.path}/$name'));
  }
}

class FileRecordingStorage implements RecordingStorage {
  FileRecordingStorage(this._file);

  final File _file;

  @override
  String get label => _file.path;

  @override
  RecordingDataSink openWrite() =>
      _FileSink(_file.openWrite(mode: FileMode.writeOnlyAppend));

  @override
  Future<Uint8List> readAsBytes() => _file.readAsBytes();

  @override
  Future<bool> exists() => _file.exists();

  @override
  Future<void> delete() => _file.delete().then((_) {});
}

class MemoryRecordingStorage implements RecordingStorage {
  MemoryRecordingStorage(this._name);

  final String _name;
  Uint8List? _data;

  @override
  String get label => _name;

  @override
  RecordingDataSink openWrite() => _MemorySink(this);

  @override
  Future<Uint8List> readAsBytes() async {
    final data = _data;
    if (data == null) throw StateError('No data stored for $_name');
    return data;
  }

  @override
  Future<bool> exists() async => _data != null;

  @override
  Future<void> delete() async => _data = null;
}

class _FileSink implements RecordingDataSink {
  _FileSink(this._sink);

  final IOSink _sink;

  @override
  void add(List<int> data) => _sink.add(data);

  @override
  Future<void> flush() => _sink.flush();

  @override
  Future<void> close() => _sink.close();
}

class _MemorySink implements RecordingDataSink {
  _MemorySink(this._storage);

  final MemoryRecordingStorage _storage;
  final _builder = BytesBuilder(copy: false);

  @override
  void add(List<int> data) => _builder.add(data);

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {
    _storage._data = _builder.takeBytes();
  }
}
