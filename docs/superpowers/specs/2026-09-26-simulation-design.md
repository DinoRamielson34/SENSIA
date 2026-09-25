# Module de simulation et tests IZAHAY — design

Date: 2026-09-26
Auteur: Personne 3 (moteur de vibrations, traitement des événements, Firebase, historique, simulation)
Statut: approuvé pour implémentation

## Contexte

Quatrième et dernier module prévu de la personne 3, après le moteur de
vibrations, le traitement des événements sonores et le module
Firebase/historique — tous livrés, testés (unitairement et, pour Firebase,
contre un vrai projet), et déjà revus.

Ce module permet de simuler des événements sonores et de tester
l'ensemble de la chaîne (traitement → vibrations → historique) sans
microphone ni modèle IA, dès maintenant, et de faciliter l'intégration du
modèle IA quand il sera disponible.

État du projet au moment de l'écriture : `lib/haptics/`, `lib/sound_events/`
et `lib/history/` complets et testés. `lib/firebase_options.dart` et
`android/app/google-services.json` configurés contre un vrai projet
Firebase (`izahay-703fd`), règles de sécurité déployées.

## Constat de conception (validé avec l'auteur)

La plupart des scénarios de test demandés par ce module (ÉTAPE 5 de la
demande) sont déjà couverts par les suites de tests des modules
précédents, puisqu'un événement simulé traverse exactement le même
pipeline qu'un événement réel :

| Test demandé | Déjà couvert par |
|---|---|
| TEST 1 — catégorie valide déclenche | `sound_event_processor_test.dart` (TEST 1) |
| TEST 2 — catégorie désactivée | `sound_event_processor_test.dart` (TEST 2) |
| TEST 3 — score insuffisant | `sound_event_processor_test.dart` (TEST 3) |
| TEST 4 — anti-répétition | `sound_event_processor_test.dart` (TEST 4) |
| TEST 5 — confirmation | `sound_event_processor_test.dart` (confirmation multi-fenêtres) |
| TEST 6 — catégorie inconnue, pas de crash | `sound_event_processor_test.dart` (TEST 5) |
| TEST 8 — arrêt de l'écoute | `sound_event_processor_test.dart` (TEST 7) |
| TEST 9 — historique enregistré | `history_result_sink_test.dart` |
| TEST 10 — statut simulé conservé | `sound_event_processor_test.dart` (TEST 6) |
| TEST 11 — vibrations sans réseau | `sound_event_processor_test.dart` (historySink jamais attendu) |
| TEST 12 — événements concurrents cohérents | `sound_event_processor_test.dart` (TEST 8) |

Ce module n'a donc pas à réimplémenter ces règles métier (ce serait un
second circuit de traitement, explicitement interdit par la demande).
Son travail propre :

1. Une façon ergonomique de **générer** des événements de test, au lieu
   d'écrire des `SoundEvent` à la main partout.
2. Une **preuve** que le simulateur n'introduit aucun circuit parallèle :
   il appelle `SoundEventProcessor.process()` exactement comme le ferait
   le module IA.
3. Les deux scénarios réellement nouveaux : **TEST 7** (motif
   personnalisé exécuté correctement de bout en bout) et la génération
   en série avec délai configurable (comportement propre au simulateur,
   absent des modules précédents).
4. Une interface de debug qui connecte pour la première fois le pipeline
   complet **réel** (traitement + vibrations + historique Firebase réel)
   — les écrans de debug précédents testaient chaque module isolément.
5. Un protocole de test sur téléphone physique documenté, avec des
   champs vides à remplir par l'auteur — aucun résultat ni taux de
   fiabilité inventé.

## Objectifs

1. Générer des événements simulés respectant exactement le contrat
   `SoundEvent` déjà défini.
2. Couvrir les 7 scénarios de génération de l'ÉTAPE 2 : sonnette,
   aboiement, catégorie inconnue, score sous le seuil, événements
   identiques répétés, deux catégories quasi simultanées, événement reçu
   écoute arrêtée.
3. Permettre de configurer catégorie, score, nombre d'événements, délai
   entre eux.
4. Transmettre les événements simulés au `SoundEventProcessor` existant,
   sans nouveau circuit de traitement, sans nouveaux seuils, sans nouveau
   moteur de vibrations ni système d'historique.
5. Conserver la distinction événement simulé/réel dans les données
   (`isSimulation`, déjà porté par `SoundEvent`/`SoundEventResult`).
6. Une interface technique minimale de test, indépendante des écrans de
   la personne 2.
7. Documenter (sans l'automatiser) le protocole de test sur téléphone
   physique.

## Non-objectifs

- Pas de nouveau moteur de vibrations ni de nouveau moteur de
  traitement — réutilisation stricte de `HapticEngine` et
  `SoundEventProcessor`.
- Pas de remplacement du module Firebase existant.
- Pas de nouvelle application complète pour tester le simulateur — un
  écran minimal suffit (voir Architecture).
- Pas de résultats de test physique fabriqués : le protocole reste un
  document à remplir, jamais des chiffres inventés par l'auteur du code.
- Pas de nouvelle dépendance pub.dev pour l'horloge de test (voir
  décision ci-dessous).

## Décisions de conception (validées)

1. **`EventSimulator` ne contient aucune règle métier.** Il construit des
   `SoundEvent` et les transmet à un `SoundEventProcessor` injecté au
   constructeur — toute la décision (seuil, confirmation, anti-répétition,
   déclenchement) reste dans le module déjà livré et testé.
