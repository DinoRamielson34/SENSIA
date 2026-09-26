import 'package:flutter/material.dart';
import 'screens/microphone_test_screen.dart';

void main() => runApp(const IzahayApp());

class IzahayApp extends StatelessWidget {
  const IzahayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SENSIA',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const MicrophoneTestScreen(),
    );
  }
}
