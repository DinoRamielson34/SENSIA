import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/haptics/haptic_exceptions.dart';
import 'package:izahay/haptics/models/vibration_pattern.dart';
import 'package:izahay/haptics/pattern_validator.dart';

void main() {
  const validator = PatternValidator();

  test('accepte un motif avec au moins une impulsion valide', () {
    const pattern = VibrationPattern(
      id: 'test',
      pulses: [VibrationPulse(vibrate: Duration(milliseconds: 100))],
    );
    expect(() => validator.validate(pattern), returnsNormally);
  });

  test('rejette un motif sans impulsion', () {
    const pattern = VibrationPattern(id: 'vide', pulses: []);
    expect(
      () => validator.validate(pattern),
      throwsA(isA<InvalidVibrationPatternException>()),
    );
  });

  test('rejette une durée de vibration nulle', () {
    const pattern = VibrationPattern(
      id: 'nul',
      pulses: [VibrationPulse(vibrate: Duration.zero)],
    );
    expect(
      () => validator.validate(pattern),
      throwsA(isA<InvalidVibrationPatternException>()),
    );
  });

  test('rejette une durée de vibration négative', () {
    const pattern = VibrationPattern(
      id: 'negatif',
      pulses: [VibrationPulse(vibrate: Duration(milliseconds: -1))],
    );
    expect(
      () => validator.validate(pattern),
      throwsA(isA<InvalidVibrationPatternException>()),
    );
  });

  test('rejette une pause négative', () {
    const pattern = VibrationPattern(
      id: 'pause-negative',
      pulses: [
        VibrationPulse(
          vibrate: Duration(milliseconds: 100),
          pauseAfter: Duration(milliseconds: -1),
        ),
      ],
    );
    expect(
      () => validator.validate(pattern),
      throwsA(isA<InvalidVibrationPatternException>()),
    );
  });
}
