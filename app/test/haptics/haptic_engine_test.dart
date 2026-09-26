import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/haptics/haptic_engine.dart';
import 'package:izahay/haptics/haptic_exceptions.dart';
import 'package:izahay/haptics/models/vibration_pattern.dart';

import 'fake_vibration_executor.dart';

void main() {
  late FakeVibrationExecutor executor;
  late HapticEngine engine;

  setUp(() {
    executor = FakeVibrationExecutor();
    engine = HapticEngine(executor: executor);
  });

  test(
    'playPattern déclenche la vibration avec les bons timings natifs',
    () async {
      const pattern = VibrationPattern(
        id: 'simple',
        pulses: [VibrationPulse(vibrate: Duration(milliseconds: 200))],
      );

      await engine.playPattern(pattern);

      expect(executor.vibrateCalls.single, [0, 200, 0]);
    },
  );

  test('playPattern convertit correctement un motif avec une pause nulle '
      'au milieu de la séquence', () async {
    const pattern = VibrationPattern(
      id: 'pauses-multiples',
      pulses: [
        VibrationPulse(
          vibrate: Duration(milliseconds: 100),
          pauseAfter: Duration(milliseconds: 50),
        ),
        VibrationPulse(vibrate: Duration(milliseconds: 80)),
        VibrationPulse(
          vibrate: Duration(milliseconds: 120),
          pauseAfter: Duration(milliseconds: 60),
        ),
      ],
    );

    await engine.playPattern(pattern);

    expect(executor.vibrateCalls.single, [0, 100, 50, 80, 0, 120, 60]);
  });

  test('playPattern lève InvalidVibrationPatternException pour un motif '
      'invalide et n\'appelle jamais l\'executor', () async {
    const invalide = VibrationPattern(id: 'vide', pulses: []);

    await expectLater(
      () => engine.playPattern(invalide),
      throwsA(isA<InvalidVibrationPatternException>()),
    );
    expect(executor.callLog, isEmpty);
  });

  test('playPattern lève HapticUnsupportedException si l\'appareil n\'a pas '
      'de vibreur et n\'appelle jamais vibrate', () async {
    executor.hasVibratorResult = false;
    const pattern = VibrationPattern(
      id: 'simple',
      pulses: [VibrationPulse(vibrate: Duration(milliseconds: 100))],
    );

    await expectLater(
      () => engine.playPattern(pattern),
      throwsA(isA<HapticUnsupportedException>()),
    );
    expect(executor.vibrateCalls, isEmpty);
  });

  test('playPattern annule toute vibration en cours avant de démarrer la '
      'nouvelle', () async {
    const pattern = VibrationPattern(
      id: 'simple',
      pulses: [VibrationPulse(vibrate: Duration(milliseconds: 100))],
    );

    await engine.playPattern(pattern);

    expect(executor.callLog, ['hasVibrator', 'cancel', 'vibrate']);
  });

  test('stop appelle cancel sur l\'executor', () async {
    await engine.stop();
    expect(executor.callLog, ['cancel']);
  });

  test(
    'registerPattern puis playForCategory joue le motif enregistré',
    () async {
      const pattern = VibrationPattern(
        id: 'alarme',
        pulses: [VibrationPulse(vibrate: Duration(milliseconds: 300))],
      );
      engine.registerPattern('alarme', pattern);

      await engine.playForCategory('alarme');

      expect(executor.vibrateCalls.single, [0, 300, 0]);
    },
  );

  test('playForCategory lève InvalidVibrationPatternException pour une '
      'catégorie inconnue', () async {
    await expectLater(
      () => engine.playForCategory('inconnue'),
      throwsA(isA<InvalidVibrationPatternException>()),
    );
    expect(executor.callLog, isEmpty);
  });

  test(
    'un appel plus récent annule le précédent avant qu\'il ne vibre',
    () async {
      executor.cancelDelay = const Duration(milliseconds: 50);
      const patternA = VibrationPattern(
        id: 'A',
        pulses: [VibrationPulse(vibrate: Duration(milliseconds: 100))],
      );
      const patternB = VibrationPattern(
        id: 'B',
        pulses: [VibrationPulse(vibrate: Duration(milliseconds: 200))],
      );

      final first = engine.playPattern(patternA);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      executor.cancelDelay = Duration.zero;
      final second = engine.playPattern(patternB);

      await Future.wait([first, second]);

      expect(executor.vibrateCalls, [
        [0, 200, 0],
      ]);
    },
  );

  test('un appel plus récent invalide le précédent même pendant sa propre '
      'vérification hasVibrator, avant tout appel à cancel/vibrate', () async {
    executor.hasVibratorDelay = const Duration(milliseconds: 50);
    const patternA = VibrationPattern(
      id: 'A',
      pulses: [VibrationPulse(vibrate: Duration(milliseconds: 100))],
    );
    const patternB = VibrationPattern(
      id: 'B',
      pulses: [VibrationPulse(vibrate: Duration(milliseconds: 200))],
    );

    final first = engine.playPattern(patternA);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    executor.hasVibratorDelay = Duration.zero;
    final second = engine.playPattern(patternB);

    await Future.wait([first, second]);

    expect(executor.vibrateCalls, [
      [0, 200, 0],
    ]);
    // A doit être abandonné dès sa propre vérification hasVibrator, sans
    // jamais appeler cancel() : un seul appel à cancel() (celui de B).
    expect(executor.callLog.where((call) => call == 'cancel'), hasLength(1));
  });

  test('stop() empêche une vibration déjà lancée de démarrer si elle est '
      'encore en attente de vérification de compatibilité', () async {
    executor.hasVibratorDelay = const Duration(milliseconds: 50);
    const pattern = VibrationPattern(
      id: 'simple',
      pulses: [VibrationPulse(vibrate: Duration(milliseconds: 100))],
    );

    final play = engine.playPattern(pattern);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await engine.stop();
    await play;

    expect(executor.vibrateCalls, isEmpty);
  });

  test('playForCategory participe à la même politique "dernier gagne" que '
      'playPattern', () async {
    executor.hasVibratorDelay = const Duration(milliseconds: 50);
    const patternA = VibrationPattern(
      id: 'A',
      pulses: [VibrationPulse(vibrate: Duration(milliseconds: 100))],
    );
    engine.registerPattern('categorie-a', patternA);

    final first = engine.playForCategory('categorie-a');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    executor.hasVibratorDelay = Duration.zero;
    final second = engine.playForCategory('sonnette');

    await Future.wait([first, second]);

    expect(executor.vibrateCalls, hasLength(1));
    expect(executor.vibrateCalls.single, isNot([0, 100, 0]));
  });

  test('playPattern propage une erreur native sans l\'avaler', () async {
    executor.hasVibratorError = const HapticPlatformException('panne simulée');
    const pattern = VibrationPattern(
      id: 'simple',
      pulses: [VibrationPulse(vibrate: Duration(milliseconds: 100))],
    );

    await expectLater(
      () => engine.playPattern(pattern),
      throwsA(isA<HapticPlatformException>()),
    );
  });
}
