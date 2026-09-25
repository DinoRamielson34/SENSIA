# Module de simulation et tests — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fournir un simulateur d'événements sonores qui génère des `SoundEvent` et les transmet au `SoundEventProcessor` déjà livré exactement comme le ferait le module IA — sans second circuit de traitement — plus un écran de debug qui connecte pour la première fois le pipeline complet réel (traitement + vibrations + historique Firebase).

**Architecture:** `lib/simulation/simulation_scenarios.dart` (7 constructeurs purs de `SoundEvent`, aucune règle métier) + `lib/simulation/event_simulator.dart` (délégation pure à `SoundEventProcessor.process()`, génération en série avec délai injectable) + `lib/simulation_debug_main.dart` (écran minimal, injecté donc testable sans Firebase).

**Tech Stack:** Flutter/Dart (SDK `^3.12.0`), réutilise `HapticEngine`/`SoundEventProcessor`/`FirestoreHistoryRepository` déjà livrés. Aucune nouvelle dépendance pub.dev.

**Spec:** [docs/superpowers/specs/2026-09-26-simulation-design.md](../specs/2026-09-26-simulation-design.md)

## Global Constraints

- `EventSimulator` ne duplique aucune règle métier : il délègue à 100% à `SoundEventProcessor.process()`, jamais de logique de seuil/confirmation/anti-répétition propre.
- Aucune modification de `lib/haptics/**`, `lib/sound_events/**`, `lib/history/**`, `lib/main.dart`.
- Aucune nouvelle dépendance pub.dev pour l'horloge de test — délai injecté via une fonction (`Future<void> Function(Duration)`), pas de package `fake_async`.
- Le protocole de test sur téléphone physique reste un document à champs vides — aucun résultat, taux de fiabilité ou latence fabriqué.
- Le contournement volontaire de la reconnaissance sonore pour un test manuel direct de motif (`lib/haptics_debug_main.dart`, déjà livré) reste identifiable comme une action de test — pas de nouveau code requis pour cette exigence, seulement un rappel dans la livraison finale.

## Review Focus

