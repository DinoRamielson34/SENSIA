// Ce test nécessite un appareil Android physique avec un vibreur : il ne
// peut pas être vérifié de façon fiable sur un émulateur (le moteur haptique
// n'est généralement pas simulé) ni en CI.
//
// Exécution : flutter test integration_test/haptics_manual_test.dart
//   (nécessite un appareil connecté, voir `flutter devices`)
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:izahay/haptics/haptic_engine.dart';
import 'package:izahay/haptics/models/vibration_pattern.dart';
import 'package:izahay/haptics/vibration_executor.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Moteur de vibrations sur appareil physique', () {
    late HapticEngine engine;

    setUp(() {
      engine = HapticEngine(
        executor: const MethodChannelVibrationExecutor(),
      );
    });

    testWidgets('l\'appareil de test est compatible', (tester) async {
      expect(await engine.isDeviceCompatible(), isTrue);
    });

    testWidgets('joue le motif "sonnette" sans erreur', (tester) async {
      await engine.playForCategory('sonnette');
    });

    testWidgets('joue un motif personnalisé avec plusieurs pauses sans '
        'erreur', (tester) async {
      const pattern = VibrationPattern(
        id: 'personnalise',
        pulses: [
          VibrationPulse(
            vibrate: Duration(milliseconds: 100),
            pauseAfter: Duration(milliseconds: 100),
          ),
          VibrationPulse(vibrate: Duration(milliseconds: 300)),
        ],
      );
      await engine.playPattern(pattern);
    });

    testWidgets('stop arrête une vibration en cours sans erreur',
        (tester) async {
      const longPattern = VibrationPattern(
        id: 'longue',
        pulses: [VibrationPulse(vibrate: Duration(seconds: 3))],
      );
      unawaited(engine.playPattern(longPattern));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await engine.stop();
    });
  });
}
