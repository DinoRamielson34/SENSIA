import '../sound_events/history_sink.dart';
import '../sound_events/sound_event_result.dart';
import 'history_repository.dart';
import 'models/sound_event_record.dart';

/// Implémente [HistorySink] côté module historique : convertit chaque
/// [SoundEventResult] réellement déclenché en [SoundEventRecord] et le
/// transmet au [HistoryRepository]. Les résultats non déclenchés (filtrés,
/// supplantés, en échec) ne sont jamais enregistrés : l'utilisateur ne les
/// a jamais vécus, ils n'ont pas leur place dans son historique.
class HistoryResultSink implements HistorySink {
  final HistoryRepository _repository;

  HistoryResultSink({required HistoryRepository repository})
      : _repository = repository;

  /// Lève toute exception du [HistoryRepository] sous-jacent (ex:
  /// [HistoryWriteException]) — c'est à l'appelant (typiquement
  /// [SoundEventProcessor], qui invoque toujours ceci en fire-and-forget)
  /// de décider comment la traiter.
  @override
  Future<void> record(SoundEventResult result) async {
    if (result.status != SoundEventStatus.triggered) return;
    final record = SoundEventRecord(
      id: _repository.newEventId(),
      event: result.event,
    );
    await _repository.saveEvent(record);
  }
}
