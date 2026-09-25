import '../sound_events/category_settings.dart';
import 'models/sound_event_record.dart';

/// Interface de persistance de l'historique et des préférences de
/// vibration, indépendante de toute implémentation concrète (Firestore ou
/// autre). Permet à ses consommateurs de rester testables sans réseau.
abstract class HistoryRepository {
  /// Génère un identifiant unique pour un nouvel événement, sans effectuer
  /// d'écriture réseau.
  String newEventId();

  /// Enregistre [record]. Écrase tout enregistrement existant portant le
  /// même id (idempotent : appeler deux fois avec le même id ne crée
  /// jamais de doublon).
  Future<void> saveEvent(SoundEventRecord record);

  /// Retourne au plus [limit] événements, du plus récent au plus ancien.
  Future<List<SoundEventRecord>> fetchEvents({int limit = 100});

  /// Supprime l'événement [eventId]. Ne fait rien s'il n'existe pas.
  Future<void> deleteEvent(String eventId);

  /// Supprime tous les événements connus au moment de l'appel. Voir la
  /// spec pour le comportement avec des écritures hors-ligne en attente.
  Future<void> clearHistory();

  /// Enregistre les réglages de vibration par catégorie.
  Future<void> saveVibrationPreferences(
    Map<String, CategorySettings> preferences,
  );

  /// Retourne les réglages de vibration enregistrés, ou `null` si aucun
  /// n'a jamais été sauvegardé.
  Future<Map<String, CategorySettings>?> fetchVibrationPreferences();
}
