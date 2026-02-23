# opus_codec_example

The original demo entrypoint is kept in `lib/main.dart`.

To run the recording demo that captures microphone PCM with `record`, writes
Opus packets to disk, decodes them back with `opus_codec_dart`, and plays the result:

```bash
flutter run -t lib/main_record_demo.dart
```