- `EventSimulator.send()` doit être prouvé strictement identique en résultat à un appel direct à `processor.process()` — pas seulement "semble déléguer à la lecture du code". Couvert par la Task 2.
- Le délai de `sendSeries()` doit être vérifié via la fonction de délai injectée (nombre d'appels, durée passée), prouvant qu'aucune attente réelle n'a lieu — pas seulement "le test est rapide". Couvert par la Task 2.
- TEST 7 (motif personnalisé) doit exercer le chemin complet (`registerPattern` + `updateCategory` + `simulator.send`) et vérifier le tableau natif exact exécuté, pas seulement l'absence d'exception. Couvert par la Task 2.
- Le scénario 7 (écoute arrêtée) doit être testé en passant réellement par la porte d'écoute du processor (`stopListening()` puis envoi), pas seulement en vérifiant la forme de l'événement généré. Couvert par la Task 1 (forme) et la Task 2 (comportement réel).
- La liste déroulante de catégories de l'écran de debug doit refléter les catégories réellement configurées (`settings.all.keys`), jamais une liste codée en dur qui pourrait diverger de la config réelle. Couvert par la Task 3.

---

## Task 1: `SimulationScenarios` — générateurs d'événements

**Files:**
- Create: `app/lib/simulation/simulation_scenarios.dart`
- Create: `app/test/simulation/event_simulator_test.dart` (fichier de test unique du module — voir spec)

**Interfaces:**
- Consumes: `SoundEvent` (déjà livré, `app/lib/sound_events/sound_event.dart`)
- Produces: `SimulationScenarios.sonnette()`, `.aboiement()`, `.unknownCategory()`, `.belowThreshold(category, {threshold})`, `.repeatedIdentical(category, {score, count})`, `.nearSimultaneousDifferentCategories(a, b)`, `.whileListeningStopped(category)` — utilisés par la Task 2.

- [ ] **Step 1: Écrire les tests qui échouent**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/simulation/simulation_scenarios.dart';

void main() {
  group('SimulationScenarios — forme des événements générés', () {
    test('sonnette() : catégorie "sonnette", simulé, score élevé', () {
      final event = SimulationScenarios.sonnette();
      expect(event.category, 'sonnette');
      expect(event.isSimulation, isTrue);
      expect(event.source, 'simulation');
      expect(event.score, greaterThan(0.75));
    });

    test('aboiement() : catégorie "aboiement", simulé, score élevé', () {
      final event = SimulationScenarios.aboiement();
      expect(event.category, 'aboiement');
      expect(event.isSimulation, isTrue);
      expect(event.score, greaterThan(0.75));
    });

    test('unknownCategory() : catégorie qui n\'est jamais une catégorie '
        'de démonstration connue', () {
      final event = SimulationScenarios.unknownCategory();
      expect(event.category, isNot(anyOf('sonnette', 'aboiement')));
      expect(event.isSimulation, isTrue);
    });

    test('belowThreshold() : score strictement sous le seuil donné', () {
      final event = SimulationScenarios.belowThreshold('sonnette', threshold: 0.75);
      expect(event.score, lessThan(0.75));
      expect(event.category, 'sonnette');
    });

    test('repeatedIdentical() : N événements identiques (catégorie, '
        'score, horodatage)', () {
      final events = SimulationScenarios.repeatedIdentical('aboiement', count: 4);
      expect(events, hasLength(4));
      expect(events.map((e) => e.category).toSet(), {'aboiement'});
      expect(events.map((e) => e.score).toSet(), hasLength(1));
      expect(events.map((e) => e.timestamp).toSet(), hasLength(1));
    });

    test('nearSimultaneousDifferentCategories() : deux catégories '
        'différentes, même horodatage', () {
      final (a, b) = SimulationScenarios.nearSimultaneousDifferentCategories(
        'sonnette',
        'aboiement',
      );
      expect(a.category, 'sonnette');
      expect(b.category, 'aboiement');
      expect(a.timestamp, b.timestamp);
    });

    test('whileListeningStopped() : source "microphone", PAS simulé '
        '(nécessaire pour tester la porte d\'écoute réelle)', () {
      final event = SimulationScenarios.whileListeningStopped('sonnette');
      expect(event.source, 'microphone');
      expect(event.isSimulation, isFalse);
    });
  });
}
```

- [ ] **Step 2: Lancer les tests et vérifier qu'ils échouent**

Run: `cd app && flutter test test/simulation/event_simulator_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:izahay/simulation/simulation_scenarios.dart'`

- [ ] **Step 3: Implémenter**

```dart
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
  static SoundEvent unknownCategory({
    String category = 'categorie-inconnue-simulee',
    DateTime? timestamp,
  }) =>
      SoundEvent(
        category: category,
        score: 0.95,
        timestamp: timestamp ?? DateTime.now(),
        source: 'simulation',
        isSimulation: true,
      );

  /// Scénario 4 — un score volontairement sous [threshold].
  static SoundEvent belowThreshold(
    String category, {
    double threshold = 0.75,
    DateTime? timestamp,
  }) =>
      SoundEvent(
        category: category,
        score: (threshold - 0.1).clamp(0.0, 1.0),
        timestamp: timestamp ?? DateTime.now(),
        source: 'simulation',
        isSimulation: true,
      );

  /// Scénario 5 — [count] événements identiques successifs (même
  /// catégorie, même score, même horodatage), utile pour tester
  /// l'anti-répétition.
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
  static SoundEvent whileListeningStopped(
    String category, {
    DateTime? timestamp,
  }) =>
      SoundEvent(
        category: category,
        score: 0.9,
        timestamp: timestamp ?? DateTime.now(),
        source: 'microphone',
        isSimulation: false,
      );
}
```

- [ ] **Step 4: Lancer les tests et vérifier qu'ils passent**

Run: `cd app && flutter test test/simulation/event_simulator_test.dart`
Expected: PASS (7 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/simulation/simulation_scenarios.dart app/test/simulation/event_simulator_test.dart
git commit -m "feat: add SimulationScenarios event generators"
```

---

## Task 2: `EventSimulator`

Le cœur du module : délégation pure au `SoundEventProcessor`, génération en série avec délai injectable, et la preuve qu'aucun second circuit de traitement n'existe.

**Files:**
- Create: `app/lib/simulation/event_simulator.dart`
- Modify: `app/test/simulation/event_simulator_test.dart` (ajout des tests, fichier créé en Task 1)

**Interfaces:**
- Consumes: `SoundEventProcessor`/`SoundEventResult`/`SoundEventStatus` (déjà livrés), `SimulationScenarios` (Task 1), `HapticEngine`/`FakeVibrationExecutor` (déjà livrés, pour les tests)
- Produces: `EventSimulator({required SoundEventProcessor processor, Future<void> Function(Duration)? delay})`, `.send(SoundEvent) -> Future<SoundEventResult>`, `.sendSeries({required category, required score, required count, Duration delay, String source}) -> Future<List<SoundEventResult>>` — utilisé par la Task 3.

- [ ] **Step 1: Écrire les tests qui échouent**

Ajouter à la fin de `main()` dans `app/test/simulation/event_simulator_test.dart` (et ajouter les imports nécessaires en tête de fichier — voir Step 1bis) :

```dart
  group('EventSimulator', () {
    late FakeVibrationExecutor executor;
    late HapticEngine hapticEngine;
    late SoundEventProcessor processor;
    late EventSimulator simulator;

    setUp(() {
      executor = FakeVibrationExecutor();
      hapticEngine = HapticEngine(executor: executor);
      processor = SoundEventProcessor(hapticEngine: hapticEngine);
      simulator = EventSimulator(processor: processor);
    });

    test('send() ne duplique aucune règle métier : résultat et effets '
        'strictement identiques à un appel direct à processor.process() '
        'avec le même événement', () async {
      final event = SimulationScenarios.sonnette();

      final viaSimulator = await simulator.send(event);

      // Deuxième processor/executor indépendants, même configuration,
      // pour comparer un appel DIRECT sur un état vierge équivalent.
      final directExecutor = FakeVibrationExecutor();
      final directProcessor = SoundEventProcessor(
        hapticEngine: HapticEngine(executor: directExecutor),
      );
      final direct = await directProcessor.process(event);

      expect(viaSimulator.status, direct.status);
      expect(viaSimulator.isSimulation, direct.isSimulation);
      expect(executor.vibrateCalls, directExecutor.vibrateCalls);
    });

    test('send() sur le scénario 7 est réellement bloqué par '
        'stopListening(), pas seulement de la bonne forme', () async {
      processor.stopListening();

      final result = await simulator.send(
        SimulationScenarios.whileListeningStopped('sonnette'),
      );

      expect(result.status, SoundEventStatus.listeningStopped);
      expect(executor.vibrateCalls, isEmpty);
    });

    test('sendSeries() envoie N événements dans l\'ordre, avec le délai '
        'injecté (jamais Future.delayed réel) entre chaque envoi',
        () async {
      final delaisRecus = <Duration>[];
      final simulatorAvecDelaiFactice = EventSimulator(
        processor: processor,
        delay: (duration) async => delaisRecus.add(duration),
      );

      final results = await simulatorAvecDelaiFactice.sendSeries(
        category: 'sonnette',
        score: 0.9,
        count: 3,
        delay: const Duration(milliseconds: 500),
      );

      expect(results, hasLength(3));
      // count-1 délais : jamais avant le tout premier envoi.
      expect(delaisRecus, [
        const Duration(milliseconds: 500),
        const Duration(milliseconds: 500),
      ]);
    });

    test('sendSeries() marque bien chaque événement comme simulé', () async {
      final results = await simulator.sendSeries(
        category: 'sonnette',
        score: 0.9,
        count: 2,
      );

      expect(results.every((r) => r.isSimulation), isTrue);
    });

    test('TEST 7 — un motif personnalisé enregistré est correctement '
        'exécuté de bout en bout via le simulateur', () async {
      hapticEngine.registerPattern(
        'alarme-perso',
        const VibrationPattern(
          id: 'alarme-perso',
          pulses: [
            VibrationPulse(
              vibrate: Duration(milliseconds: 120),
              pauseAfter: Duration(milliseconds: 80),
            ),
            VibrationPulse(vibrate: Duration(milliseconds: 300)),
          ],
        ),
      );
      processor.settings.updateCategory(
        'alarme-perso',
        const CategorySettings(
          enabled: true,
          threshold: 0.5,
          requiredConfirmations: 1,
          cooldown: Duration(seconds: 1),
        ),
      );

      final result = await simulator.send(SoundEvent(
        category: 'alarme-perso',
        score: 0.9,
        timestamp: DateTime.now(),
        source: 'simulation',
        isSimulation: true,
      ));

      expect(result.status, SoundEventStatus.triggered);
      expect(executor.vibrateCalls.single, [0, 120, 80, 300, 0]);
    });
  });
}
```

Ajouter en tête de fichier (Step 1bis, avant `void main() {`) :

```dart
import 'package:izahay/haptics/haptic_engine.dart';
import 'package:izahay/haptics/models/vibration_pattern.dart';
import 'package:izahay/simulation/event_simulator.dart';
import 'package:izahay/sound_events/category_settings.dart';
import 'package:izahay/sound_events/sound_event_processor.dart';
import 'package:izahay/sound_events/sound_event_result.dart';

import '../haptics/fake_vibration_executor.dart';
```

(Le `}` fermant de `main()` doit être déplacé en fin de fichier, après ce nouveau `group('EventSimulator', ...)`.)

- [ ] **Step 2: Lancer les tests et vérifier qu'ils échouent**

Run: `cd app && flutter test test/simulation/event_simulator_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:izahay/simulation/event_simulator.dart'`

- [ ] **Step 3: Implémenter**

```dart
import '../sound_events/sound_event.dart';
import '../sound_events/sound_event_processor.dart';
import '../sound_events/sound_event_result.dart';

/// Génère et transmet des événements sonores simulés au
/// [SoundEventProcessor] existant, exactement comme le ferait le module
/// de reconnaissance sonore (IA). Ne contient aucune règle métier : toute
/// la décision (seuil, confirmation, anti-répétition, déclenchement)
/// reste dans le processor déjà livré et testé.
class EventSimulator {
  final SoundEventProcessor _processor;
  final Future<void> Function(Duration duration) _delay;

  EventSimulator({
    required SoundEventProcessor processor,
    Future<void> Function(Duration duration)? delay,
  })  : _processor = processor,
        _delay = delay ?? _realDelay;

  static Future<void> _realDelay(Duration duration) =>
      Future<void>.delayed(duration);

  /// Envoie [event] au processor, sans aucune transformation : c'est
  /// exactement l'appel que ferait le module IA en conditions réelles.
  /// Ne lève jamais d'exception métier (voir `SoundEventProcessor`) :
  /// retourne toujours un [SoundEventResult].
  Future<SoundEventResult> send(SoundEvent event) => _processor.process(event);

  /// Construit et envoie [count] événements de [category]/[score], à
  /// intervalle [delay] entre chaque envoi (aucun délai avant le
  /// premier). Retourne les résultats dans l'ordre d'envoi.
  ///
  /// [delay] utilise la fonction de temporisation injectée au
  /// constructeur (par défaut une vraie attente ; remplaçable en test
  /// pour éviter toute attente réelle).
  Future<List<SoundEventResult>> sendSeries({
    required String category,
    required double score,
    required int count,
    Duration delay = Duration.zero,
    String source = 'simulation',
  }) async {
    final results = <SoundEventResult>[];
    for (var i = 0; i < count; i++) {
      if (i > 0 && delay > Duration.zero) {
        await _delay(delay);
      }
      final result = await send(SoundEvent(
        category: category,
        score: score,
        timestamp: DateTime.now(),
        source: source,
        isSimulation: true,
      ));
      results.add(result);
    }
    return results;
  }
}
```

- [ ] **Step 4: Lancer les tests et vérifier qu'ils passent, puis toute la suite du projet**

Run: `cd app && flutter test test/simulation/event_simulator_test.dart`
Expected: PASS (12 tests : 7 de la Task 1 + 5 nouveaux)

Run: `cd app && flutter test`
Expected: PASS (83 tests : 71 précédant ce plan + 12 — aucune régression ailleurs)

- [ ] **Step 5: Commit**

```bash
git add app/lib/simulation/event_simulator.dart app/test/simulation/event_simulator_test.dart
git commit -m "feat: add EventSimulator delegating to SoundEventProcessor"
```

---

## Task 3: Écran de debug — pipeline complet réel

Premier écran à connecter le vrai `HapticEngine`, la vraie `FirestoreHistoryRepository` et le `SoundEventProcessor` ensemble — les écrans précédents testaient chaque module isolément.

**Files:**
- Create: `app/lib/simulation_debug_main.dart`
- Create: `app/test/simulation/simulation_debug_screen_test.dart`

**Interfaces:**
- Consumes: `EventSimulator` (Task 2), `HapticEngine`/`MethodChannelVibrationExecutor` (déjà livrés), `FirestoreHistoryRepository`/`HistoryResultSink` (déjà livrés), `SoundEventProcessor` (déjà livré)

- [ ] **Step 1: Écrire les tests qui échouent**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/haptics/haptic_engine.dart';
import 'package:izahay/simulation/event_simulator.dart';
import 'package:izahay/simulation_debug_main.dart';
import 'package:izahay/sound_events/sound_event_processor.dart';

import '../haptics/fake_vibration_executor.dart';

void main() {
  testWidgets('envoyer un événement pour une catégorie connue affiche le '
      'statut déclenché et vibre', (tester) async {
    final executor = FakeVibrationExecutor();
    final processor = SoundEventProcessor(
      hapticEngine: HapticEngine(executor: executor),
    );
    final simulator = EventSimulator(processor: processor);

    await tester.pumpWidget(SimulationDebugApp(
      simulator: simulator,
      knownCategories: const ['sonnette', 'aboiement'],
    ));
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();

    expect(find.textContaining('triggered'), findsOneWidget);
    expect(executor.vibrateCalls, isNotEmpty);
  });

  testWidgets('changer de catégorie via le menu déroulant envoie la '
      'bonne catégorie', (tester) async {
    final executor = FakeVibrationExecutor();
    final processor = SoundEventProcessor(
      hapticEngine: HapticEngine(executor: executor),
    );
    final simulator = EventSimulator(processor: processor);

    await tester.pumpWidget(SimulationDebugApp(
      simulator: simulator,
      knownCategories: const ['sonnette', 'aboiement'],
    ));
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('aboiement').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();

    expect(executor.vibrateCalls.single, [0, 400, 200, 400, 200, 400, 0]);
  });
}
```

- [ ] **Step 2: Lancer les tests et vérifier qu'ils échouent**

Run: `cd app && flutter test test/simulation/simulation_debug_screen_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:izahay/simulation_debug_main.dart'`

- [ ] **Step 3: Implémenter l'écran**

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'haptics/haptic_engine.dart';
import 'haptics/vibration_executor.dart';
import 'history/firestore_history_repository.dart';
import 'history/history_result_sink.dart';
import 'simulation/event_simulator.dart';
import 'sound_events/sound_event.dart';
import 'sound_events/sound_event_processor.dart';

/// Point d'entrée séparé pour tester manuellement le pipeline complet
/// (traitement + vibrations + historique Firebase réel), sans
/// microphone ni IA.
///
/// Lancer avec : flutter run -t lib/simulation_debug_main.dart
/// Se connecte au vrai projet Firebase (voir lib/firebase_options.dart).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final hapticEngine = HapticEngine(executor: const MethodChannelVibrationExecutor());
  final historyRepository = FirestoreHistoryRepository();
  final processor = SoundEventProcessor(
    hapticEngine: hapticEngine,
    historySink: HistoryResultSink(repository: historyRepository),
  );

  runApp(SimulationDebugApp(
    simulator: EventSimulator(processor: processor),
    knownCategories: processor.settings.all.keys.toList(),
  ));
}

