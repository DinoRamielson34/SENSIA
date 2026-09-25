import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/history/history_result_sink.dart';
import 'package:izahay/history/history_exceptions.dart';
import 'package:izahay/sound_events/sound_event.dart';
import 'package:izahay/sound_events/sound_event_result.dart';

import 'fake_history_repository.dart';

void main() {
  late FakeHistoryRepository repository;
  late HistoryResultSink sink;

  setUp(() {
    repository = FakeHistoryRepository();
    sink = HistoryResultSink(repository: repository);
  });

  SoundEvent event({
    required String category,
    DateTime? timestamp,
    bool isSimulation = false,
  }) {
    return SoundEvent(
      category: category,
      score: 0.9,
      timestamp: timestamp ?? DateTime.utc(2026, 9, 25, 12),
      source: 'microphone',
      isSimulation: isSimulation,
    );
  }

  test('un résultat triggered est enregistré dans le repository', () async {
    final result = SoundEventResult(
      event: event(category: 'sonnette'),
      status: SoundEventStatus.triggered,
      isSimulation: false,
    );

    await sink.record(result);

    final stored = await repository.fetchEvents();
    expect(stored, hasLength(1));
    expect(stored.single.event.category, 'sonnette');
  });

  test('un résultat non déclenché n\'est jamais enregistré', () async {
    for (final status in SoundEventStatus.values) {
      if (status == SoundEventStatus.triggered) continue;
      final result = SoundEventResult(
        event: event(category: 'sonnette'),
        status: status,
        isSimulation: false,
      );

      await sink.record(result);
    }

    expect(await repository.fetchEvents(), isEmpty);
  });

  test('un événement simulé déclenché est enregistré avec son statut '
      'simulé préservé', () async {
    final result = SoundEventResult(
      event: event(category: 'sonnette', isSimulation: true),
      status: SoundEventStatus.triggered,
      isSimulation: true,
    );

    await sink.record(result);

    final stored = await repository.fetchEvents();
    expect(stored.single.event.isSimulation, isTrue);
  });

  test('enregistrer deux résultats déclenchés distincts produit deux '
      'entrées triées du plus récent au plus ancien, même insérées dans '
      'le désordre', () async {
    final ancien = SoundEventResult(
      event: event(
        category: 'sonnette',
        timestamp: DateTime.utc(2026, 9, 25, 10),
      ),
      status: SoundEventStatus.triggered,
      isSimulation: false,
    );
    final recent = SoundEventResult(
      event: event(
        category: 'aboiement',
        timestamp: DateTime.utc(2026, 9, 25, 14),
      ),
      status: SoundEventStatus.triggered,
      isSimulation: false,
    );

    // Insérés dans le désordre chronologique (le plus récent en premier).
    await sink.record(recent);
    await sink.record(ancien);

    final stored = await repository.fetchEvents();
    expect(stored, hasLength(2));
    expect(stored[0].event.category, 'aboiement');
    expect(stored[1].event.category, 'sonnette');
  });

  test('une erreur du repository propage à travers record()', () async {
    repository.saveEventError = const HistoryWriteException('panne simulée');
    final result = SoundEventResult(
      event: event(category: 'sonnette'),
      status: SoundEventStatus.triggered,
      isSimulation: false,
    );

    await expectLater(
      () => sink.record(result),
      throwsA(isA<HistoryWriteException>()),
    );
  });
}
