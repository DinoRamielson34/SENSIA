import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/config/haptic_pattern_config.dart';
import 'package:izahay/haptics/segment_pattern.dart';
import 'package:izahay/models/vibration_segment.dart';

void main() {
  test('long et court donnent 500 ms et 150 ms avec 150 ms de pause', () {
    final pattern = patternFromSegments('x', [
      VibrationSegment.long,
      VibrationSegment.short,
    ]);

    expect(pattern.pulses.map((p) => p.vibrate.inMilliseconds), [500, 150]);
    expect(pattern.pulses.map((p) => p.pauseAfter.inMilliseconds), [150, 0]);
  });

  test('les motifs existants se reconvertissent en long / court', () {
    final babyCry = HapticPatternConfig.patterns['baby_cry']!;
    expect(segmentsFromPattern(babyCry), [
      VibrationSegment.long,
      VibrationSegment.short,
      VibrationSegment.long,
    ]);
    // Klaxon : une seule impulsion très longue.
    expect(segmentsFromPattern(HapticPatternConfig.patterns['car_horn']!), [
      VibrationSegment.long,
    ]);
  });
}
