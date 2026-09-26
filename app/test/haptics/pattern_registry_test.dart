import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/haptics/haptic_exceptions.dart';
import 'package:izahay/haptics/models/vibration_pattern.dart';
import 'package:izahay/haptics/pattern_registry.dart';

void main() {
  test('contient les motifs par défaut sonnette et aboiement', () {
    final registry = PatternRegistry();
    expect(registry.lookup('sonnette'), isNotNull);
    expect(registry.lookup('aboiement'), isNotNull);
  });

  test('lookup retourne null pour une catégorie inconnue', () {
    final registry = PatternRegistry();
    expect(registry.lookup('inconnue'), isNull);
  });

  test('register ajoute une nouvelle catégorie', () {
    final registry = PatternRegistry();
    const pattern = VibrationPattern(
      id: 'alarme',
      pulses: [VibrationPulse(vibrate: Duration(milliseconds: 200))],
    );
    registry.register('alarme', pattern);
    expect(registry.lookup('alarme'), same(pattern));
  });

  test('register remplace un motif existant', () {
    final registry = PatternRegistry();
    const remplacement = VibrationPattern(
      id: 'sonnette',
      pulses: [VibrationPulse(vibrate: Duration(milliseconds: 999))],
    );
    registry.register('sonnette', remplacement);
    expect(registry.lookup('sonnette'), same(remplacement));
  });

  test('register rejette un motif invalide sans l\'enregistrer', () {
    final registry = PatternRegistry();
    const invalide = VibrationPattern(id: 'invalide', pulses: []);
    expect(
      () => registry.register('invalide', invalide),
      throwsA(isA<InvalidVibrationPatternException>()),
    );
    expect(registry.lookup('invalide'), isNull);
  });
}
