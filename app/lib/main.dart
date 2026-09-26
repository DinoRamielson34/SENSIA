import 'package:flutter/material.dart';
import 'screens/detection_test_screen.dart';

void main() => runApp(const IzahayApp());

class IzahayApp extends StatelessWidget {
  const IzahayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SENSIA',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const DetectionTestScreen(),
    );
  }
}

/// Écran placeholder (compteur de taps), conservé pour le test widget.
class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IZAHAY')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone_android, size: 72),
            const SizedBox(height: 16),
            const Text('Application de test IZAHAY',
                style: TextStyle(fontSize: 22)),
            const SizedBox(height: 12),
            Text('Bouton pressé : $_taps fois'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => setState(() => _taps++),
              child: const Text('Tester'),
            ),
          ],
        ),
      ),
    );
  }
}
