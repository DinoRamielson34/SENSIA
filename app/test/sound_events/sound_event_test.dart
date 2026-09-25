import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/sound_events/sound_event.dart';

void main() {
  test('SoundEvent expose tous les champs du contrat', () {
    final timestamp = DateTime.utc(2026, 9, 25, 14, 30);
    final event = SoundEvent(
      category: 'dog_bark',
      score: 0.91,
      timestamp: timestamp,
      source: 'microphone',
      isSimulation: false,
    );

    expect(event.category, 'dog_bark');
    expect(event.score, 0.91);
    expect(event.timestamp, timestamp);
    expect(event.source, 'microphone');
    expect(event.isSimulation, isFalse);
  });
}
