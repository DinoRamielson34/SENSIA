import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/haptics/haptic_engine.dart';
import 'package:izahay/haptics/segment_pattern.dart';
import 'package:izahay/models/vibration_segment.dart';
import 'package:izahay/services/sound_haptic_pipeline.dart';

import '../haptics/fake_vibration_executor.dart';

void main() {
  test('un motif personnalisé remplace celui joué pour la catégorie', () async {
    final executor = FakeVibrationExecutor();
    final pipeline = SoundHapticPipeline(
      hapticEngine: HapticEngine(executor: executor),
    );

    // Avant : motif par défaut du train (très longue + 2 courtes).
    await pipeline.testVibration('train');
    expect(executor.vibrateCalls.last, [0, 900, 150, 150, 150, 150, 0]);

    pipeline.setCategoryPattern(
      'train',
      patternFromSegments('train', [VibrationSegment.short]),
    );

    await pipeline.testVibration('train');
    expect(executor.vibrateCalls.last, [0, 150, 0]);
    expect(pipeline.patternFor('train')!.pulses.length, 1);
    // Les autres catégories ne changent pas.
    expect(pipeline.patternFor('doorbell')!.pulses.length, 2);
  });
}
