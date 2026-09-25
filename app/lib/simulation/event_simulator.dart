import '../sound_events/sound_event.dart';
import '../sound_events/sound_event_processor.dart';
import '../sound_events/sound_event_result.dart';

/// Génère et transmet des événements sonores simulés au
/// [SoundEventProcessor] existant, exactement comme le ferait le module
/// de reconnaissance sonore (IA). Ne contient aucune règle métier : toute
/// la décision (seuil, confirmation, anti-répétition, déclenchement)
/// reste dans le processor déjà livré et testé.
class EventSimulator {
  final SoundEventProcessor _processor;
  final Future<void> Function(Duration duration) _delay;

  /// Crée un simulateur qui transmettra tous ses événements à
  /// [processor].
  ///
  /// [processor] : le moteur de traitement réel à utiliser — jamais
  /// remplacé ni dupliqué, c'est lui qui applique seuils, confirmation
  /// et anti-répétition.
  ///
  /// [delay] : fonction appelée pour attendre entre deux envois de
  /// [sendSeries]. Par défaut, une vraie attente (`Future.delayed`) ; en
  /// test, remplacer par une fonction qui ne fait rien (voir
  /// `test/simulation/event_simulator_test.dart`) pour éviter toute
  /// attente réelle — les horodatages avancent quand même normalement
  /// (voir [sendSeries]), seule l'attente elle-même est court-circuitée.
  EventSimulator({
    required SoundEventProcessor processor,
    Future<void> Function(Duration duration)? delay,
  })  : _processor = processor,
        _delay = delay ?? _realDelay;

  /// Implémentation par défaut de la temporisation : une vraie attente.
  /// Utilisée quand aucune fonction de délai n'est injectée au
  /// constructeur (donc en dehors des tests).
  static Future<void> _realDelay(Duration duration) =>
      Future<void>.delayed(duration);

  /// Envoie [event] au processor, sans aucune transformation : c'est
  /// exactement l'appel que ferait le module IA en conditions réelles.
  ///
  /// Retourne le [SoundEventResult] produit par le processor. Ne lève
  /// jamais d'exception métier (voir `SoundEventProcessor.process`) :
  /// une catégorie inconnue, désactivée, etc. se traduit par un statut
  /// dans le résultat, jamais par une exception.
  Future<SoundEventResult> send(SoundEvent event) => _processor.process(event);

  /// Construit et envoie [count] événements simulés de [category]/[score],
  /// à intervalle [delay] entre chaque envoi (aucun délai avant le
  /// premier envoi). Chaque événement a `isSimulation: true` — y compris
  /// si [source] vaut `"microphone"` (permet de composer avec le
  /// scénario 7 sans le confondre pour autant avec un vrai événement
  /// microphone, qui a lui `isSimulation: false`, voir
  /// `SimulationScenarios.whileListeningStopped`).
  ///
  /// Paramètres :
  /// - [category]/[score] : identiques pour tous les événements générés.
  /// - [count] : nombre d'événements. `count <= 0` retourne une liste
  ///   vide sans effectuer aucun envoi.
  /// - [delay] : temps simulé entre deux envois (`Duration.zero` par
  ///   défaut = aucun délai). Utilise la fonction de temporisation
  ///   injectée au constructeur ; l'horodatage de chaque événement
  ///   avance de [delay] à chaque tour même si cette fonction n'attend
  ///   pas réellement (voir le commentaire dans le corps de la
  ///   fonction), pour que l'anti-répétition du processor se comporte
  ///   comme sur un vrai appareil.
  /// - [source] : origine déclarée des événements générés (par défaut
  ///   `"simulation"`).
  ///
  /// Retourne les résultats dans l'ordre d'envoi (un par événement).
  /// Effet de bord : chaque envoi peut déclencher une vibration et un
  /// enregistrement d'historique réels, exactement comme [send].
  Future<List<SoundEventResult>> sendSeries({
    required String category,
    required double score,
    required int count,
    Duration delay = Duration.zero,
    String source = 'simulation',
  }) async {
    // L'horodatage de chaque événement avance de [delay] à chaque tour,
    // même quand la fonction de délai injectée n'attend pas réellement
    // (tests). Le processor calcule l'anti-répétition à partir de
    // `event.timestamp`, pas de l'horloge murale : sans cet avancement,
    // une série générée avec un délai factice supérieur au cooldown
    // paraîtrait à tort bloquée par l'anti-répétition, alors qu'un vrai
    // appareil (où le délai s'écoule réellement) laisserait passer
    // chaque événement.
    final start = DateTime.now();
    final results = <SoundEventResult>[];
    for (var i = 0; i < count; i++) {
      if (i > 0 && delay > Duration.zero) {
        await _delay(delay);
      }
      final result = await send(SoundEvent(
        category: category,
        score: score,
        timestamp: start.add(delay * i),
        source: source,
        isSimulation: true,
      ));
      results.add(result);
    }
    return results;
  }
}
