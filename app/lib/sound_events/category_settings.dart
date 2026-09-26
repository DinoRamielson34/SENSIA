/// Réglages appliqués à une catégorie sonore par [SoundEventProcessor].
///
/// Les valeurs par défaut fournies par [SoundEventSettings] sont
/// EXPÉRIMENTALES : ce ne sont PAS des seuils de fiabilité validés
/// scientifiquement, seulement un point de départ raisonnable.
class CategorySettings {
  /// Si false, aucun événement de cette catégorie ne déclenche de
  /// vibration, quel que soit le score.
  final bool enabled;

  /// Score minimal (inclus) pour qu'un événement soit qualifiant.
  final double threshold;

  /// Nombre de détections qualifiantes consécutives requises avant de
  /// déclencher. 1 = déclenche dès la première détection qualifiante (pas
  /// de confirmation multi-fenêtres).
  final int requiredConfirmations;

  /// Délai minimal entre deux déclenchements de cette catégorie, pour
  /// éviter qu'un son prolongé (ex: aboiement continu) ne déclenche des
  /// vibrations en rafale.
  final Duration cooldown;

  const CategorySettings({
    required this.enabled,
    required this.threshold,
    required this.requiredConfirmations,
    required this.cooldown,
  });
}

/// Table mutable des réglages par catégorie, modifiable à l'exécution (par
/// une future UI de réglages ou une synchronisation Firebase) sans toucher
/// au code de [SoundEventProcessor].
///
/// Une catégorie absente de cette table est considérée comme inconnue du
/// système par [SoundEventProcessor], indépendamment de ce que
/// `HapticEngine` connaît par ailleurs.
class SoundEventSettings {
  final Map<String, CategorySettings> _settings = {};

  SoundEventSettings() {
    _seedDefaults();
  }

  void _seedDefaults() {
    // Valeurs expérimentales, mêmes catégories que les motifs par défaut
    // du moteur haptique, pour cohérence.
    const defaults = CategorySettings(
      enabled: true,
      threshold: 0.75,
      requiredConfirmations: 1,
      cooldown: Duration(seconds: 5),
    );
    updateCategory('sonnette', defaults);
    updateCategory('aboiement', defaults);
  }

  /// Ajoute ou remplace les réglages de [category].
  void updateCategory(String category, CategorySettings settings) {
    _settings[category] = settings;
  }

  /// Retourne les réglages de [category], ou `null` si la catégorie est
  /// inconnue du système.
  CategorySettings? lookup(String category) => _settings[category];

  /// Copie en lecture seule de tous les réglages actuellement configurés,
  /// utilisée pour la persistance (module historique) sans dupliquer ce
  /// modèle ni exposer la table interne mutable.
  Map<String, CategorySettings> get all => Map.unmodifiable(_settings);
}
