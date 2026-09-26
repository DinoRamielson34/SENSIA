/// Libellés français des catégories de sons (identifiants de
/// `SoundPriorityConfig`) et des niveaux de priorité, pour l'interface.
class SoundLabels {
  SoundLabels._();

  static const Map<String, String> _labels = {
    'train': 'Train',
    'fire_alarm': 'Alarme incendie',
    'smoke_alarm': 'Détecteur de fumée',
    'car_horn': 'Klaxon',
    'emergency_siren': 'Sirène d\'urgence',
    'car_alarm': 'Alarme de voiture',
    'baby_cry': 'Pleurs de bébé',
    'alarm': 'Alarme',
    'doorbell': 'Sonnette',
    'door_knock': 'Coups à la porte',
    'telephone': 'Téléphone',
    'alarm_clock': 'Réveil',
    'dog_bark': 'Aboiement',
  };

  static const Map<int, String> _priorityTitles = {
    5: 'Danger immédiat',
    4: 'Alertes',
    3: 'Vigilance',
    2: 'Sons du quotidien',
    1: 'Autres sons',
  };

  /// Libellé de [category] ; l'identifiant lui-même si elle est inconnue.
  static String of(String category) => _labels[category] ?? category;

  static String priorityTitle(int priority) =>
      _priorityTitles[priority] ?? 'Priorité $priority';
}
