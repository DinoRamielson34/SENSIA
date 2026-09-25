import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/haptics/haptic_engine.dart';
import 'package:izahay/haptics/models/vibration_pattern.dart';
import 'package:izahay/simulation/event_simulator.dart';
import 'package:izahay/simulation/simulation_scenarios.dart';
import 'package:izahay/sound_events/category_settings.dart';
import 'package:izahay/sound_events/sound_event.dart';
import 'package:izahay/sound_events/sound_event_processor.dart';
import 'package:izahay/sound_events/sound_event_result.dart';

import '../haptics/fake_vibration_executor.dart';

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

    test('send() délègue réellement à LA MÊME instance de processor '
        '(pas seulement un résultat équivalent) : un appel via le '
        'simulateur laisse une trace d\'état visible en appelant '
        'directement ce même processor juste après', () async {
      final event = SimulationScenarios.sonnette();

      await simulator.send(event);
      // Si simulator.send() avait sa propre logique au lieu de déléguer
      // à `processor`, cet appel DIRECT sur ce MÊME processor ne verrait
      // aucun état de cooldown : il redéclencherait au lieu d'être
      // bloqué. Seule une vraie délégation à cette instance précise
      // laisse cette trace.
      final justeApres = await processor.process(event);

      expect(justeApres.status, SoundEventStatus.inCooldown);
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

    test('sendSeries() avec un délai factice fait quand même avancer '
        'l\'horodatage des événements : l\'anti-répétition se comporte '
        'comme sur un vrai appareil, pas comme si tout arrivait au même '
        'instant', () async {
      // Délai factice (zéro attente réelle) mais SUPÉRIEUR au cooldown
      // par défaut (5s) : sur un vrai appareil, les 2 événements
      // déclencheraient tous les deux. Si l'horodatage n'avançait pas
      // avec le délai simulé, le 2e serait à tort bloqué par
      // l'anti-répétition.
      final simulatorAvecDelaiFactice = EventSimulator(
        processor: processor,
        delay: (_) async {},
      );

      final results = await simulatorAvecDelaiFactice.sendSeries(
        category: 'sonnette',
        score: 0.9,
        count: 2,
        delay: const Duration(seconds: 6),
      );

      expect(
        results.map((r) => r.status),
        [SoundEventStatus.triggered, SoundEventStatus.triggered],
      );
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
