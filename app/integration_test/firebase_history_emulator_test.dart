// Ce test nécessite le Firebase Local Emulator Suite démarré en local
// (voir Task 6 du plan : `npx firebase-tools emulators:start --project
// demo-izahay --only firestore,auth`) ET un client Flutter sur une
// plateforme supportée par cloud_firestore/firebase_auth. Exécution
// réelle : `flutter drive --driver=test_driver/integration_test.dart
// --target=integration_test/firebase_history_emulator_test.dart -d chrome`
// (voir le ledger d'exécution pour l'installation de Chrome/chromedriver
// requise dans ce conteneur — `flutter test ... -d chrome` seul NE
// FONCTIONNE PAS pour integration_test sur le web). Aucun compte Firebase
// réel n'est utilisé.
//
// Hôte de l'émulateur : 'host.docker.internal', pas 'localhost' — ce test
// tourne dans un conteneur Docker (réseau séparé de l'hôte macOS où
// l'émulateur écoute réellement). Sur un vrai appareil Android, utiliser
// 10.0.2.2 (émulateur Android) ou l'IP LAN de la machine (appareil
// physique) ; sur un hôte Linux natif sans Docker, 'localhost' suffit.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:izahay/history/current_user.dart';
import 'package:izahay/history/firestore_history_repository.dart';
import 'package:izahay/history/history_exceptions.dart';
import 'package:izahay/history/models/sound_event_record.dart';
import 'package:izahay/sound_events/category_settings.dart';
import 'package:izahay/sound_events/sound_event.dart';

const _emulatorHost = 'host.docker.internal';

/// Double de test : force le chemin Firestore construit par
/// [FirestoreHistoryRepository] à utiliser un uid choisi plutôt que celui
/// réellement authentifié — reproduit le scénario "et si la construction
/// du chemin avait un bug" (voir TEST 9 étendu) en passant par le vrai
/// code de production, pas une simulation.
class _FixedUidCurrentUser extends CurrentUser {
  _FixedUidCurrentUser(this.uid);
  final String uid;

