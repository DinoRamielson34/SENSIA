import 'package:flutter/material.dart';

import 'haptics/haptic_engine.dart';
import 'haptics/haptic_exceptions.dart';
import 'haptics/vibration_executor.dart';

/// Point d'entrée séparé pour tester le moteur de vibrations manuellement,
/// sans dépendre de la reconnaissance sonore ni de l'application principale.
///
/// Lancer avec : flutter run -t lib/haptics_debug_main.dart
void main() {
  runApp(
    HapticsDebugApp(
      engine: HapticEngine(executor: const MethodChannelVibrationExecutor()),
    ),
  );
}

class HapticsDebugApp extends StatelessWidget {
  final HapticEngine engine;

  const HapticsDebugApp({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IZAHAY — Test moteur haptique',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: HapticsDebugScreen(engine: engine),
    );
  }
}

class HapticsDebugScreen extends StatefulWidget {
  final HapticEngine engine;

  const HapticsDebugScreen({super.key, required this.engine});

  @override
  State<HapticsDebugScreen> createState() => _HapticsDebugScreenState();
}

class _HapticsDebugScreenState extends State<HapticsDebugScreen> {
  static const _categories = ['sonnette', 'aboiement'];

  String _status = '';

  Future<void> _play(String category) async {
    try {
      await widget.engine.playForCategory(category);
      setState(() => _status = 'Motif "$category" déclenché');
    } on HapticUnsupportedException {
      setState(() => _status = 'Appareil sans vibreur');
    } on InvalidVibrationPatternException catch (e) {
      setState(() => _status = 'Motif invalide : ${e.message}');
    } on HapticPlatformException catch (e) {
      setState(() => _status = 'Erreur native : ${e.message}');
    }
  }

  Future<void> _stop() async {
    await widget.engine.stop();
    setState(() => _status = 'Vibration arrêtée');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test moteur haptique')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final category in _categories)
              Padding(
                padding: const EdgeInsets.all(8),
                child: FilledButton(
                  onPressed: () => _play(category),
                  child: Text('Tester "$category"'),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: OutlinedButton(
                onPressed: _stop,
                child: const Text('Arrêter'),
              ),
            ),
            const SizedBox(height: 16),
            Text(_status),
          ],
        ),
      ),
    );
  }
}
