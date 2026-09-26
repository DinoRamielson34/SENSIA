# Moteur de traitement des événements sonores — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construire un pipeline Dart qui reçoit des `SoundEvent` (réels ou simulés) et décide, selon des règles métier configurables à l'exécution, s'il faut déclencher une vibration via le `HapticEngine` déjà livré — testable sans microphone ni IA.

**Architecture:** Quatre fichiers dans `lib/sound_events/` : un modèle d'événement (`SoundEvent`), une table de réglages mutable par catégorie (`SoundEventSettings`), un modèle de résultat (`SoundEventResult`/`SoundEventStatus`), et l'orchestrateur (`SoundEventProcessor`) qui applique 8 étapes de décision séquentielles avant de déléguer le déclenchement réel à `HapticEngine`, sans jamais modifier ce dernier.

**Tech Stack:** Flutter/Dart (SDK `^3.12.0`), réutilise `HapticEngine`/`FakeVibrationExecutor` du module haptique déjà livré.

**Spec:** [docs/superpowers/specs/2026-09-25-sound-event-processor-design.md](../specs/2026-09-25-sound-event-processor-design.md)

## Global Constraints

- Aucune modification de `lib/haptics/**` ni de `lib/main.dart`.
- Aucune dépendance à Firebase, ni à l'implémentation du modèle IA — seul le contrat de données `SoundEvent` est partagé avec la personne 1.
- Toute issue métier (catégorie désactivée, sous le seuil, en attente de confirmation, anti-répétition, écoute arrêtée, catégorie inconnue, échec haptique) est retournée via `SoundEventResult` — jamais levée comme exception. Seules les erreurs de programmation restent des exceptions Dart classiques.
- Confirmation = compteur consécutif sans fenêtre temporelle (aucune détection ne "expire" avec le temps, seule une détection sous le seuil remet le compteur à zéro).
- Un événement `isSimulation: true` ignore toujours la porte d'écoute (`stopListening()`), quelle que soit sa valeur de `source`.
- Les valeurs par défaut (`threshold: 0.75`, `cooldown: Duration(seconds: 5)`) sont documentées dans le code comme expérimentales, jamais comme des seuils de fiabilité validés.
- La cohérence entre vibrations concurrentes n'est pas réimplémentée : elle repose entièrement sur la politique "dernier gagne" déjà testée dans `HapticEngine`.

## Review Focus

- Une catégorie configurée dans `SoundEventSettings` mais absente du `PatternRegistry` de `HapticEngine` (désynchronisation entre les deux catalogues) : doit produire `hapticFailure` via l'exception typée capturée, jamais une exception non gérée qui remonte à l'appelant. Couvert par la Task 4.
- Un événement simulé dont `source == "microphone"`, reçu après `stopListening()` : doit tout de même être traité (pas bloqué) — l'interaction la plus piégeuse de la porte d'écoute. Couvert par la Task 4.
- `requiredConfirmations > 1` avec une détection sous le seuil au milieu de la série : le compteur doit revenir à zéro, pas seulement se mettre en pause — une détection qualifiante suivante ne doit donc pas déclencher immédiatement. Couvert par la Task 4.
- Deux catégories différentes traitées sans attendre entre les deux appels : ne doivent jamais produire deux vibrations ni un motif mélangé — seule la plus récente doit jouer. Couvert par la Task 5.
- Une détection qui arrive exactement à la limite de l'anti-répétition (`cooldown` calculé sur `event.timestamp`, pas sur l'horloge murale) : la limite doit être stricte et déterministe (strictement en dessous du délai = bloqué, à ou après = autorisé), pas dépendante du temps réel d'exécution du test. Couvert par la Task 4.

---

## Task 1: Modèle `SoundEvent`

Le contrat de données reçu du module IA (personne 1) ou injecté par le mode simulation. Aucune structure commune existante n'est modifiée — celle-ci est nouvelle (vérifié en amont : rien de tel n'existe dans le code).

**Files:**
- Create: `app/lib/sound_events/sound_event.dart`
- Test: `app/test/sound_events/sound_event_test.dart`