  @override
  Future<String> ensureSignedIn() async => uid;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'demo-api-key',
        appId: '1:000000000000:web:0000000000000000',
        messagingSenderId: '000000000000',
        projectId: 'demo-izahay',
      ),
    );
    FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8080);
    await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
  });

  SoundEvent event(String category, DateTime timestamp, {double score = 0.9}) {
    return SoundEvent(
      category: category,
      score: score,
      timestamp: timestamp,
      source: 'microphone',
      isSimulation: false,
    );
  }

  testWidgets('enregistrement puis lecture réels via Firestore, champs '
      'préservés intégralement', (tester) async {
    await FirebaseAuth.instance.signOut();
    final repository = FirestoreHistoryRepository();

    final id = repository.newEventId();
    final original = event('sonnette', DateTime.utc(2026, 9, 25, 12, 30, 45));
    await repository.saveEvent(SoundEventRecord(id: id, event: original));

    final events = await repository.fetchEvents();
    final stored = events.firstWhere((e) => e.id == id);
    expect(stored.event.category, original.category);
    expect(stored.event.score, original.score);
    expect(stored.event.timestamp.toUtc(), original.timestamp.toUtc());
    expect(stored.event.source, original.source);
    expect(stored.event.isSimulation, original.isSimulation);
  });

  testWidgets('la persistance survit à la recréation du client Firestore '
      '(même utilisateur, nouvelle instance)', (tester) async {
    await FirebaseAuth.instance.signOut();
    final first = FirestoreHistoryRepository();
    final id = first.newEventId();
    await first.saveEvent(SoundEventRecord(
      id: id,
      event: event('aboiement', DateTime.utc(2026, 9, 25, 13)),
    ));

    final second = FirestoreHistoryRepository();
    final events = await second.fetchEvents();
    expect(events.map((e) => e.id), contains(id));
  });

  testWidgets('enregistrer deux fois le même id ne produit pas de doublon '
      '(la 2e écriture écrase la 1re)', (tester) async {
    await FirebaseAuth.instance.signOut();
    final repository = FirestoreHistoryRepository();
    final id = repository.newEventId();

    await repository.saveEvent(SoundEventRecord(
      id: id,
      event: event('sonnette', DateTime.utc(2026, 9, 25, 10), score: 0.5),
    ));
    await repository.saveEvent(SoundEventRecord(
      id: id,
      event: event('sonnette', DateTime.utc(2026, 9, 25, 10), score: 0.99),
    ));

    final events = await repository.fetchEvents();
    final matching = events.where((e) => e.id == id).toList();
    expect(matching, hasLength(1));
    expect(matching.single.event.score, 0.99);
  });

  testWidgets('fetchEvents retourne du plus récent au plus ancien même '
      'insérés dans le désordre, contre le vrai tri Firestore', (tester) async {
    await FirebaseAuth.instance.signOut();
    final repository = FirestoreHistoryRepository();

    final t0 = DateTime.utc(2026, 9, 25, 10);
    final idMilieu = repository.newEventId();
    await repository.saveEvent(SoundEventRecord(
      id: idMilieu,
      event: event('sonnette', t0.add(const Duration(minutes: 5))),
    ));
    final idRecent = repository.newEventId();
    await repository.saveEvent(SoundEventRecord(
      id: idRecent,
      event: event('aboiement', t0.add(const Duration(minutes: 10))),
    ));
    final idAncien = repository.newEventId();
    await repository.saveEvent(SoundEventRecord(
      id: idAncien,
      event: event('sonnette', t0),
    ));

    final events = await repository.fetchEvents();
    final ids = events.map((e) => e.id).toList();
    expect(
      ids.indexOf(idRecent) < ids.indexOf(idMilieu) &&
          ids.indexOf(idMilieu) < ids.indexOf(idAncien),
      isTrue,
      reason: 'attendu : $idRecent avant $idMilieu avant $idAncien, obtenu $ids',
    );
  });

  testWidgets('deleteEvent supprime un événement précis sans toucher aux '
      'autres', (tester) async {
    await FirebaseAuth.instance.signOut();
    final repository = FirestoreHistoryRepository();
    final aSupprimer = repository.newEventId();
    final aGarder = repository.newEventId();
    await repository.saveEvent(SoundEventRecord(
      id: aSupprimer,
      event: event('sonnette', DateTime.utc(2026, 9, 25, 9)),
    ));
    await repository.saveEvent(SoundEventRecord(
      id: aGarder,
      event: event('aboiement', DateTime.utc(2026, 9, 25, 9, 1)),
    ));

    await repository.deleteEvent(aSupprimer);

    final events = await repository.fetchEvents();
    expect(events.map((e) => e.id), isNot(contains(aSupprimer)));
    expect(events.map((e) => e.id), contains(aGarder));
  });

  testWidgets('clearHistory efface tous les événements connus', (tester) async {
    await FirebaseAuth.instance.signOut();
    final repository = FirestoreHistoryRepository();
    for (var i = 0; i < 3; i++) {
      await repository.saveEvent(SoundEventRecord(
        id: repository.newEventId(),
        event: event('sonnette', DateTime.utc(2026, 9, 25, 8, i)),
      ));
    }
    expect(await repository.fetchEvents(), isNotEmpty);

    await repository.clearHistory();

    expect(await repository.fetchEvents(), isEmpty);
  });

  testWidgets('les préférences de vibration font un aller-retour complet, '
      'y compris le cooldown', (tester) async {
    await FirebaseAuth.instance.signOut();
    final repository = FirestoreHistoryRepository();
    expect(await repository.fetchVibrationPreferences(), isNull);

    const preferences = {
      'sonnette': CategorySettings(
        enabled: true,
        threshold: 0.8,
        requiredConfirmations: 2,
        cooldown: Duration(seconds: 12),
      ),
      'aboiement': CategorySettings(
        enabled: false,
        threshold: 0.6,
        requiredConfirmations: 1,
        cooldown: Duration(seconds: 3),
      ),
    };
    await repository.saveVibrationPreferences(preferences);

    final fetched = await repository.fetchVibrationPreferences();
    expect(fetched, isNotNull);
    expect(fetched!['sonnette']!.enabled, isTrue);
    expect(fetched['sonnette']!.threshold, 0.8);
    expect(fetched['sonnette']!.requiredConfirmations, 2);
    expect(fetched['sonnette']!.cooldown, const Duration(seconds: 12));
    expect(fetched['aboiement']!.enabled, isFalse);
    expect(fetched['aboiement']!.cooldown, const Duration(seconds: 3));
  });

  testWidgets('écriture hors-ligne réellement mise en file (utilisateur '
      'déjà connecté), puis synchronisée au retour du réseau', (tester) async {
    await FirebaseAuth.instance.signOut();
    final repository = FirestoreHistoryRepository();
    // Connexion établie AVANT de couper le réseau : sinon l'appel réseau
    // de signInAnonymously() masquerait entièrement le scénario hors
    // ligne testé ici (voir la correction du même test dans la revue).
    await CurrentUser().ensureSignedIn();

    addTearDown(() => FirebaseFirestore.instance.enableNetwork());
    await FirebaseFirestore.instance.disableNetwork();

    final id = repository.newEventId();
    final pendingWrite = repository.saveEvent(SoundEventRecord(
      id: id,
      event: event('sonnette', DateTime.utc(2026, 9, 25, 14)),
    ));

    var writeCompleted = false;
    unawaited(pendingWrite.then((_) => writeCompleted = true));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(
      writeCompleted,
      isFalse,
      reason: 'l\'écriture ne doit pas se terminer pendant que le réseau '
          'est coupé : sinon ce test ne prouve rien sur le hors-ligne',
    );

    await FirebaseFirestore.instance.enableNetwork();
    await pendingWrite;

    final events = await repository.fetchEvents();
    expect(events.map((e) => e.id), contains(id));
  });

  testWidgets('deux ensureSignedIn() concurrents au tout premier appel '
      'résolvent au même utilisateur (pas de compte anonyme dupliqué)',
      (tester) async {
    await FirebaseAuth.instance.signOut();

    final results = await Future.wait([
      CurrentUser().ensureSignedIn(),
      CurrentUser().ensureSignedIn(),
      CurrentUser().ensureSignedIn(),
    ]);

    expect(results.toSet(), hasLength(1));
  });

  testWidgets('un document d\'historique malformé produit une '
      'HistoryReadException typée, jamais une TypeError', (tester) async {
    await FirebaseAuth.instance.signOut();
    final uid = await CurrentUser().ensureSignedIn();
    // Écrit directement, en contournant le repository, un document dont
    // le champ "score" n'a pas le bon type (simule une ancienne version
    // du schéma ou une donnée corrompue).
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('events')
        .doc('malformed')
        .set({
      'category': 'sonnette',
      'score': 'pas-un-nombre',
      'timestamp': Timestamp.now(),
      'source': 'microphone',
      'isSimulation': false,
    });

    final repository = FirestoreHistoryRepository();
    await expectLater(
      () => repository.fetchEvents(),
      throwsA(isA<HistoryReadException>()),
    );
  });

  testWidgets('TEST 9 — un utilisateur ne peut ni lire ni écrire les '
      'données d\'un autre utilisateur, via le vrai repository',
      (tester) async {
    await FirebaseAuth.instance.signOut();
    final userA = await CurrentUser().ensureSignedIn();

    await FirebaseAuth.instance.signOut();
    await CurrentUser().ensureSignedIn(); // utilisateur B, différent

    // B est réellement connecté, mais ce repository construit ses chemins
    // avec l'uid de A (voir _FixedUidCurrentUser) : reproduit fidèlement
    // "le repository a un bug de construction de chemin" à travers le
    // vrai code de production, pas une lecture directe simulée.
    final asIfA = FirestoreHistoryRepository(
      currentUser: _FixedUidCurrentUser(userA),
    );

    await expectLater(
      () => asIfA.fetchEvents(),
      throwsA(isA<HistoryPermissionException>()),
    );
    await expectLater(
      () => asIfA.saveEvent(SoundEventRecord(
        id: asIfA.newEventId(),
        event: event('sonnette', DateTime.utc(2026, 9, 25)),
      )),
      throwsA(isA<HistoryPermissionException>()),
    );
    await expectLater(
      () => asIfA.saveVibrationPreferences(const {}),
      throwsA(isA<HistoryPermissionException>()),
    );

    // Lecture directe (hors repository) confirmant que la règle elle-même
    // refuse, pas seulement l'enveloppe d'exception côté client.
    await expectLater(
      () => FirebaseFirestore.instance
          .collection('users')
          .doc(userA)
          .collection('events')
          .get(),
      throwsA(isA<FirebaseException>().having(
        (e) => e.code,
        'code',
        'permission-denied',
      )),
    );
  });

  testWidgets('un utilisateur non authentifié ne peut rien lire', (tester) async {
    await FirebaseAuth.instance.signOut();

    await expectLater(
      () => FirebaseFirestore.instance
          .collection('users')
          .doc('nimporte-quel-uid')
          .collection('events')
          .get(),
      throwsA(isA<FirebaseException>().having(
        (e) => e.code,
        'code',
        'permission-denied',
      )),
    );
  });

  testWidgets('les règles resserrées refusent un chemin arbitraire sous '
      'le propre uid de l\'utilisateur (pas de joker {document=**})',
      (tester) async {
    await FirebaseAuth.instance.signOut();
    final uid = await CurrentUser().ensureSignedIn();

    // "profile" n'est ni "events" ni "settings/vibrations" : les règles
    // explicites doivent refuser, même si c'est bien le propre uid de
    // l'utilisateur.
    await expectLater(
      () => FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('anything')
          .set({'nope': true}),
      throwsA(isA<FirebaseException>().having(
        (e) => e.code,
        'code',
        'permission-denied',
      )),
    );
  });
}
