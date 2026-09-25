import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/history/models/sound_event_record.dart';
import 'package:izahay/sound_events/sound_event.dart';

void main() {
  test('SoundEventRecord expose id et event', () {
    final event = SoundEvent(
      category: 'sonnette',
      score: 0.9,
      timestamp: DateTime.utc(2026, 9, 25),
      source: 'microphone',
      isSimulation: false,
    );
    final record = SoundEventRecord(id: 'abc123', event: event);

    expect(record.id, 'abc123');
    expect(record.event, same(event));
  });
}
