# Module Firebase et historique — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persister les événements sonores déclenchés et les préférences de vibration via Cloud Firestore + Firebase Anonymous Auth, sans jamais faire dépendre le déclenchement d'une vibration d'une réponse Firebase, avec des règles de sécurité réellement vérifiées contre l'émulateur Firebase local.

**Architecture:** `lib/history/` fournit une interface `HistoryRepository` (implémentée par `FirestoreHistoryRepository`) et un adaptateur `HistoryResultSink` qui implémente l'interface `HistorySink` définie côté `lib/sound_events/` — `SoundEventProcessor` transmet chaque événement `triggered` en fire-and-forget, sans jamais connaître Firebase.

**Tech Stack:** Flutter/Dart (SDK `^3.12.0`), `firebase_core`/`firebase_auth`/`cloud_firestore`, Firebase Local Emulator Suite (via `npx firebase-tools`, projet `demo-izahay`, aucun compte réel), Chromium (installé ponctuellement dans le conteneur Docker pour exécuter les tests emulator).

**Spec:** [docs/superpowers/specs/2026-09-25-firebase-history-design.md](../specs/2026-09-25-firebase-history-design.md)

## Global Constraints

- Aucune modification de `lib/haptics/**`, `lib/main.dart`, ni d'aucun écran.
- Modifications de `lib/sound_events/` limitées à : nouveau `history_sink.dart`, paramètre optionnel `historySink` additif sur `SoundEventProcessor` (défaut `null`), nouveau getter `all` sur `SoundEventSettings` — aucun test existant de ce module ne doit changer de comportement.
- Aucun identifiant utilisateur inventé ou codé en dur : toujours issu de `FirebaseAuth` via `CurrentUser`.
- Le déclenchement d'une vibration ne dépend jamais de Firebase : tout appel à `HistorySink.record` est fire-and-forget, ses erreurs sont avalées à la frontière de `SoundEventProcessor`.
- Aucun enregistrement audio brut, aucune donnée personnelle au-delà des champs du contrat `SoundEvent`.
- Règles de sécurité Firestore à isolation stricte par utilisateur, vérifiées contre le véritable émulateur (pas seulement affirmées).
- Pas de nouvelle couche de stockage local (Hive/sqlite...) : la persistance hors-ligne native de Firestore suffit.
- Le comportement de `clearHistory()` avec des écritures hors-ligne en attente est documenté explicitement (voir spec), pas passé sous silence.

## Review Focus

- Un `HistorySink` qui ne répond jamais (ou échoue) ne doit jamais bloquer ni retarder le retour de `SoundEventProcessor.process()` — prouvé par un test borné par un timeout réel, pas seulement par lecture du code. Couvert par la Task 3.
- Seuls les résultats `SoundEventStatus.triggered` doivent atteindre `HistoryRepository.saveEvent` — un résultat filtré, supplanté ou en échec ne doit jamais être persisté. Couvert par la Task 4.
- Enregistrer deux fois le même `SoundEventRecord.id` ne doit jamais produire deux entrées (écrasement par id, pas ajout). Couvert par la Task 4 (fake) et la Task 7 (émulateur réel).
- L'accès aux données d'un autre utilisateur doit être réellement refusé par les règles de sécurité Firestore — la seule exigence qu'un fake ne peut pas prouver, elle doit passer par le véritable émulateur. Couvert par la Task 7.
- `fetchEvents()` doit retourner les événements du plus récent au plus ancien même quand ils sont insérés dans le désordre chronologique — pas seulement dans l'ordre d'insertion par coïncidence. Couvert par la Task 4.

---

## Task 1: Modèle `SoundEventRecord` et exceptions du module

**Files:**
- Create: `app/lib/history/models/sound_event_record.dart`
- Create: `app/lib/history/history_exceptions.dart`
- Test: `app/test/history/sound_event_record_test.dart`

**Interfaces:**
- Consumes: `SoundEvent` (déjà livré, `app/lib/sound_events/sound_event.dart`)
- Produces: `SoundEventRecord({required String id, required SoundEvent event})`, `HistoryWriteException`, `HistoryReadException`, `HistoryPermissionException` (même forme `{message, cause}` que `haptic_exceptions.dart`) — utilisés par toutes les tâches suivantes.

- [ ] **Step 1: Écrire le test qui échoue**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/history/models/sound_event_record.dart';
import 'package:izahay/sound_events/sound_event.dart';

