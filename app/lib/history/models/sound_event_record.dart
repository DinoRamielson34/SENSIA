import 'package:izahay/sound_events/sound_event.dart';

/// Un événement sonore persisté : l'identifiant unique généré côté client
/// (voir [HistoryRepository.newEventId]) associé à l'événement d'origine.
/// Composition plutôt que duplication des champs de [SoundEvent].
class SoundEventRecord {
  final String id;
  final SoundEvent event;

  const SoundEventRecord({required this.id, required this.event});
}