**Interfaces:**
- Produces: `SoundEvent({required String category, required double score, required DateTime timestamp, required String source, required bool isSimulation})` — consommé par toutes les tâches suivantes.

- [ ] **Step 1: Écrire le test qui échoue**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/sound_events/sound_event.dart';

void main() {
  test('SoundEvent expose tous les champs du contrat', () {
    final timestamp = DateTime.utc(2026, 9, 25, 14, 30);
    final event = SoundEvent(
      category: 'dog_bark',
      score: 0.91,
      timestamp: timestamp,
      source: 'microphone',
      isSimulation: false,
    );

    expect(event.category, 'dog_bark');
    expect(event.score, 0.91);
    expect(event.timestamp, timestamp);
    expect(event.source, 'microphone');
    expect(event.isSimulation, isFalse);
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `cd app && flutter test test/sound_events/sound_event_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:izahay/sound_events/sound_event.dart'`

- [ ] **Step 3: Implémenter le modèle**

```dart
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
```

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `cd app && flutter test test/sound_events/sound_event_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Commit**

```bash
git add app/lib/sound_events/sound_event.dart app/test/sound_events/sound_event_test.dart
git commit -m "feat: add SoundEvent data contract"
```

---

## Task 2: Réglages par catégorie (`CategorySettings`/`SoundEventSettings`)

Table mutable, modifiable à l'exécution sans recompiler (règle 12), qui définit à la fois quelles catégories sont connues du système et leurs paramètres métier.

**Files:**
- Create: `app/lib/sound_events/category_settings.dart`
- Test: `app/test/sound_events/category_settings_test.dart`

**Interfaces:**
- Produces: `CategorySettings({required bool enabled, required double threshold, required int requiredConfirmations, required Duration cooldown})`, `SoundEventSettings()` (seedée), `.updateCategory(String category, CategorySettings settings)`, `.lookup(String category) -> CategorySettings?` — utilisés par la Task 4.

- [ ] **Step 1: Écrire le test qui échoue**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/sound_events/category_settings.dart';

void main() {
  test('contient les catégories par défaut sonnette et aboiement, activées',
      () {
    final settings = SoundEventSettings();
    expect(settings.lookup('sonnette'), isNotNull);
    expect(settings.lookup('aboiement'), isNotNull);
    expect(settings.lookup('sonnette')!.enabled, isTrue);
  });

  test('lookup retourne null pour une catégorie inconnue', () {
    final settings = SoundEventSettings();
    expect(settings.lookup('inconnue'), isNull);
  });

  test('updateCategory ajoute une nouvelle catégorie', () {
    final settings = SoundEventSettings();
    const custom = CategorySettings(
      enabled: true,
      threshold: 0.6,
      requiredConfirmations: 2,
      cooldown: Duration(seconds: 10),
    );
    settings.updateCategory('alarme', custom);
    expect(settings.lookup('alarme'), same(custom));
  });

  test('updateCategory remplace des réglages existants', () {
    final settings = SoundEventSettings();
    const desactivee = CategorySettings(
      enabled: false,
      threshold: 0.75,
      requiredConfirmations: 1,
      cooldown: Duration(seconds: 5),
    );
    settings.updateCategory('sonnette', desactivee);
    expect(settings.lookup('sonnette'), same(desactivee));
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `cd app && flutter test test/sound_events/category_settings_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:izahay/sound_events/category_settings.dart'`

- [ ] **Step 3: Implémenter**

```dart
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
}
```

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `cd app && flutter test test/sound_events/category_settings_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/sound_events/category_settings.dart app/test/sound_events/category_settings_test.dart
git commit -m "feat: add per-category sound event settings, runtime-configurable"
```

---

## Task 3: Résultat (`SoundEventResult`/`SoundEventStatus`)

Le verdict du traitement, exploitable par les autres modules (UI, historique) sans qu'ils connaissent les règles métier qui l'ont produit.

**Files:**
- Create: `app/lib/sound_events/sound_event_result.dart`
- Test: `app/test/sound_events/sound_event_result_test.dart`

**Interfaces:**
- Consumes: `SoundEvent` (Task 1)
- Produces: `enum SoundEventStatus { triggered, unknownCategory, categoryDisabled, belowThreshold, awaitingConfirmation, inCooldown, listeningStopped, hapticFailure }`, `SoundEventResult({required SoundEvent event, required SoundEventStatus status, required bool isSimulation, String? reason})` — utilisé par la Task 4.

- [ ] **Step 1: Écrire le test qui échoue**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/sound_events/sound_event.dart';
import 'package:izahay/sound_events/sound_event_result.dart';

void main() {
  test('SoundEventResult expose event, status, isSimulation et reason', () {
    final event = SoundEvent(
      category: 'sonnette',
      score: 0.9,
      timestamp: DateTime.utc(2026, 9, 25),
      source: 'microphone',
      isSimulation: false,
    );
    final result = SoundEventResult(
      event: event,
      status: SoundEventStatus.hapticFailure,
      isSimulation: false,
      reason: 'panne simulée',
    );

    expect(result.event, same(event));
    expect(result.status, SoundEventStatus.hapticFailure);
    expect(result.isSimulation, isFalse);
    expect(result.reason, 'panne simulée');
  });

  test('reason est optionnel (null par défaut)', () {
    final event = SoundEvent(
      category: 'sonnette',
      score: 0.9,
      timestamp: DateTime.utc(2026, 9, 25),
      source: 'microphone',
      isSimulation: false,
    );
    final result = SoundEventResult(
      event: event,
      status: SoundEventStatus.triggered,
      isSimulation: false,
    );

    expect(result.reason, isNull);
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `cd app && flutter test test/sound_events/sound_event_result_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:izahay/sound_events/sound_event_result.dart'`

- [ ] **Step 3: Implémenter**

```dart
import 'sound_event.dart';

/// Statut d'issue du traitement d'un [SoundEvent] par [SoundEventProcessor].
/// Aucune de ces valeurs n'est une erreur de programmation : ce sont des
/// issues métier normales, jamais levées comme exceptions.
enum SoundEventStatus {
  /// La vibration a été déclenchée avec succès.
  triggered,

  /// La catégorie n'est pas configurée dans [SoundEventSettings].
  unknownCategory,

  /// La catégorie est configurée mais désactivée par l'utilisateur.
  categoryDisabled,

  /// Le score de l'événement est sous le seuil configuré.
  belowThreshold,

  /// Le nombre de confirmations requises n'est pas encore atteint.
  awaitingConfirmation,

  /// Un déclenchement récent pour cette catégorie bloque celui-ci
  /// (anti-répétition).
  inCooldown,

  /// L'événement vient du microphone alors que l'écoute est arrêtée.
  listeningStopped,

  /// `HapticEngine` a rejeté ou échoué le déclenchement (voir [SoundEventResult.reason]).
  hapticFailure,
}

/// Le verdict du traitement d'un [SoundEvent], exploitable par les autres
/// modules (interface utilisateur, historique) sans qu'ils aient besoin de
/// connaître les règles métier qui l'ont produit.
class SoundEventResult {
  final SoundEvent event;
  final SoundEventStatus status;

  /// Dupliqué depuis `event.isSimulation`, pour que les consommateurs de ce
  /// résultat n'aient pas besoin de redescendre dans l'événement d'origine
  /// pour distinguer réel/simulé.
  final bool isSimulation;

  /// Détail lisible, notamment renseigné pour [SoundEventStatus.hapticFailure].
  final String? reason;

  const SoundEventResult({
    required this.event,
    required this.status,
    required this.isSimulation,
    this.reason,
  });
}
```

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `cd app && flutter test test/sound_events/sound_event_result_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/sound_events/sound_event_result.dart app/test/sound_events/sound_event_result_test.dart
git commit -m "feat: add SoundEventResult/SoundEventStatus"
```

---

## Task 4: `SoundEventProcessor` — pipeline complet

Le cœur du module : les 8 étapes de décision, de la réception d'un `SoundEvent` jusqu'au déclenchement (ou non) de `HapticEngine`. Implémenté et testé en un seul passage car les étapes (seuil, confirmation, anti-répétition, déclenchement) partagent un état interne étroitement lié — les découper en tâches séparées obligerait à des étapes intermédiaires non fonctionnelles.

**Files:**
- Create: `app/lib/sound_events/sound_event_processor.dart`
- Test: `app/test/sound_events/sound_event_processor_test.dart`

**Interfaces:**
- Consumes: `SoundEvent` (Task 1), `SoundEventSettings`/`CategorySettings` (Task 2), `SoundEventResult`/`SoundEventStatus` (Task 3), `HapticEngine`/`InvalidVibrationPatternException`/`HapticUnsupportedException` (module haptique déjà livré : `app/lib/haptics/haptic_engine.dart`, `app/lib/haptics/haptic_exceptions.dart`), `FakeVibrationExecutor` (déjà livré : `app/test/haptics/fake_vibration_executor.dart`, réutilisé tel quel pour les tests)
- Produces: `SoundEventProcessor({required HapticEngine hapticEngine, SoundEventSettings? settings})`, `.settings` (champ public, `SoundEventSettings`), `.startListening()`, `.stopListening()`, `.process(SoundEvent event) -> Future<SoundEventResult>` — utilisé par la Task 5.

- [ ] **Step 1: Écrire les tests qui échouent**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/haptics/haptic_engine.dart';
import 'package:izahay/sound_events/category_settings.dart';
import 'package:izahay/sound_events/sound_event.dart';
import 'package:izahay/sound_events/sound_event_processor.dart';
import 'package:izahay/sound_events/sound_event_result.dart';

import '../haptics/fake_vibration_executor.dart';

void main() {
  late FakeVibrationExecutor executor;
  late HapticEngine hapticEngine;
  late SoundEventProcessor processor;
  late DateTime t0;

  setUp(() {
    executor = FakeVibrationExecutor();
    hapticEngine = HapticEngine(executor: executor);
    processor = SoundEventProcessor(hapticEngine: hapticEngine);
    t0 = DateTime.utc(2026, 9, 25, 12);
  });

  SoundEvent event({
    required String category,
    required double score,
    DateTime? timestamp,
    String source = 'microphone',
    bool isSimulation = false,
  }) {
    return SoundEvent(
      category: category,
      score: score,
      timestamp: timestamp ?? t0,
      source: source,
      isSimulation: isSimulation,
    );
  }

  test('TEST 1 — catégorie activée, score au-dessus du seuil, confirmation '
      'valide déclenche la vibration', () async {
    final result =
        await processor.process(event(category: 'sonnette', score: 0.9));

    expect(result.status, SoundEventStatus.triggered);
    expect(executor.vibrateCalls, isNotEmpty);
  });

  test('TEST 2 — une catégorie désactivée ne déclenche aucune vibration',
      () async {
    processor.settings.updateCategory(
      'sonnette',
      const CategorySettings(
        enabled: false,
        threshold: 0.75,
        requiredConfirmations: 1,
        cooldown: Duration(seconds: 5),
      ),
    );

    final result =
        await processor.process(event(category: 'sonnette', score: 0.99));

    expect(result.status, SoundEventStatus.categoryDisabled);
    expect(executor.vibrateCalls, isEmpty);
  });

  test('TEST 3 — un score inférieur au seuil ne déclenche aucune vibration',
      () async {
    final result =
        await processor.process(event(category: 'sonnette', score: 0.5));

    expect(result.status, SoundEventStatus.belowThreshold);
    expect(executor.vibrateCalls, isEmpty);
  });

  test('TEST 5 — une catégorie inconnue est ignorée proprement', () async {
    final result =
        await processor.process(event(category: 'inconnue', score: 0.99));

    expect(result.status, SoundEventStatus.unknownCategory);
    expect(executor.vibrateCalls, isEmpty);
  });

  test('TEST 6 — un événement simulé suit les mêmes règles et conserve son '
      'statut simulé', () async {
    final resultDeclenche = await processor.process(
      event(category: 'sonnette', score: 0.9, isSimulation: true),
    );
    expect(resultDeclenche.status, SoundEventStatus.triggered);
    expect(resultDeclenche.isSimulation, isTrue);

    final resultSousSeuil = await processor.process(
      event(
        category: 'aboiement',
        score: 0.1,
        isSimulation: true,
      ),
    );
    expect(resultSousSeuil.status, SoundEventStatus.belowThreshold);
    expect(resultSousSeuil.isSimulation, isTrue);
  });

  test('TEST 7 — l\'arrêt de l\'écoute bloque les événements microphone, '
      'mais pas les événements simulés', () async {
    processor.stopListening();

    final resultMicro =
        await processor.process(event(category: 'sonnette', score: 0.9));
    expect(resultMicro.status, SoundEventStatus.listeningStopped);
    expect(executor.vibrateCalls, isEmpty);

    // Un événement simulé qui se déclare pourtant source: "microphone"
    // doit tout de même passer : la simulation ignore l'état d'écoute.
    final resultSimule = await processor.process(
      event(category: 'sonnette', score: 0.9, isSimulation: true),
    );
    expect(resultSimule.status, SoundEventStatus.triggered);
  });

  test('confirmation multi-fenêtres : ne déclenche qu\'après N détections '
      'consécutives qualifiantes', () async {
    processor.settings.updateCategory(
      'sonnette',
      const CategorySettings(
        enabled: true,
        threshold: 0.75,
        requiredConfirmations: 2,
        cooldown: Duration(seconds: 5),
      ),
    );

    final first =
        await processor.process(event(category: 'sonnette', score: 0.9));
    expect(first.status, SoundEventStatus.awaitingConfirmation);
    expect(executor.vibrateCalls, isEmpty);

    final second = await processor.process(
      event(category: 'sonnette', score: 0.9, timestamp: t0),
    );
    expect(second.status, SoundEventStatus.triggered);
    expect(executor.vibrateCalls, isNotEmpty);
  });

  test('une détection sous le seuil remet le compteur de confirmation à '
      'zéro', () async {
    processor.settings.updateCategory(
      'sonnette',
      const CategorySettings(
        enabled: true,
        threshold: 0.75,
        requiredConfirmations: 2,
        cooldown: Duration(seconds: 5),
      ),
    );

    await processor.process(event(category: 'sonnette', score: 0.9));
    await processor.process(event(category: 'sonnette', score: 0.1));
    final third =
        await processor.process(event(category: 'sonnette', score: 0.9));

    // Le compteur ayant été remis à zéro, cette 3e détection n'est que la
    // 1re d'une nouvelle série : encore en attente, pas déclenché.
    expect(third.status, SoundEventStatus.awaitingConfirmation);
    expect(executor.vibrateCalls, isEmpty);
  });

  test('TEST 4 — deux détections trop rapprochées ne produisent pas deux '
      'vibrations (anti-répétition)', () async {
    final first = await processor.process(
      event(category: 'sonnette', score: 0.9, timestamp: t0),
    );
    expect(first.status, SoundEventStatus.triggered);

    final second = await processor.process(
      event(
        category: 'sonnette',
        score: 0.9,
        timestamp: t0.add(const Duration(seconds: 1)),
      ),
    );
    expect(second.status, SoundEventStatus.inCooldown);
    expect(executor.vibrateCalls, hasLength(1));

    final third = await processor.process(
      event(
        category: 'sonnette',
        score: 0.9,
        timestamp: t0.add(const Duration(seconds: 6)),
      ),
    );
    expect(third.status, SoundEventStatus.triggered);
    expect(executor.vibrateCalls, hasLength(2));
  });

  test('un échec du moteur haptique (catégorie non enregistrée côté '
      'HapticEngine) est retourné proprement, jamais levé comme exception',
      () async {
    processor.settings.updateCategory(
      'connue-du-processor-seulement',
      const CategorySettings(
        enabled: true,
        threshold: 0.5,
        requiredConfirmations: 1,
        cooldown: Duration(seconds: 5),
      ),
    );

    final result = await processor.process(
      event(category: 'connue-du-processor-seulement', score: 0.9),
    );

    expect(result.status, SoundEventStatus.hapticFailure);
    expect(result.reason, isNotNull);
    expect(executor.vibrateCalls, isEmpty);
  });
}
```

- [ ] **Step 2: Lancer les tests et vérifier qu'ils échouent**

Run: `cd app && flutter test test/sound_events/sound_event_processor_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:izahay/sound_events/sound_event_processor.dart'`

- [ ] **Step 3: Implémenter le pipeline**

```dart
import '../haptics/haptic_engine.dart';
import '../haptics/haptic_exceptions.dart';
import 'category_settings.dart';
import 'sound_event.dart';
import 'sound_event_result.dart';

/// Pipeline qui décide, pour chaque [SoundEvent] reçu, s'il doit déclencher
/// une vibration via [HapticEngine], en appliquant les règles métier
/// (catégorie connue, activée, seuil, confirmation, anti-répétition).
///
/// Fonctionne indépendamment du modèle IA et de Firebase : testable avec
/// des [SoundEvent] fictifs, sans microphone (voir le mode simulation via
/// `SoundEvent.isSimulation`).
class SoundEventProcessor {
  final HapticEngine _hapticEngine;

  /// Réglages par catégorie (seuil, activation, confirmations,
  /// anti-répétition), modifiables à l'exécution.
  final SoundEventSettings settings;

  bool _isListening = true;

  // Compteur de détections qualifiantes consécutives, par catégorie.
  final Map<String, int> _confirmationCounts = {};

  // Horodatage du dernier déclenchement réussi, par catégorie — utilisé
  // pour l'anti-répétition.
  final Map<String, DateTime> _lastTriggeredAt = {};

  SoundEventProcessor({
    required HapticEngine hapticEngine,
    SoundEventSettings? settings,
  })  : _hapticEngine = hapticEngine,
        settings = settings ?? SoundEventSettings();

  /// Autorise à nouveau le traitement des événements en provenance du
  /// microphone (état par défaut à la création).
  void startListening() => _isListening = true;

  /// Bloque tout nouvel événement en provenance du microphone. Les
  /// événements simulés (`SoundEvent.isSimulation == true`) continuent
  /// d'être traités normalement : le mode simulation sert justement à
  /// tester le moteur sans microphone, l'arrêt de l'écoute réelle ne doit
  /// pas l'en empêcher.
  void stopListening() => _isListening = false;

  /// Traite [event] et retourne toujours un [SoundEventResult] — jamais
  /// d'exception pour une issue métier normale (catégorie désactivée,
  /// sous le seuil, etc.). Applique dans l'ordre : porte d'écoute,
  /// catégorie connue, catégorie activée, seuil, confirmation,
  /// anti-répétition, puis déclenchement haptique.
  Future<SoundEventResult> process(SoundEvent event) async {
    if (_blockedByListeningGate(event)) {
      return _result(event, SoundEventStatus.listeningStopped);
    }

    final categorySettings = settings.lookup(event.category);
    if (categorySettings == null) {
      return _result(event, SoundEventStatus.unknownCategory);
    }

    if (!categorySettings.enabled) {
      return _result(event, SoundEventStatus.categoryDisabled);
    }

    if (event.score < categorySettings.threshold) {
      // Une détection sous le seuil casse toute série de confirmation en
      // cours : la prochaine détection qualifiante repart de zéro.
      _confirmationCounts[event.category] = 0;
      return _result(event, SoundEventStatus.belowThreshold);
    }

    final confirmations = (_confirmationCounts[event.category] ?? 0) + 1;
    _confirmationCounts[event.category] = confirmations;
    if (confirmations < categorySettings.requiredConfirmations) {
      return _result(event, SoundEventStatus.awaitingConfirmation);
    }

    final lastTriggeredAt = _lastTriggeredAt[event.category];
    if (lastTriggeredAt != null &&
        event.timestamp.difference(lastTriggeredAt) <
            categorySettings.cooldown) {
      // Anti-répétition : la série de confirmation n'est PAS remise à
      // zéro ici — l'événement était valide, juste trop rapproché du
      // précédent déclenchement.
      return _result(event, SoundEventStatus.inCooldown);
    }

    try {
      await _hapticEngine.playForCategory(event.category);
    } on InvalidVibrationPatternException catch (e) {
      return _result(event, SoundEventStatus.hapticFailure, reason: e.message);
    } on HapticUnsupportedException catch (e) {
      return _result(event, SoundEventStatus.hapticFailure, reason: e.message);
    }

    _confirmationCounts[event.category] = 0;
    _lastTriggeredAt[event.category] = event.timestamp;
    return _result(event, SoundEventStatus.triggered);
  }

  // Un événement microphone réel est bloqué si l'écoute est arrêtée. Un
  // événement simulé ignore toujours cette porte, même s'il se déclare
  // source: "microphone".
  bool _blockedByListeningGate(SoundEvent event) {
    return !_isListening && !event.isSimulation && event.source == 'microphone';
  }

  SoundEventResult _result(
    SoundEvent event,
    SoundEventStatus status, {
    String? reason,
  }) {
    return SoundEventResult(
      event: event,
      status: status,
      isSimulation: event.isSimulation,
      reason: reason,
    );
  }
}
```

- [ ] **Step 4: Lancer les tests et vérifier qu'ils passent**

Run: `cd app && flutter test test/sound_events/sound_event_processor_test.dart`
Expected: PASS (10 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/sound_events/sound_event_processor.dart app/test/sound_events/sound_event_processor_test.dart
git commit -m "feat: add SoundEventProcessor decision pipeline"
```

---

## Task 5: Concurrence entre catégories (test 8)

Vérifie que deux catégories différentes traitées sans attendre l'une l'autre ne produisent pas de vibrations incohérentes — en s'appuyant entièrement sur la politique "dernier gagne" déjà testée dans `HapticEngine`, sans aucune logique supplémentaire côté `SoundEventProcessor`.

**Files:**
- Modify: `app/test/sound_events/sound_event_processor_test.dart`

**Interfaces:**
- Consumes: `SoundEventProcessor.process` (Task 4) — aucune modification de production attendue si le pipeline est correctement construit sur `HapticEngine`.

- [ ] **Step 1: Ajouter le test qui doit déjà passer (non-régression du comportement hérité)**

Ajouter à la fin de `main()` dans `app/test/sound_events/sound_event_processor_test.dart` :

```dart
  test('TEST 8 — deux catégories quasi simultanées ne provoquent pas de '
      'vibrations concurrentes incohérentes', () async {
    final first = processor.process(
      event(category: 'sonnette', score: 0.9, timestamp: t0),
    );
    final second = processor.process(
      event(category: 'aboiement', score: 0.9, timestamp: t0),
    );

    final results = await Future.wait([first, second]);

    // Un seul motif net a réellement vibré : celui du second appel, la
    // politique "dernier gagne" de HapticEngine ayant annulé le premier
    // avant qu'il ne vibre (comportement hérité, pas réimplémenté ici).
    expect(executor.vibrateCalls, hasLength(1));
    expect(results.map((r) => r.status), everyElement(isNot(SoundEventStatus.hapticFailure)));
  });
```

- [ ] **Step 2: Lancer le test**

Run: `cd app && flutter test test/sound_events/sound_event_processor_test.dart --name "TEST 8"`
Expected: PASS immédiatement — ce test vérifie un comportement déjà garanti par `HapticEngine` (voir sa propre suite de tests, module précédent), pas un nouveau mécanisme. S'il échoue, c'est que `SoundEventProcessor.process` a introduit un `await` supplémentaire avant l'appel à `_hapticEngine.playForCategory` qui casse l'ordonnancement synchrone dont dépend la garantie "dernier gagne" — dans ce cas, revoir le Step 3 de la Task 4 (aucune étape du pipeline avant le déclenchement haptique ne doit être asynchrone).

- [ ] **Step 3: Lancer toute la suite du module pour confirmer qu'il n'y a pas de régression**

Run: `cd app && flutter test test/sound_events/`
Expected: PASS (18 tests : 1 + 4 + 2 + 11 répartis sur les 4 fichiers de test du module, la Task 4 en apportant 10 et ce Step en ajoutant le 11e au fichier processor)

- [ ] **Step 4: Commit**

```bash
git add app/test/sound_events/sound_event_processor_test.dart
git commit -m "test: pin cross-category concurrency guarantee inherited from HapticEngine"
```