void main() {
  test('SoundEventRecord expose id et event', () {
    final event = SoundEvent(
      category: 'sonnette',
      score: 0.9,
      timestamp: DateTime.utc(2026, 9, 25),
      source: 'microphone',
      isSimulation: false,
    );
    final record = SoundEventRecord(id: 'abc123', event: event);

    expect(record.id, 'abc123');
    expect(record.event, same(event));
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `cd app && flutter test test/history/sound_event_record_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:izahay/history/models/sound_event_record.dart'`

- [ ] **Step 3: Implémenter le modèle et les exceptions**

```dart
// app/lib/history/models/sound_event_record.dart
import 'package:izahay/sound_events/sound_event.dart';

/// Un événement sonore persisté : l'identifiant unique généré côté client
/// (voir [HistoryRepository.newEventId]) associé à l'événement d'origine.
/// Composition plutôt que duplication des champs de [SoundEvent].
class SoundEventRecord {
  final String id;
  final SoundEvent event;

  const SoundEventRecord({required this.id, required this.event});
}
```

```dart
// app/lib/history/history_exceptions.dart

/// Exception levée quand une écriture Firestore échoue (réseau, quota...).
/// Enveloppe la cause d'origine pour le débogage.
class HistoryWriteException implements Exception {
  final String message;
  final Object? cause;
  const HistoryWriteException(this.message, {this.cause});

  @override
  String toString() =>
      'HistoryWriteException: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// Exception levée quand une lecture Firestore échoue.
class HistoryReadException implements Exception {
  final String message;
  final Object? cause;
  const HistoryReadException(this.message, {this.cause});

  @override
  String toString() =>
      'HistoryReadException: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// Exception levée quand une opération est refusée par les règles de
/// sécurité Firestore (accès aux données d'un autre utilisateur).
class HistoryPermissionException implements Exception {
  final String message;
  final Object? cause;
  const HistoryPermissionException(this.message, {this.cause});

  @override
  String toString() =>
      'HistoryPermissionException: $message${cause != null ? ' (cause: $cause)' : ''}';
}
```

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `cd app && flutter test test/history/sound_event_record_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Commit**

```bash
git add app/lib/history/models/sound_event_record.dart app/lib/history/history_exceptions.dart app/test/history/sound_event_record_test.dart
git commit -m "feat: add SoundEventRecord model and history exceptions"
```

---

## Task 2: Interface `HistoryRepository` et double de test

**Files:**
- Create: `app/lib/history/history_repository.dart`
- Create: `app/test/history/fake_history_repository.dart`

**Interfaces:**
- Consumes: `SoundEventRecord` (Task 1), `CategorySettings` (déjà livré, `app/lib/sound_events/category_settings.dart`)
- Produces: `abstract class HistoryRepository { String newEventId(); Future<void> saveEvent(SoundEventRecord); Future<List<SoundEventRecord>> fetchEvents({int limit = 100}); Future<void> deleteEvent(String eventId); Future<void> clearHistory(); Future<void> saveVibrationPreferences(Map<String, CategorySettings>); Future<Map<String, CategorySettings>?> fetchVibrationPreferences(); }`, `FakeHistoryRepository` (double en mémoire, champs `saveEventError`/`fetchEventsError` pour injecter des pannes) — consommés par les Tasks 4 et 5.

Pas de test dédié à ce fichier : comme `VibrationExecutor`/`FakeVibrationExecutor` dans le module haptique, l'interface n'a pas de comportement propre et le double est prouvé correct par les tests de ses consommateurs (Task 4).

- [ ] **Step 1: Implémenter l'interface**

```dart
// app/lib/history/history_repository.dart
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
  Future<void> saveVibrationPreferences(Map<String, CategorySettings> preferences);

  /// Retourne les réglages de vibration enregistrés, ou `null` si aucun
  /// n'a jamais été sauvegardé.
  Future<Map<String, CategorySettings>?> fetchVibrationPreferences();
}
```

- [ ] **Step 2: Implémenter le double de test**

```dart
// app/test/history/fake_history_repository.dart
import 'package:izahay/history/history_repository.dart';
import 'package:izahay/history/models/sound_event_record.dart';
import 'package:izahay/sound_events/category_settings.dart';

/// Double de test pour [HistoryRepository] : aucun accès réseau, garde
/// tout en mémoire, permet d'injecter des pannes pour tester la gestion
/// d'erreur des consommateurs.
class FakeHistoryRepository implements HistoryRepository {
  final Map<String, SoundEventRecord> _events = {};
  Map<String, CategorySettings>? _preferences;
  int _nextId = 0;

  /// Si non nul, [saveEvent] lève cette erreur au lieu d'enregistrer.
  Object? saveEventError;

  @override
  String newEventId() => 'fake-${_nextId++}';

  @override
  Future<void> saveEvent(SoundEventRecord record) async {
    final error = saveEventError;
    if (error != null) throw error;
    _events[record.id] = record;
  }

  @override
  Future<List<SoundEventRecord>> fetchEvents({int limit = 100}) async {
    final sorted = _events.values.toList()
      ..sort((a, b) => b.event.timestamp.compareTo(a.event.timestamp));
    return sorted.take(limit).toList();
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    _events.remove(eventId);
  }

  @override
  Future<void> clearHistory() async {
    _events.clear();
  }

  @override
  Future<void> saveVibrationPreferences(
    Map<String, CategorySettings> preferences,
  ) async {
    _preferences = Map.of(preferences);
  }

  @override
  Future<Map<String, CategorySettings>?> fetchVibrationPreferences() async {
    final preferences = _preferences;
    return preferences == null ? null : Map.of(preferences);
  }
}
```

- [ ] **Step 3: Vérifier que le projet compile toujours (pas de test comportemental ici)**

Run: `cd app && flutter analyze lib/history test/history`
Expected: aucune erreur (des infos de style éventuelles sont acceptables, voir les rulings des modules précédents).

- [ ] **Step 4: Commit**

```bash
git add app/lib/history/history_repository.dart app/test/history/fake_history_repository.dart
git commit -m "feat: add HistoryRepository interface and in-memory fake"
```

---

## Task 3: Intégration `sound_events` — `HistorySink`

Ajoute le point d'extension permettant à `SoundEventProcessor` de transmettre un événement déclenché à l'historique sans connaître Firebase. Modifications additives et rétrocompatibles d'un module déjà livré et testé — la suite existante de `sound_events` doit rester verte à l'identique.

**Files:**
- Create: `app/lib/sound_events/history_sink.dart`
- Modify: `app/lib/sound_events/sound_event_processor.dart`
- Modify: `app/lib/sound_events/category_settings.dart`
- Modify: `app/test/sound_events/sound_event_processor_test.dart`
- Modify: `app/test/sound_events/category_settings_test.dart`

**Interfaces:**
- Consumes: `SoundEventResult`/`SoundEventStatus` (déjà livré)
- Produces: `abstract class HistorySink { Future<void> record(SoundEventResult result); }`, `SoundEventProcessor({..., HistorySink? historySink})`, `SoundEventSettings.all -> Map<String, CategorySettings>` — consommés par la Task 4.

- [ ] **Step 1: Créer l'interface HistorySink**

```dart
// app/lib/sound_events/history_sink.dart
import 'sound_event_result.dart';

/// Point d'extension permettant à [SoundEventProcessor] de transmettre un
/// événement déclenché à un module d'historique (ex: Firebase), sans
/// jamais connaître son implémentation concrète. Défini côté consommateur
/// (`sound_events`) pour que ce module ne dépende jamais de Firebase —
/// seul le module historique l'implémente.
abstract class HistorySink {
  /// Enregistre [result]. L'appelant ([SoundEventProcessor]) invoque
  /// toujours cette méthode en fire-and-forget (jamais attendue) : une
  /// implémentation lente ou en échec ne doit jamais bloquer ni faire
  /// échouer le pipeline de vibration.
  Future<void> record(SoundEventResult result);
}
```

- [ ] **Step 2: Écrire les tests qui échouent (ajoutés au fichier existant)**

Ajouter à la fin de `main()` dans `app/test/sound_events/sound_event_processor_test.dart` (et ajouter `import 'dart:async';` et `import 'package:izahay/sound_events/history_sink.dart';` en tête de fichier) :

```dart
  test('un historySink qui ne répond jamais ne bloque pas process()',
      () async {
    final sink = _RecordingHistorySink(neverCompletes: true);
    final withSink = SoundEventProcessor(
      hapticEngine: hapticEngine,
      historySink: sink,
    );

    final result = await withSink
        .process(event(category: 'sonnette', score: 0.9))
        .timeout(const Duration(seconds: 2));

    expect(result.status, SoundEventStatus.triggered);
    expect(sink.received, hasLength(1));
  });

  test('une erreur du historySink n\'empêche pas process() de retourner '
      'normalement', () async {
    final sink = _RecordingHistorySink(throwsOnRecord: true);
    final withSink = SoundEventProcessor(
      hapticEngine: hapticEngine,
      historySink: sink,
    );

    final result = await withSink
        .process(event(category: 'sonnette', score: 0.9))
        .timeout(const Duration(seconds: 2));

    expect(result.status, SoundEventStatus.triggered);
  });

  test('historySink n\'est jamais appelé pour un résultat non déclenché',
      () async {
    final sink = _RecordingHistorySink();
    final withSink = SoundEventProcessor(
      hapticEngine: hapticEngine,
      historySink: sink,
    );

    await withSink.process(event(category: 'sonnette', score: 0.1));
    // Laisse une chance à un éventuel appel fire-and-forget de s'exécuter
    // avant de vérifier qu'il n'a jamais eu lieu.
    await Future<void>.delayed(Duration.zero);

    expect(sink.received, isEmpty);
  });
}

/// Double de test pour [HistorySink], utilisé uniquement dans ce fichier.
class _RecordingHistorySink implements HistorySink {
  _RecordingHistorySink({this.neverCompletes = false, this.throwsOnRecord = false});

  final bool neverCompletes;
  final bool throwsOnRecord;
  final List<SoundEventResult> received = [];

  @override
  Future<void> record(SoundEventResult result) {
    received.add(result);
    if (throwsOnRecord) {
      return Future<void>.error(StateError('panne simulée du sink'));
    }
    if (neverCompletes) {
      return Completer<void>().future;
    }
    return Future<void>.value();
  }
}
```

(Le `}` fermant `void main() {` existant doit être retiré de sa position actuelle en fin de fichier et déplacé juste après le 3e nouveau test, puisque `_RecordingHistorySink` est déclarée en dehors de `main()`.)

- [ ] **Step 3: Lancer les tests et vérifier qu'ils échouent**

Run: `cd app && flutter test test/sound_events/sound_event_processor_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:izahay/sound_events/history_sink.dart'` (et `historySink` paramètre inconnu de `SoundEventProcessor`)

- [ ] **Step 4: Ajouter le paramètre et l'appel fire-and-forget dans SoundEventProcessor**

Dans `app/lib/sound_events/sound_event_processor.dart`, ajouter en tête de fichier :

```dart
import 'dart:async';

import 'history_sink.dart';
```

Ajouter un champ et un paramètre de constructeur :

```dart
  final HistorySink? _historySink;
```

```dart
  SoundEventProcessor({
    required HapticEngine hapticEngine,
    SoundEventSettings? settings,
    HistorySink? historySink,
  })  : _hapticEngine = hapticEngine,
        _historySink = historySink,
        settings = settings ?? SoundEventSettings();
```

Remplacer le `return _result(event, SoundEventStatus.triggered);` final de `process()` par :

```dart
    final result = _result(event, SoundEventStatus.triggered);
    final sink = _historySink;
    if (sink != null) {
      // Fire-and-forget : jamais attendu, pour qu'un historique lent ou
      // hors ligne (Firebase) ne retarde jamais une vibration déjà
      // déclenchée. L'erreur éventuelle du sink est délibérément avalée
      // ici : process() a déjà retourné son résultat, il n'y a plus
      // personne pour la recevoir.
      unawaited(sink.record(result).catchError((Object _) {}));
    }
    return result;
```

- [ ] **Step 5: Lancer les tests et vérifier qu'ils passent, puis relancer toute la suite sound_events**

Run: `cd app && flutter test test/sound_events/sound_event_processor_test.dart`
Expected: PASS (18 tests : les 15 existants + les 3 nouveaux)

Run: `cd app && flutter test test/sound_events/`
Expected: PASS (25 tests : 22 précédents + les 3 nouveaux ci-dessus ; aucune régression sur `category_settings_test.dart`, `sound_event_test.dart`, `sound_event_result_test.dart`)

- [ ] **Step 6: Écrire le test qui échoue pour le getter `all`**

Ajouter à la fin de `main()` dans `app/test/sound_events/category_settings_test.dart` :

```dart
  test('all expose une copie non modifiable des réglages actuels', () {
    final settings = SoundEventSettings();
    const custom = CategorySettings(
      enabled: true,
      threshold: 0.6,
      requiredConfirmations: 2,
      cooldown: Duration(seconds: 10),
    );
    settings.updateCategory('alarme', custom);

    final all = settings.all;

    expect(all['sonnette'], isNotNull);
    expect(all['aboiement'], isNotNull);
    expect(all['alarme'], same(custom));
    expect(() => all['nouvelle'] = custom, throwsUnsupportedError);
  });
```

- [ ] **Step 7: Lancer le test et vérifier qu'il échoue**

Run: `cd app && flutter test test/sound_events/category_settings_test.dart`
Expected: FAIL — `The getter 'all' isn't defined for the class 'SoundEventSettings'`

- [ ] **Step 8: Implémenter le getter**

Ajouter à `SoundEventSettings` dans `app/lib/sound_events/category_settings.dart` :

```dart
  /// Copie en lecture seule de tous les réglages actuellement configurés,
  /// utilisée pour la persistance (module historique) sans dupliquer ce
  /// modèle ni exposer la table interne mutable.
  Map<String, CategorySettings> get all => Map.unmodifiable(_settings);
```

- [ ] **Step 9: Lancer le test et vérifier qu'il passe, puis toute la suite du projet**

Run: `cd app && flutter test test/sound_events/`
Expected: PASS (26 tests : les 25 de l'étape précédente + celui-ci)

Run: `cd app && flutter test`
Expected: PASS (65 tests : 60 précédant ce plan + 1 de la Task 1 (`sound_event_record_test.dart`) + les 4 ajoutés dans cette Task 3 — aucune régression ailleurs)

- [ ] **Step 10: Commit**

```bash
git add app/lib/sound_events/history_sink.dart app/lib/sound_events/sound_event_processor.dart app/lib/sound_events/category_settings.dart app/test/sound_events/sound_event_processor_test.dart app/test/sound_events/category_settings_test.dart
git commit -m "feat: add HistorySink extension point to SoundEventProcessor"
```

---

## Task 4: `HistoryResultSink`

L'adaptateur côté module historique : implémente `HistorySink`, filtre sur `triggered`, génère l'id et transmet au `HistoryRepository`. Ses tests exercent aussi en profondeur le comportement de `FakeHistoryRepository` (tri, dédoublonnage) — voir la note de la Task 2.

**Files:**
- Create: `app/lib/history/history_result_sink.dart`
- Test: `app/test/history/history_result_sink_test.dart`

**Interfaces:**
- Consumes: `HistorySink` (Task 3), `HistoryRepository`/`FakeHistoryRepository` (Task 2), `SoundEventRecord` (Task 1), `SoundEventResult`/`SoundEventStatus` (déjà livré)
- Produces: `HistoryResultSink({required HistoryRepository repository})` implémentant `HistorySink` — utilisé par la Task 5/8 (câblage réel) et testable dès maintenant sans Firebase.

- [ ] **Step 1: Écrire les tests qui échouent**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/history/history_result_sink.dart';
import 'package:izahay/history/history_exceptions.dart';
import 'package:izahay/sound_events/sound_event.dart';
import 'package:izahay/sound_events/sound_event_result.dart';

import 'fake_history_repository.dart';

void main() {
  late FakeHistoryRepository repository;
  late HistoryResultSink sink;

  setUp(() {
    repository = FakeHistoryRepository();
    sink = HistoryResultSink(repository: repository);
  });

  SoundEvent event({
    required String category,
    DateTime? timestamp,
    bool isSimulation = false,
  }) {
    return SoundEvent(
      category: category,
      score: 0.9,
      timestamp: timestamp ?? DateTime.utc(2026, 9, 25, 12),
      source: 'microphone',
      isSimulation: isSimulation,
    );
  }

  test('un résultat triggered est enregistré dans le repository', () async {
    final result = SoundEventResult(
      event: event(category: 'sonnette'),
      status: SoundEventStatus.triggered,
      isSimulation: false,
    );

    await sink.record(result);

    final stored = await repository.fetchEvents();
    expect(stored, hasLength(1));
    expect(stored.single.event.category, 'sonnette');
  });

  test('un résultat non déclenché n\'est jamais enregistré', () async {
    for (final status in SoundEventStatus.values) {
      if (status == SoundEventStatus.triggered) continue;
      final result = SoundEventResult(
        event: event(category: 'sonnette'),
        status: status,
        isSimulation: false,
      );

      await sink.record(result);
    }

    expect(await repository.fetchEvents(), isEmpty);
  });

  test('un événement simulé déclenché est enregistré avec son statut '
      'simulé préservé', () async {
    final result = SoundEventResult(
      event: event(category: 'sonnette', isSimulation: true),
      status: SoundEventStatus.triggered,
      isSimulation: true,
    );

    await sink.record(result);

    final stored = await repository.fetchEvents();
    expect(stored.single.event.isSimulation, isTrue);
  });

  test('enregistrer deux résultats déclenchés distincts produit deux '
      'entrées triées du plus récent au plus ancien, même insérées dans '
      'le désordre', () async {
    final ancien = SoundEventResult(
      event: event(
        category: 'sonnette',
        timestamp: DateTime.utc(2026, 9, 25, 10),
      ),
      status: SoundEventStatus.triggered,
      isSimulation: false,
    );
    final recent = SoundEventResult(
      event: event(
        category: 'aboiement',
        timestamp: DateTime.utc(2026, 9, 25, 14),
      ),
      status: SoundEventStatus.triggered,
      isSimulation: false,
    );

    // Insérés dans le désordre chronologique (le plus récent en premier).
    await sink.record(recent);
    await sink.record(ancien);

    final stored = await repository.fetchEvents();
    expect(stored, hasLength(2));
    expect(stored[0].event.category, 'aboiement');
    expect(stored[1].event.category, 'sonnette');
  });

  test('une erreur du repository propage à travers record()', () async {
    repository.saveEventError = const HistoryWriteException('panne simulée');
    final result = SoundEventResult(
      event: event(category: 'sonnette'),
      status: SoundEventStatus.triggered,
      isSimulation: false,
    );

    await expectLater(
      () => sink.record(result),
      throwsA(isA<HistoryWriteException>()),
    );
  });
}
```

- [ ] **Step 2: Lancer les tests et vérifier qu'ils échouent**

Run: `cd app && flutter test test/history/history_result_sink_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:izahay/history/history_result_sink.dart'`

- [ ] **Step 3: Implémenter**

```dart
import '../sound_events/history_sink.dart';
import '../sound_events/sound_event_result.dart';
import 'history_repository.dart';
import 'models/sound_event_record.dart';

/// Implémente [HistorySink] côté module historique : convertit chaque
/// [SoundEventResult] réellement déclenché en [SoundEventRecord] et le
/// transmet au [HistoryRepository]. Les résultats non déclenchés (filtrés,
/// supplantés, en échec) ne sont jamais enregistrés : l'utilisateur ne les
/// a jamais vécus, ils n'ont pas leur place dans son historique.
class HistoryResultSink implements HistorySink {
  final HistoryRepository _repository;

  HistoryResultSink({required HistoryRepository repository})
      : _repository = repository;

  /// Lève toute exception du [HistoryRepository] sous-jacent (ex:
  /// [HistoryWriteException]) — c'est à l'appelant (typiquement
  /// [SoundEventProcessor], qui invoque toujours ceci en fire-and-forget)
  /// de décider comment la traiter.
  @override
  Future<void> record(SoundEventResult result) async {
    if (result.status != SoundEventStatus.triggered) return;
    final record = SoundEventRecord(
      id: _repository.newEventId(),
      event: result.event,
    );
    await _repository.saveEvent(record);
  }
}
```

- [ ] **Step 4: Lancer les tests et vérifier qu'ils passent**

Run: `cd app && flutter test test/history/history_result_sink_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/history/history_result_sink.dart app/test/history/history_result_sink_test.dart
git commit -m "feat: add HistoryResultSink adapter"
```

---

## Task 5: Dépendances Firebase, `CurrentUser`, `FirestoreHistoryRepository`, règles de sécurité

Code qui parle réellement à Firebase — pas de test unitaire ici (comme le pont Kotlin natif du module haptique, il ne peut pas être vérifié sans infrastructure réelle) : sa vérification se fait par compilation (`flutter pub get`/`flutter analyze`) puis, réellement, contre l'émulateur en Task 7.

**Files:**
- Modify: `app/pubspec.yaml`
- Create: `app/lib/history/current_user.dart`
- Create: `app/lib/history/firestore_history_repository.dart`
- Create: `app/firestore.rules`
- Create: `app/firebase.json`
- Create: `app/.firebaserc`

**Interfaces:**
- Consumes: `HistoryRepository` (Task 2), `SoundEventRecord`/`SoundEvent` (Task 1), `CategorySettings` (déjà livré), `HistoryWriteException`/`HistoryReadException`/`HistoryPermissionException` (Task 1)
- Produces: `CurrentUser({FirebaseAuth? auth}).ensureSignedIn() -> Future<String>`, `FirestoreHistoryRepository({FirebaseFirestore? firestore, CurrentUser? currentUser})` implémentant `HistoryRepository` — vérifiés réellement en Task 7.

- [ ] **Step 1: Ajouter les dépendances Firebase**

Run: `cd app && flutter pub add firebase_core firebase_auth cloud_firestore`
Expected: succès, les trois paquets et leurs dépendances transitives apparaissent dans `pubspec.lock`, versions résolues automatiquement (ne pas figer de numéro de version à la main).

- [ ] **Step 2: Implémenter CurrentUser**

```dart
// app/lib/history/current_user.dart
import 'package:firebase_auth/firebase_auth.dart';

/// Enveloppe fine autour de Firebase Authentication : garantit qu'un
/// utilisateur est connecté avant d'accéder à ses données, sans jamais
/// inventer ni coder en dur d'identifiant. Connexion anonyme uniquement
/// (voir la spec, décision n°2) : aucun écran de connexion requis.
class CurrentUser {
  final FirebaseAuth _auth;

  CurrentUser({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  /// Retourne l'uid de l'utilisateur courant, en le connectant anonymement
  /// s'il ne l'est pas déjà. Effectue un appel réseau (ou utilise la
  /// session Firebase déjà en cache) si aucune session n'existe encore.
  ///
  /// Lève toute exception de `firebase_auth` sans l'envelopper : cette
  /// classe ne fait que garantir la connexion, pas la gestion d'erreur
  /// métier (voir [FirestoreHistoryRepository], qui enveloppe les erreurs
  /// Firestore, pas celles d'authentification).
  Future<String> ensureSignedIn() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing.uid;

    final credential = await _auth.signInAnonymously();
    final user = credential.user;
    if (user == null) {
      throw StateError(
        'Firebase Auth n\'a retourné aucun utilisateur après signInAnonymously()',
      );
    }
    return user.uid;
  }
}
```

- [ ] **Step 3: Implémenter FirestoreHistoryRepository**

```dart
// app/lib/history/firestore_history_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;

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
    try {
      final collection = await _eventsCollection();
      final snapshot = await collection
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs
          .map((doc) => SoundEventRecord(
                id: doc.id,
                event: _eventFromMap(doc.data()),
              ))
          .toList();
    } on FirebaseException catch (e) {
      throw _wrapRead(e);
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

  @override
  Future<void> clearHistory() async {
    try {
      final collection = await _eventsCollection();
      // Firestore n'offre pas de suppression atomique de collection côté
      // client : on supprime chaque document actuellement connu. Une
      // écriture déjà en file d'attente hors-ligne pour un NOUVEL
      // événement n'est pas annulée par cette opération — voir la spec,
      // section "comportement explicite clearHistory".
      final snapshot = await collection.get();
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
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
    try {
      final doc = await _settingsDoc();
      final snapshot = await doc.get();
      final data = snapshot.data();
      return data == null ? null : _preferencesFromMap(data);
    } on FirebaseException catch (e) {
      throw _wrapRead(e);
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
```

- [ ] **Step 4: Créer les règles de sécurité**

```
// app/firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

- [ ] **Step 5: Créer la configuration de l'émulateur**

```json
// app/firebase.json
{
  "firestore": {
    "rules": "firestore.rules"
  },
  "emulators": {
    "auth": {
      "port": 9099
    },
    "firestore": {
      "port": 8080
    },
    "ui": {
      "enabled": false
    }
  }
}
```

```json
// app/.firebaserc
{
  "projects": {
    "default": "demo-izahay"
  }
}
```

- [ ] **Step 6: Vérifier que le projet compile**

Run: `cd app && flutter analyze lib/history`
Expected: aucune erreur (infos de style éventuelles acceptables).

Run: `cd app && flutter test`
Expected: PASS (70 tests : 65 précédents + les 5 de `history_result_sink_test.dart` ajoutés en Task 4 — aucune régression ; `firestore_history_repository.dart`/`current_user.dart` ne sont pas exercés ici, verification réelle en Task 7).

- [ ] **Step 7: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock app/lib/history/current_user.dart app/lib/history/firestore_history_repository.dart app/firestore.rules app/firebase.json app/.firebaserc
git commit -m "feat: add Firebase dependencies, CurrentUser and FirestoreHistoryRepository"
```

---

## Task 6: Émulateur Firebase local

Installe `firebase-tools` et lance les émulateurs Firestore + Auth avec le projet factice `demo-izahay`, sans compte réel. Étape d'infrastructure, pas de code produit.

**Files:** aucun fichier projet créé ou modifié (installation d'outil + processus lancé pour la durée de la session).

- [ ] **Step 1: Vérifier l'accès à npm et lancer les émulateurs**

Run (depuis `app/`, où se trouvent `firebase.json`/`.firebaserc`/`firestore.rules`) :
```bash
cd app && npx --yes firebase-tools@latest emulators:start --project demo-izahay --only firestore,auth
```
Expected: les émulateurs démarrent et affichent `✔ All emulators ready!`, Firestore sur `localhost:8080`, Auth sur `localhost:9099`. Lancer en arrière-plan (le process doit rester actif pendant toute la Task 7).

- [ ] **Step 2: Vérifier que les émulateurs répondent**

Run: `curl -s http://localhost:8080/ -o /dev/null -w '%{http_code}\n'`
Expected: un code HTTP de réponse du serveur Firestore emulator (ex: 200 ou 404 selon la route — l'important est une connexion TCP réussie, pas une erreur de connexion refusée).

Run: `curl -s http://localhost:9099/ -o /dev/null -w '%{http_code}\n'`
Expected: idem pour l'émulateur Auth.

---

## Task 7: Tests réels contre l'émulateur (nécessite Chromium)

Les seuls tests de ce plan qui touchent réellement Firebase. Nécessite un client Flutter sur une plateforme supportée par `cloud_firestore`/`firebase_auth` (Android, iOS, Windows, macOS, Web — **pas** Linux desktop) : Chromium est installé ponctuellement dans ce conteneur pour cette session (voir Global Constraints de la spec — ce n'est pas intégré au workflow Docker standard du projet ; un coéquipier devra soit utiliser un vrai téléphone, soit installer Chrome/Chromium lui-même pour relancer ces tests).

**Files:**
- Create: `app/integration_test/firebase_history_emulator_test.dart`

**Interfaces:**
- Consumes: `FirestoreHistoryRepository`, `CurrentUser` (Task 5), `SoundEventRecord`/`SoundEvent` (Task 1)

- [ ] **Step 1: Installer Chromium dans le conteneur**

Run: `docker compose run --rm --entrypoint bash android -c "apt-get update -qq && apt-get install -y -qq chromium && which chromium"`
Expected: chemin vers le binaire chromium installé (ex: `/usr/bin/chromium`). Cette installation est perdue à la fin du conteneur (`--rm`) : à refaire à chaque session de test emulator, ce n'est pas persistant.

- [ ] **Step 2: Écrire le test**

```dart
// app/integration_test/firebase_history_emulator_test.dart
//
// Ce test nécessite le Firebase Local Emulator Suite démarré en local
// (voir Task 6 du plan : `npx firebase-tools emulators:start --project
// demo-izahay --only firestore,auth`) ET un client Flutter sur une
// plateforme supportée par cloud_firestore/firebase_auth (ici : Chromium,
// installé ponctuellement — voir Task 7 Step 1). Aucun compte Firebase
// réel n'est utilisé.
//
// Exécution : flutter test integration_test/firebase_history_emulator_test.dart -d chrome
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:izahay/history/current_user.dart';
import 'package:izahay/history/firestore_history_repository.dart';
import 'package:izahay/history/history_exceptions.dart';
import 'package:izahay/history/models/sound_event_record.dart';
import 'package:izahay/sound_events/sound_event.dart';

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
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  });

  SoundEvent event(String category, DateTime timestamp) => SoundEvent(
        category: category,
        score: 0.9,
        timestamp: timestamp,
        source: 'microphone',
        isSimulation: false,
      );

  testWidgets('enregistrement puis lecture réels via Firestore', (tester) async {
    await FirebaseAuth.instance.signOut();
    final repository = FirestoreHistoryRepository();

    final id = repository.newEventId();
    await repository.saveEvent(SoundEventRecord(
      id: id,
      event: event('sonnette', DateTime.utc(2026, 9, 25, 12)),
    ));

    final events = await repository.fetchEvents();
    expect(events.map((e) => e.id), contains(id));
  });

  testWidgets('la persistance survit à la recréation du client', (tester) async {
    await FirebaseAuth.instance.signOut();
    final first = FirestoreHistoryRepository();
    final id = first.newEventId();
    await first.saveEvent(SoundEventRecord(
      id: id,
      event: event('aboiement', DateTime.utc(2026, 9, 25, 13)),
    ));

    // Nouvelle instance de repository, même utilisateur (session Auth
    // toujours active) : simule un redémarrage du côté application.
    final second = FirestoreHistoryRepository();
    final events = await second.fetchEvents();
    expect(events.map((e) => e.id), contains(id));
  });

  testWidgets('écriture hors-ligne mise en file puis synchronisée au '
      'retour du réseau', (tester) async {
    await FirebaseAuth.instance.signOut();
    final repository = FirestoreHistoryRepository();
    final id = repository.newEventId();

    await FirebaseFirestore.instance.disableNetwork();
    // N'attend pas la confirmation serveur : l'écriture est mise en file
    // d'attente locale, c'est exactement le scénario testé.
    final pendingWrite = repository.saveEvent(SoundEventRecord(
      id: id,
      event: event('sonnette', DateTime.utc(2026, 9, 25, 14)),
    ));
    await FirebaseFirestore.instance.enableNetwork();
    await pendingWrite;

    final events = await repository.fetchEvents();
    expect(events.map((e) => e.id), contains(id));
  });

  testWidgets('TEST 9 — un utilisateur ne peut pas lire les données d\'un '
      'autre utilisateur', (tester) async {
    await FirebaseAuth.instance.signOut();
    final userA = await CurrentUser().ensureSignedIn();

    await FirebaseAuth.instance.signOut();
    await CurrentUser().ensureSignedIn(); // utilisateur B, différent

    // Tente une lecture directe sous le chemin de l'utilisateur A, alors
    // que l'utilisateur B est connecté : doit être refusé par
    // firestore.rules, pas par une vérification côté client.
    expect(
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
}
```

- [ ] **Step 3: Lancer le test contre l'émulateur (Task 6 doit être en cours d'exécution)**

Run: `cd app && flutter test integration_test/firebase_history_emulator_test.dart -d chrome`
Expected: 4 tests PASS. Consigner le résultat réel obtenu (pas une supposition) dans la livraison finale.

Si ce test échoue pour une raison d'environnement (chrome non détecté, émulateur non joignable), documenter précisément l'erreur plutôt que de supposer un succès.

- [ ] **Step 4: Commit**

```bash
git add app/integration_test/firebase_history_emulator_test.dart
git commit -m "test: add real Firebase emulator integration tests"
```

---

## Task 8: Point d'entrée de debug manuel

Cohérent avec `haptics_debug_main.dart` : un écran minimal pour vérifier manuellement l'enregistrement/la lecture d'historique, sans dépendre du reste de l'application.

**Files:**
- Create: `app/lib/history_debug_main.dart`

**Interfaces:**
- Consumes: `FirestoreHistoryRepository`, `CurrentUser` (Task 5)

- [ ] **Step 1: Implémenter l'écran de debug**

```dart
// app/lib/history_debug_main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'history/firestore_history_repository.dart';
import 'history/history_repository.dart';
import 'history/models/sound_event_record.dart';
import 'sound_events/sound_event.dart';

/// Point d'entrée séparé pour tester manuellement le module historique
/// (enregistrement, lecture, effacement), sans dépendre du reste de
/// l'application.
///
/// Lancer avec : flutter run -t lib/history_debug_main.dart
/// Nécessite lib/firebase_options.dart (généré par `flutterfire configure`
/// contre un vrai projet Firebase — voir la spec, "Configuration manuelle
/// requise"). Absent tant qu'aucun projet réel n'existe.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(HistoryDebugApp(repository: FirestoreHistoryRepository()));
}

class HistoryDebugApp extends StatelessWidget {
  final HistoryRepository repository;

  const HistoryDebugApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IZAHAY — Test historique',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: HistoryDebugScreen(repository: repository),
    );
  }
}

class HistoryDebugScreen extends StatefulWidget {
  final HistoryRepository repository;

  const HistoryDebugScreen({super.key, required this.repository});

  @override
  State<HistoryDebugScreen> createState() => _HistoryDebugScreenState();
}

class _HistoryDebugScreenState extends State<HistoryDebugScreen> {
  List<SoundEventRecord> _events = [];
  String _status = '';

  Future<void> _addTestEvent() async {
    final id = widget.repository.newEventId();
    await widget.repository.saveEvent(SoundEventRecord(
      id: id,
      event: SoundEvent(
        category: 'sonnette',
        score: 0.9,
        timestamp: DateTime.now(),
        source: 'simulation',
        isSimulation: true,
      ),
    ));
    setState(() => _status = 'Événement ajouté ($id)');
    await _refresh();
  }

  Future<void> _refresh() async {
    final events = await widget.repository.fetchEvents();
    setState(() => _events = events);
  }

  Future<void> _clear() async {
    await widget.repository.clearHistory();
    setState(() => _status = 'Historique effacé');
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test historique')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: _addTestEvent,
                  child: const Text('Ajouter un événement de test'),
                ),
                OutlinedButton(
                  onPressed: _refresh,
                  child: const Text('Rafraîchir'),
                ),
                OutlinedButton(
                  onPressed: _clear,
                  child: const Text('Effacer'),
                ),
              ],
            ),
          ),
          Text(_status),
          Expanded(
            child: ListView.builder(
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final record = _events[index];
                return ListTile(
                  title: Text(record.event.category),
                  subtitle: Text('${record.event.timestamp} — ${record.id}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Vérifier que le projet compile**

Run: `cd app && flutter analyze lib/history_debug_main.dart`
Expected: aucune erreur.

- [ ] **Step 3: Commit**

```bash
git add app/lib/history_debug_main.dart
git commit -m "feat: add standalone debug entrypoint for manual history testing"
```
