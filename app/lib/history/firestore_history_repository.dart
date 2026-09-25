import 'package:cloud_firestore/cloud_firestore.dart';

import '../sound_events/category_settings.dart';
import '../sound_events/sound_event.dart';
import 'current_user.dart';
import 'history_exceptions.dart';
import 'history_repository.dart';
import 'models/sound_event_record.dart';

/// Implémentation Firestore de [HistoryRepository]. Toutes les données
/// sont isolées sous `users/{uid}/...` — l'isolation entre utilisateurs
/// est appliquée côté serveur par `firestore.rules`, pas seulement par
/// cette classe (voir Task 7 pour la vérification réelle contre
/// l'émulateur).
class FirestoreHistoryRepository implements HistoryRepository {
  final FirebaseFirestore _firestore;
  final CurrentUser _currentUser;

  FirestoreHistoryRepository({
    FirebaseFirestore? firestore,
    CurrentUser? currentUser,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _currentUser = currentUser ?? CurrentUser();

  Future<CollectionReference<Map<String, dynamic>>> _eventsCollection() async {
    final uid = await _currentUser.ensureSignedIn();
    return _firestore.collection('users').doc(uid).collection('events');
  }

  Future<DocumentReference<Map<String, dynamic>>> _settingsDoc() async {
    final uid = await _currentUser.ensureSignedIn();
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('vibrations');
  }

  /// Génère un id unique côté client, sans écriture réseau : `.doc()`
  /// sans argument tire un identifiant aléatoire localement. La
  /// collection "_ids" n'est jamais réellement créée : aucune écriture
  /// n'a lieu ici.
  @override
  String newEventId() => _firestore.collection('_ids').doc().id;

  @override
  Future<void> saveEvent(SoundEventRecord record) async {
    try {
      final collection = await _eventsCollection();
      // set() par id (pas add()) : une même écriture retentée écrase le
      // même document au lieu d'en créer un doublon.
      await collection.doc(record.id).set(_eventToMap(record.event));
    } on FirebaseException catch (e) {
      throw _wrapWrite(e);
    }
  }

  @override
  Future<List<SoundEventRecord>> fetchEvents({int limit = 100}) async {
    late final QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      final collection = await _eventsCollection();
      snapshot = await collection
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
    } on FirebaseException catch (e) {
      throw _wrapRead(e);
    }
    try {
      return snapshot.docs
          .map((doc) => SoundEventRecord(
                id: doc.id,
                event: _eventFromMap(doc.data()),
              ))
          .toList();
    } on TypeError catch (e) {
      // Un document dont la forme ne correspond plus au schéma attendu
      // (champ manquant, type changé...) ne doit jamais faire fuiter une
      // TypeError non typée hors de ce module.
      throw HistoryReadException(
        'Document d\'historique mal formé',
        cause: e,
      );
    }
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    try {
      final collection = await _eventsCollection();
      await collection.doc(eventId).delete();
    } on FirebaseException catch (e) {
      throw _wrapWrite(e);
    }
  }

  // Une écriture par lot Firestore est plafonnée à 500 opérations côté
  // serveur. On supprime par blocs de 400 (marge de sécurité) plutôt
  // qu'en un seul lot, pour rester correct même avec un historique de
  // plus de 500 événements.
  static const _clearBatchSize = 400;

  @override
  Future<void> clearHistory() async {
    try {
      final collection = await _eventsCollection();
      // Firestore n'offre pas de suppression atomique de collection côté
      // client : on supprime les documents actuellement connus, bloc par
      // bloc. Une écriture déjà en file d'attente hors-ligne pour un
      // NOUVEL événement n'est pas annulée par cette opération — voir la
      // spec, section "comportement explicite clearHistory".
      while (true) {
        final snapshot = await collection.limit(_clearBatchSize).get();
        if (snapshot.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snapshot.docs.length < _clearBatchSize) break;
      }
    } on FirebaseException catch (e) {
      throw _wrapWrite(e);
    }
  }

  @override
  Future<void> saveVibrationPreferences(
    Map<String, CategorySettings> preferences,
  ) async {
    try {
      final doc = await _settingsDoc();
      await doc.set(_preferencesToMap(preferences));
    } on FirebaseException catch (e) {
      throw _wrapWrite(e);
    }
  }

  @override
  Future<Map<String, CategorySettings>?> fetchVibrationPreferences() async {
    late final DocumentSnapshot<Map<String, dynamic>> snapshot;
    try {
      final doc = await _settingsDoc();
      snapshot = await doc.get();
    } on FirebaseException catch (e) {
      throw _wrapRead(e);
    }
    final data = snapshot.data();
    if (data == null) return null;
    try {
      return _preferencesFromMap(data);
    } on TypeError catch (e) {
      throw HistoryReadException(
        'Document de préférences mal formé',
        cause: e,
      );
    }
  }

  Map<String, dynamic> _eventToMap(SoundEvent event) => {
        'category': event.category,
        'score': event.score,
        'timestamp': Timestamp.fromDate(event.timestamp),
        'source': event.source,
        'isSimulation': event.isSimulation,
      };

  SoundEvent _eventFromMap(Map<String, dynamic> data) => SoundEvent(
        category: data['category'] as String,
        score: (data['score'] as num).toDouble(),
        timestamp: (data['timestamp'] as Timestamp).toDate(),
        source: data['source'] as String,
        isSimulation: data['isSimulation'] as bool,
      );

  Map<String, dynamic> _preferencesToMap(
    Map<String, CategorySettings> preferences,
  ) {
    return preferences.map((category, settings) => MapEntry(category, {
          'enabled': settings.enabled,
          'threshold': settings.threshold,
          'requiredConfirmations': settings.requiredConfirmations,
          // Duration n'a pas de type Firestore natif : stocké en secondes.
          'cooldownSeconds': settings.cooldown.inSeconds,
        }));
  }

  Map<String, CategorySettings> _preferencesFromMap(
    Map<String, dynamic> data,
  ) {
    return data.map((category, value) {
      final map = Map<String, dynamic>.from(value as Map);
      return MapEntry(
        category,
        CategorySettings(
          enabled: map['enabled'] as bool,
          threshold: (map['threshold'] as num).toDouble(),
          requiredConfirmations: map['requiredConfirmations'] as int,
          cooldown: Duration(seconds: map['cooldownSeconds'] as int),
        ),
      );
    });
  }

  Exception _wrapWrite(FirebaseException e) {
    if (e.code == 'permission-denied') {
      return HistoryPermissionException('Accès refusé en écriture', cause: e);
    }
    return HistoryWriteException('Échec d\'écriture Firestore', cause: e);
  }

  Exception _wrapRead(FirebaseException e) {
    if (e.code == 'permission-denied') {
      return HistoryPermissionException('Accès refusé en lecture', cause: e);
    }
    return HistoryReadException('Échec de lecture Firestore', cause: e);
  }
}
