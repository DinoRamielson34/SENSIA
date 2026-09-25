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
}