class SimulationDebugApp extends StatelessWidget {
  final EventSimulator simulator;
  final List<String> knownCategories;

  const SimulationDebugApp({
    super.key,
    required this.simulator,
    required this.knownCategories,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IZAHAY — Test simulation',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: SimulationDebugScreen(
        simulator: simulator,
        knownCategories: knownCategories,
      ),
    );
  }
}

class SimulationDebugScreen extends StatefulWidget {
  final EventSimulator simulator;
  final List<String> knownCategories;

  const SimulationDebugScreen({
    super.key,
    required this.simulator,
    required this.knownCategories,
  });

  @override
  State<SimulationDebugScreen> createState() => _SimulationDebugScreenState();
}

class _SimulationDebugScreenState extends State<SimulationDebugScreen> {
  late String _category =
      widget.knownCategories.isNotEmpty ? widget.knownCategories.first : 'sonnette';
  double _score = 0.9;
  String _status = '';

  Future<void> _send() async {
    try {
      final result = await widget.simulator.send(SoundEvent(
        category: _category,
        score: _score,
        timestamp: DateTime.now(),
        source: 'simulation',
        isSimulation: true,
      ));
      setState(() {
        _status = result.reason != null
            ? '${result.status.name} — ${result.reason}'
            : result.status.name;
      });
    } catch (e) {
      setState(() => _status = 'Erreur : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test simulation')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButton<String>(
              value: _category,
              items: widget.knownCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            Slider(
              value: _score,
              onChanged: (value) => setState(() => _score = value),
              label: _score.toStringAsFixed(2),
            ),
            FilledButton(onPressed: _send, child: const Text('Envoyer')),
            const SizedBox(height: 16),
            Text('Résultat : $_status'),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Lancer les tests et vérifier qu'ils passent, puis toute la suite du projet**

Run: `cd app && flutter test test/simulation/simulation_debug_screen_test.dart`
Expected: PASS (2 tests)

Run: `cd app && flutter test`
Expected: PASS (85 tests : 83 précédents + 2 — aucune régression ailleurs)

Run: `cd app && flutter analyze lib/simulation lib/simulation_debug_main.dart`
Expected: aucune erreur (infos de style éventuelles acceptables, voir les rulings des modules précédents).

- [ ] **Step 5: Commit**

```bash
git add app/lib/simulation_debug_main.dart app/test/simulation/simulation_debug_screen_test.dart
git commit -m "feat: add simulation debug entrypoint wiring the full real pipeline"
```

---

## Task 4: Protocole de test sur téléphone physique

Document seul, pas de code — les 7 points de l'ÉTAPE 6 de la demande, plus un tableau de consignation à champs vides.

**Files:**
- Create: `docs/superpowers/device-tests/simulation-protocol.md`

- [ ] **Step 1: Rédiger le document**

```markdown
# Protocole de test IZAHAY sur téléphone physique

Ce document ne contient aucun résultat : les champs sont à remplir après
exécution réelle sur un appareil. Aucun taux de fiabilité ni latence n'est
annoncé tant qu'il n'a pas été mesuré.

## Points à vérifier

1. **Présence du moteur de vibration** : `HapticEngine.isDeviceCompatible()`
   retourne `true` sur l'appareil de test (voir `lib/haptics_debug_main.dart`).
2. **Exécution de deux motifs distincts** : déclencher "sonnette" puis
   "aboiement" depuis `lib/simulation_debug_main.dart` ou
   `lib/haptics_debug_main.dart`, confirmer que les deux vibrations sont
   perceptiblement différentes.
3. **Arrêt d'une vibration** : déclencher un motif long, appeler `stop()`
   en cours de route, confirmer l'arrêt immédiat.
4. **Fonctionnement hors ligne** : couper les données/Wi-Fi du téléphone,
   déclencher un événement simulé depuis `lib/simulation_debug_main.dart` —
   la vibration doit se produire normalement (l'historique se
   synchronisera plus tard, voir le module Firebase).
5. **Persistance de l'historique après redémarrage** : enregistrer un
   événement, fermer complètement l'app, la rouvrir, vérifier que
   l'historique est toujours présent.
6. **Réception de deux événements sonores différents (modèle IA
   disponible)** : à exécuter une fois le module de reconnaissance
   sonore livré par la personne 1 — hors de portée tant qu'il n'existe
   pas.
7. **Différence événement simulé / événement réellement reconnu** :
   vérifier que `SoundEventResult.isSimulation` (visible dans
   l'historique) distingue bien les deux.

## Tableau de consignation par essai

À dupliquer pour chaque essai réel (viser au moins 10 essais par
catégorie quand le temps le permet, une fois les catégories sonores
disponibles) :

| Champ | Valeur |
|---|---|
| Catégorie attendue | |
| Catégorie reconnue | |
| Score | |
| Téléphone utilisé | |
| Source audio | |
| Distance approximative | |
| Bruit ambiant | |
| Résultat | |
| Délai son → vibration (si mesurable) | |
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/device-tests/simulation-protocol.md
git commit -m "docs: add physical-device test protocol for simulation module"
```
