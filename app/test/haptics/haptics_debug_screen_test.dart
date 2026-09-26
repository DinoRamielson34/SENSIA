import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/haptics/haptic_engine.dart';
import 'package:izahay/haptics_debug_main.dart';

import 'fake_vibration_executor.dart';

void main() {
  testWidgets('tapper sur un bouton de motif déclenche la vibration '
      'correspondante', (tester) async {
    final executor = FakeVibrationExecutor();
    final engine = HapticEngine(executor: executor);

    await tester.pumpWidget(HapticsDebugApp(engine: engine));
    await tester.tap(find.text('Tester "sonnette"'));
    await tester.pumpAndSettle();

    expect(executor.vibrateCalls, isNotEmpty);
    expect(find.textContaining('sonnette'), findsWidgets);
  });

  testWidgets('le bouton Arrêter appelle stop sur le moteur', (tester) async {
    final executor = FakeVibrationExecutor();
    final engine = HapticEngine(executor: executor);

    await tester.pumpWidget(HapticsDebugApp(engine: engine));
    await tester.tap(find.text('Arrêter'));
    await tester.pumpAndSettle();

    expect(executor.callLog, contains('cancel'));
  });

  testWidgets('un appareil sans vibreur affiche un message clair', (
    tester,
  ) async {
    final executor = FakeVibrationExecutor()..hasVibratorResult = false;
    final engine = HapticEngine(executor: executor);

    await tester.pumpWidget(HapticsDebugApp(engine: engine));
    await tester.tap(find.text('Tester "aboiement"'));
    await tester.pumpAndSettle();

    expect(find.text('Appareil sans vibreur'), findsOneWidget);
  });
}
