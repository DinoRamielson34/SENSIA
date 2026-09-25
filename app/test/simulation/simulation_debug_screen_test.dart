import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/haptics/haptic_engine.dart';
import 'package:izahay/simulation_debug_main.dart';
import 'package:izahay/sound_events/category_settings.dart';
import 'package:izahay/sound_events/sound_event_processor.dart';

import '../haptics/fake_vibration_executor.dart';

void main() {
  testWidgets('envoyer un événement pour une catégorie connue affiche le '
      'statut déclenché et vibre', (tester) async {
    final executor = FakeVibrationExecutor();
    final processor = SoundEventProcessor(
      hapticEngine: HapticEngine(executor: executor),
    );

    await tester.pumpWidget(SimulationDebugApp(processor: processor));
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

    await tester.pumpWidget(SimulationDebugApp(processor: processor));
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('aboiement').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();

    expect(executor.vibrateCalls.single, [0, 400, 200, 400, 200, 400, 0]);
  });

  testWidgets('la liste déroulante reflète les catégories réellement '
      'configurées sur le processor, y compris une catégorie ajoutée '
      'après coup — jamais une liste codée en dur', (tester) async {
    final executor = FakeVibrationExecutor();
    final processor = SoundEventProcessor(
      hapticEngine: HapticEngine(executor: executor),
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

    await tester.pumpWidget(SimulationDebugApp(processor: processor));
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('alarme-perso'), findsOneWidget);
  });
}
