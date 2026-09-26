import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/sound_events/sound_event.dart';
import 'package:izahay/sound_events/sound_event_result.dart';

void main() {
  test('SoundEventResult expose event, status, isSimulation et reason', () {
    final event = SoundEvent(
      category: 'sonnette',
      score: 0.9,
      timestamp: DateTime.utc(2026, 9, 25),
      source: 'microphone',
      isSimulation: false,
    );
    final result = SoundEventResult(
      event: event,
      status: SoundEventStatus.hapticFailure,
      isSimulation: false,
      reason: 'panne simulée',
    );

    expect(result.event, same(event));
    expect(result.status, SoundEventStatus.hapticFailure);
    expect(result.isSimulation, isFalse);
    expect(result.reason, 'panne simulée');
  });

  test('reason est optionnel (null par défaut)', () {
    final event = SoundEvent(
      category: 'sonnette',
      score: 0.9,
      timestamp: DateTime.utc(2026, 9, 25),
      source: 'microphone',
      isSimulation: false,
    );
    final result = SoundEventResult(
      event: event,
      status: SoundEventStatus.triggered,
      isSimulation: false,
    );

    expect(result.reason, isNull);
  });
}
