import 'sound_event.dart';

/// Statut d'issue du traitement d'un [SoundEvent] par [SoundEventProcessor].
/// Aucune de ces valeurs n'est une erreur de programmation : ce sont des
/// issues métier normales, jamais levées comme exceptions.
enum SoundEventStatus {
  /// La vibration a été déclenchée avec succès.
  triggered,

  /// La catégorie n'est pas configurée dans [SoundEventSettings].
  unknownCategory,

  /// La catégorie est configurée mais désactivée par l'utilisateur.
  categoryDisabled,

  /// Le score de l'événement est sous le seuil configuré.
  belowThreshold,

  /// Le nombre de confirmations requises n'est pas encore atteint.
  awaitingConfirmation,

  /// Un déclenchement récent pour cette catégorie bloque celui-ci
  /// (anti-répétition).
  inCooldown,

  /// L'événement vient du microphone alors que l'écoute est arrêtée.
  listeningStopped,

  /// `HapticEngine` a rejeté ou échoué le déclenchement (voir [SoundEventResult.reason]).
  hapticFailure,

  /// Une autre demande (même catégorie ou catégorie différente) a supplanté
  /// celle-ci chez `HapticEngine` ("dernier gagne") avant qu'elle n'ait
  /// réellement vibré. Ce n'est pas un échec : c'est le comportement
  /// attendu quand deux événements arrivent quasi simultanément — mais ce
  /// n'est pas non plus un vrai déclenchement, donc distinct de
  /// [triggered] pour ne pas faire croire à l'utilisateur qu'il a été
  /// alerté, ni démarrer une anti-répétition pour une vibration qui n'a
  /// jamais eu lieu.
  superseded,
}

/// Le verdict du traitement d'un [SoundEvent], exploitable par les autres
/// modules (interface utilisateur, historique) sans qu'ils aient besoin de
/// connaître les règles métier qui l'ont produit.
class SoundEventResult {
  final SoundEvent event;
  final SoundEventStatus status;

  /// Dupliqué depuis `event.isSimulation`, pour que les consommateurs de ce
  /// résultat n'aient pas besoin de redescendre dans l'événement d'origine
  /// pour distinguer réel/simulé.
  final bool isSimulation;

  /// Détail lisible, notamment renseigné pour [SoundEventStatus.hapticFailure].
  final String? reason;

  const SoundEventResult({
    required this.event,
    required this.status,
    required this.isSimulation,
    this.reason,
  });
}
