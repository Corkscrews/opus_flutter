import 'package:flutter/material.dart';

import '../presentation/screens/record_and_playback_screen.dart';

const opusampBlack = Color(0xFF1E1E1E);
const opusampDarkGray = Color(0xFF2B2B2B);
const opusampMidGray = Color(0xFF3A3A3A);
const opusampLightGray = Color(0xFF4A4A4A);
const opusampGreen = Color(0xFF00E000);
const opusampGreenDim = Color(0xFF007800);
const opusampAmber = Color(0xFFE8A317);
const opusampRed = Color(0xFFE03030);

class RecordAndPlaybackAppWidget extends StatelessWidget {
  const RecordAndPlaybackAppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: false,
        scaffoldBackgroundColor: opusampBlack,
        fontFamily: 'Courier',
        colorScheme: const ColorScheme.dark(
          primary: opusampGreen,
          surface: opusampDarkGray,
          onSurface: opusampGreen,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: opusampBlack,
          foregroundColor: opusampGreen,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: opusampGreen,
            fontFamily: 'Courier',
            letterSpacing: 1.2,
          ),
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('OPUS_FLUTTER'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF3A3A3A), Color(0xFF1A1A1A)],
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFF555555), width: 1),
              ),
            ),
          ),
        ),
        body: const SafeArea(child: RecordAndPlaybackScreenWidget()),
      ),
    );
  }
}
