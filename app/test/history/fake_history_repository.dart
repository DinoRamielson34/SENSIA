import 'package:izahay/history/history_repository.dart';
import 'package:izahay/history/models/sound_event_record.dart';
import 'package:izahay/sound_events/category_settings.dart';

/// Double de test pour [HistoryRepository] : aucun accès réseau, garde
/// tout en mémoire, permet d'injecter des pannes pour tester la gestion
/// d'erreur des consommateurs.
class FakeHistoryRepository implements HistoryRepository {
  final Map<String, SoundEventRecord> _events = {};
  Map<String, CategorySettings>? _preferences;
  int _nextId = 0;

  /// Si non nul, [saveEvent] lève cette erreur au lieu d'enregistrer.
  Object? saveEventError;

  @override
  String newEventId() => 'fake-${_nextId++}';

  @override
  Future<void> saveEvent(SoundEventRecord record) async {
    final error = saveEventError;
    if (error != null) throw error;
    _events[record.id] = record;
  }

  @override
  Future<List<SoundEventRecord>> fetchEvents({int limit = 100}) async {
    final sorted = _events.values.toList()
      ..sort((a, b) => b.event.timestamp.compareTo(a.event.timestamp));
    return sorted.take(limit).toList();
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    _events.remove(eventId);
  }

  @override
  Future<void> clearHistory() async {
    _events.clear();
  }

  @override
  Future<void> saveVibrationPreferences(
    Map<String, CategorySettings> preferences,
  ) async {
    _preferences = Map.of(preferences);
  }

  @override
  Future<Map<String, CategorySettings>?> fetchVibrationPreferences() async {
    final preferences = _preferences;
    return preferences == null ? null : Map.of(preferences);
  }
}
