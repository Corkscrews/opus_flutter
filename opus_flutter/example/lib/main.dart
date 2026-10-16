import 'package:opus_codec/opus_codec.dart' as opus_flutter;
import 'package:flutter/material.dart';

import 'record_demo/app/record_demo_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await opus_flutter.initializeOpus();
  runApp(const RecordAndPlaybackAppWidget());
}
