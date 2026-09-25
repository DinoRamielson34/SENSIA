/// Un événement de reconnaissance sonore, reçu du module IA (personne 1) ou
/// injecté par le mode simulation, à traiter par [SoundEventProcessor].
class SoundEvent {
  /// Catégorie sonore reconnue, ex: "dog_bark", "sonnette".
  final String category;

  /// Score fourni par le modèle IA. Ce n'est pas nécessairement une
  /// probabilité calibrée : à comparer uniquement au seuil configuré pour
  /// la catégorie, jamais à interpréter comme un pourcentage de certitude.
  final double score;

  /// Date et heure de la détection.
  final DateTime timestamp;

  /// Origine de l'événement, ex: "microphone", "simulation".
  final String source;

  /// true si l'événement est injecté par le mode simulation plutôt que
  /// produit par une détection réelle du microphone.
  final bool isSimulation;

  const SoundEvent({
    required this.category,
    required this.score,
    required this.timestamp,
    required this.source,
    required this.isSimulation,
  });
}
