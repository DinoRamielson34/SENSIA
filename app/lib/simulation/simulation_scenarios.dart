import '../sound_events/sound_event.dart';

/// Motifs d'événements simulés prêts à l'emploi, correspondant aux 7
/// scénarios de test du simulateur. Aucune fonction ici n'accède au
/// `SoundEventProcessor` ni à aucune règle métier : elles ne font QUE
/// construire des [SoundEvent], toute la décision reste dans le pipeline
/// déjà livré et testé.
class SimulationScenarios {
  const SimulationScenarios._();

  /// Scénario 1 — une sonnette, score confortablement au-dessus du seuil
  /// expérimental par défaut (0.75, voir `CategorySettings`).
  static SoundEvent sonnette({DateTime? timestamp}) => SoundEvent(
        category: 'sonnette',
        score: 0.92,
        timestamp: timestamp ?? DateTime.now(),
        source: 'simulation',
        isSimulation: true,
      );

  /// Scénario 2 — un aboiement, même logique que [sonnette].
  static SoundEvent aboiement({DateTime? timestamp}) => SoundEvent(
        category: 'aboiement',
        score: 0.9,
        timestamp: timestamp ?? DateTime.now(),
        source: 'simulation',
        isSimulation: true,
      );

  /// Scénario 3 — une catégorie que le système ne connaît pas (absente
  /// de `SoundEventSettings`).
  static SoundEvent unknownCategory({
    String category = 'categorie-inconnue-simulee',
    DateTime? timestamp,
  }) =>
      SoundEvent(
        category: category,
        score: 0.95,
        timestamp: timestamp ?? DateTime.now(),
        source: 'simulation',
        isSimulation: true,
      );

  /// Scénario 4 — un score volontairement sous [threshold].
  static SoundEvent belowThreshold(
    String category, {
    double threshold = 0.75,
    DateTime? timestamp,
  }) =>
      SoundEvent(
        category: category,
        score: (threshold - 0.1).clamp(0.0, 1.0),
        timestamp: timestamp ?? DateTime.now(),
        source: 'simulation',
        isSimulation: true,
      );

  /// Scénario 5 — [count] événements identiques successifs (même
  /// catégorie, même score, même horodatage), utile pour tester
  /// l'anti-répétition.
  static List<SoundEvent> repeatedIdentical(
    String category, {
    double score = 0.9,
    int count = 3,
    DateTime? timestamp,
  }) {
    final base = timestamp ?? DateTime.now();
    return List.generate(
      count,
      (_) => SoundEvent(
        category: category,
        score: score,
        timestamp: base,
        source: 'simulation',
        isSimulation: true,
      ),
    );
  }

  /// Scénario 6 — deux catégories différentes détectées au même instant.
  static (SoundEvent, SoundEvent) nearSimultaneousDifferentCategories(
    String categoryA,
    String categoryB, {
    DateTime? timestamp,
  }) {
    final base = timestamp ?? DateTime.now();
    return (
      SoundEvent(
        category: categoryA,
        score: 0.9,
        timestamp: base,
        source: 'simulation',
        isSimulation: true,
      ),
      SoundEvent(
        category: categoryB,
        score: 0.9,
        timestamp: base,
        source: 'simulation',
        isSimulation: true,
      ),
    );
  }

  /// Scénario 7 — un événement `source: "microphone"`, délibérément PAS
  /// simulé : c'est le seul moyen de tester la porte d'écoute réelle du
  /// processor (`stopListening()`), qui laisse toujours passer les
  /// événements simulés (voir la spec du module précédent). Cette
  /// fonction ne pilote PAS l'état d'écoute du processor : c'est à
  /// l'appelant d'avoir appelé `stopListening()` avant d'envoyer cet
  /// événement.
  static SoundEvent whileListeningStopped(
    String category, {
    DateTime? timestamp,
  }) =>
      SoundEvent(
        category: category,
        score: 0.9,
        timestamp: timestamp ?? DateTime.now(),
        source: 'microphone',
        isSimulation: false,
      );
}
