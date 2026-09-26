import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/haptics/models/vibration_pattern.dart';

void main() {
  test('VibrationPulse expose vibrate et pauseAfter (pauseAfter par défaut à zéro)', () {
    const pulse = VibrationPulse(vibrate: Duration(milliseconds: 150));
    expect(pulse.vibrate, const Duration(milliseconds: 150));
    expect(pulse.pauseAfter, Duration.zero);
  });

  test('VibrationPattern expose id et la liste des impulsions', () {
    const pattern = VibrationPattern(
      id: 'sonnette',
      pulses: [
        VibrationPulse(
          vibrate: Duration(milliseconds: 150),
          pauseAfter: Duration(milliseconds: 150),
        ),
      ],
    );
    expect(pattern.id, 'sonnette');
    expect(pattern.pulses, hasLength(1));
    expect(pattern.pulses.single.vibrate, const Duration(milliseconds: 150));
  });
}
