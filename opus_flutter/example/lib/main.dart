import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;
import 'package:flutter/material.dart';
import 'package:opus_dart/opus_dart.dart';

import 'record_demo/app/record_demo_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initOpus(await opus_flutter.load());
  runApp(const RecordAndPlaybackAppWidget());
}
