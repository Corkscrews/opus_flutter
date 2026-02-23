import 'package:opus_codec/opus_codec.dart' as opus_flutter;
import 'package:flutter/material.dart';
import 'package:opus_codec_dart/opus_codec_dart.dart';

import 'record_demo/app/record_demo_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initOpus(await opus_flutter.load());
  runApp(const RecordAndPlaybackAppWidget());
}
