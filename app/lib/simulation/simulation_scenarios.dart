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
  ///
  /// [timestamp] : horodatage de l'événement généré (par défaut,
  /// l'instant présent). Retourne un [SoundEvent] prêt à être envoyé à
  /// un `SoundEventProcessor` (via `EventSimulator` ou directement).
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
  ///
  /// [category] : nom de catégorie à utiliser (par défaut, une valeur qui
  /// n'entre jamais en collision avec les catégories seedées par défaut
  /// `SoundEventSettings` — "sonnette"/"aboiement" — ni avec aucune
  /// catégorie usuelle). [timestamp] : voir [sonnette].
  static SoundEvent unknownCategory({
    String category = 'categorie-inconnue-simulee',
    DateTime? timestamp,
  }) => SoundEvent(
    category: category,
    score: 0.95,
    timestamp: timestamp ?? DateTime.now(),
    source: 'simulation',
    isSimulation: true,
  );

  /// Scénario 4 — un score volontairement sous [threshold].
  ///
  /// [category] : catégorie de l'événement. [threshold] : seuil que le
  /// score généré doit rester strictement sous — passez le seuil
  /// réellement configuré pour cette catégorie
  /// (`settings.lookup(category)!.threshold`) si vous voulez une preuve
  /// fidèle, le défaut (0.75) n'est qu'une valeur de convenance qui peut
  /// diverger de la config réelle. [timestamp] : voir [sonnette].
  ///
  /// Le score généré est `threshold - 0.1`, ramené entre 0.0 et 1.0.
  /// Avec un [threshold] très proche de 0.0, le score généré peut valoir
  /// 0.0 et ne plus être strictement inférieur au seuil — ce scénario
  /// suppose un seuil réaliste (> 0.1), pas un seuil nul.
  static SoundEvent belowThreshold(
    String category, {
    double threshold = 0.75,
    DateTime? timestamp,
  }) => SoundEvent(
    category: category,
    score: (threshold - 0.1).clamp(0.0, 1.0),
    timestamp: timestamp ?? DateTime.now(),
    source: 'simulation',
    isSimulation: true,
  );

  /// Scénario 5 — [count] événements identiques successifs (même
  /// catégorie, même score, même horodatage), utile pour tester
  /// l'anti-répétition.
  ///
  /// [category] : catégorie répétée. [score] : score identique pour
  /// chaque événement. [count] : nombre d'événements générés (au moins
  /// 1 pour un scénario utile). [timestamp] : horodatage commun à tous
  /// les événements générés (par défaut, l'instant présent).
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
  ///
  /// [categoryA]/[categoryB] : les deux catégories. [timestamp] :
  /// horodatage commun aux deux événements retournés (par défaut,
  /// l'instant présent). Retourne les deux [SoundEvent] sous forme de
  /// tuple `(a, b)` — à envoyer sans attendre l'un après l'autre pour
  /// reproduire une quasi-simultanéité (voir `EventSimulator`/le module
  /// de traitement des événements pour la politique "dernier gagne").
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
  ///
  /// [category] : catégorie de l'événement microphone simulé.
  /// [timestamp] : voir [sonnette].
  static SoundEvent whileListeningStopped(
    String category, {
    DateTime? timestamp,
  }) => SoundEvent(
    category: category,
    score: 0.9,
    timestamp: timestamp ?? DateTime.now(),
    source: 'microphone',
    isSimulation: false,
  );
}
