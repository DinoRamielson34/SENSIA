import 'sound_event_result.dart';

/// Point d'extension permettant à [SoundEventProcessor] de transmettre un
/// événement déclenché à un module d'historique (ex: Firebase), sans
/// jamais connaître son implémentation concrète. Défini côté consommateur
/// (`sound_events`) pour que ce module ne dépende jamais de Firebase —
/// seul le module historique l'implémente.
abstract class HistorySink {
  /// Enregistre [result]. L'appelant ([SoundEventProcessor]) invoque
  /// toujours cette méthode en fire-and-forget (jamais attendue) : une
  /// implémentation lente ou en échec ne doit jamais bloquer ni faire
  /// échouer le pipeline de vibration.
  Future<void> record(SoundEventResult result);
}