2. **Délai entre événements injectable, pas de nouvelle dépendance.**
   Plutôt qu'un package comme `fake_async`, `EventSimulator` accepte une
   fonction `Future<void> Function(Duration) delay` (défaut :
   `Future.delayed`), remplaçable en test par une fonction qui ne fait
   rien — conforme à la consigne "éviter les délais réels inutiles, horloge
   simulée" sans dépendance supplémentaire, et cohérent avec le style
   d'injection déjà utilisé dans tout le projet (`VibrationExecutor`,
   `HistoryRepository`...).
3. **Un seul nouvel écran de debug**, branché sur le vrai `HapticEngine`
   et la vraie `FirestoreHistoryRepository` (le projet Firebase réel est
   maintenant configuré) : c'est la première fois que le pipeline complet
   est testable de bout en bout sur un vrai appareil, pas seulement
   module par module.
4. **Le déclenchement manuel direct d'un motif** (contournant la
   reconnaissance, ÉTAPE 3 "Attention") reste ce que fait déjà
   `haptics_debug_main.dart` — un écran séparé, explicitement nommé "test
   moteur haptique", déjà identifiable comme une action de test. Aucun
   nouveau code requis pour cette exigence, seulement le rappel dans la
   livraison finale.

## Architecture

```
lib/simulation/
├── event_simulator.dart        # Génère et transmet des SoundEvent au SoundEventProcessor
└── simulation_scenarios.dart   # 7 constructeurs nommés (ÉTAPE 2), aucune logique métier

lib/simulation_debug_main.dart  # Point d'entrée séparé, pipeline réel complet
```

### `EventSimulator` (`event_simulator.dart`)

```dart
class EventSimulator {
  EventSimulator({
    required SoundEventProcessor processor,
    Future<void> Function(Duration) delay = Future.delayed,
  });

  /// Envoie [event] au processor, exactement comme le ferait le module IA.
  Future<SoundEventResult> send(SoundEvent event);

  /// Envoie [count] événements de [category]/[score], espacés de [delay]
  /// entre chaque envoi (pas avant le premier).
  Future<List<SoundEventResult>> sendSeries({
    required String category,
    required double score,
    required int count,
    Duration delay = Duration.zero,
    String source = 'simulation',
  });
}
```

### `simulation_scenarios.dart`

Sept fonctions pures (aucun accès à `SoundEventProcessor`), chacune
retournant un ou plusieurs `SoundEvent` déjà formés, nommées d'après
l'ÉTAPE 2 : `sonnette()`, `aboiement()`, `unknownCategory()`,
`belowThreshold(String category, double threshold)`,
`repeatedIdentical(String category, {int count})`,
`nearSimultaneousDifferentCategories(String a, String b)`,
`whileListeningStopped(String category)` (retourne l'événement ;
l'appelant doit avoir appelé `processor.stopListening()` avant de
l'envoyer — cette fonction ne pilote pas l'état d'écoute, elle ne fait
que construire l'événement, cohérent avec la règle n°1 ci-dessus).

### `simulation_debug_main.dart`

Écran minimal : sélection de catégorie (liste des catégories connues de
`SoundEventSettings`), champ score, bouton "Envoyer", affichage du
`SoundEventResult` (statut, raison), branché sur :
`HapticEngine(executor: MethodChannelVibrationExecutor())`,
`FirestoreHistoryRepository()`, `SoundEventProcessor(hapticEngine: ...,
historySink: HistoryResultSink(repository: ...))`.

## Stratégie de tests

Nouveau `test/simulation/event_simulator_test.dart`, avec
`FakeVibrationExecutor` (déjà livré) et un `HapticEngine`/
`SoundEventProcessor` réels montés dessus (aucun réseau, aucun
microphone) :

- Chaque scénario de `simulation_scenarios.dart` produit la forme
  d'événement attendue (catégorie, score, `source`, `isSimulation`).
- **Preuve d'absence de second circuit** : envoyer un événement via
  `EventSimulator.send()` produit un résultat strictement identique
  (même statut, même appel à l'executor) qu'un appel direct à
  `processor.process()` avec le même événement.
- `sendSeries()` avec un délai factice (fonction injectée, zéro attente
  réelle) : le bon nombre d'événements est envoyé, dans l'ordre, avec le
  délai demandé passé à la fonction injectée (vérifiable sans horloge
  réelle).
- **TEST 7 — personnalisation** : `hapticEngine.registerPattern(...)` et
  `settings.updateCategory(...)` avec un motif sur mesure, puis
  `EventSimulator.send()` sur cette catégorie → le bon motif natif est
  exécuté (vérifié via `FakeVibrationExecutor.vibrateCalls`).

Les 10 autres tests demandés restent dans leurs fichiers d'origine (pas
de duplication) — rappelés dans la livraison finale avec leur
emplacement exact.

## Protocole de test sur téléphone physique (document, pas de code)

Nouveau fichier `docs/superpowers/device-tests/simulation-protocol.md` :
les 7 points de l'ÉTAPE 6, plus un tableau de consignation par essai
(catégorie attendue/reconnue, score, téléphone, source audio, distance
approximative, bruit ambiant, résultat, délai son→vibration si
mesurable) — champs vides, à remplir par l'auteur après exécution réelle.
Aucun taux de fiabilité ni latence non mesurés n'y sera jamais inscrit
par avance.

## Fichiers créés

- `app/lib/simulation/event_simulator.dart`
- `app/lib/simulation/simulation_scenarios.dart`
- `app/lib/simulation_debug_main.dart`
- `app/test/simulation/event_simulator_test.dart`
- `docs/superpowers/device-tests/simulation-protocol.md`

## Fichiers modifiés

Aucun. `lib/haptics/**`, `lib/sound_events/**`, `lib/history/**`,
`lib/main.dart` restent inchangés.
