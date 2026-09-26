import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/haptics/haptic_engine.dart';
import 'package:izahay/models/vibration_entry.dart';
import 'package:izahay/models/vibration_segment.dart';
import 'package:izahay/screens/vibration_config_screen.dart';

import 'haptics/fake_vibration_executor.dart';

const _entry = VibrationEntry(id: 'baby_cry', label: 'baby cry');

Widget _app(Widget screen) => MaterialApp(home: screen);

/// Taille de la maquette (360×800) : sur un écran plus court, le contenu défile.
void _useMockupSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('long et court ajoutent des segments, reset les efface', (
    tester,
  ) async {
    _useMockupSize(tester);
    await tester.pumpWidget(
      _app(
        VibrationConfigScreen(
          entry: _entry,
          hapticEngine: HapticEngine(executor: FakeVibrationExecutor()),
        ),
      ),
    );

    expect(find.byType(SegmentMark), findsNWidgets(2)); // les 2 boutons
    await tester.tap(find.bySemanticsLabel('Ajouter un son long'));
    await tester.tap(find.bySemanticsLabel('Ajouter un son court'));
    await tester.pump();
    expect(find.byType(SegmentMark), findsNWidgets(4));

    await tester.tap(find.byIcon(Icons.replay));
    await tester.pump();
    expect(find.byType(SegmentMark), findsNWidgets(2));
  });

  testWidgets('play joue le motif et valider le renvoie', (tester) async {
    _useMockupSize(tester);
    final executor = FakeVibrationExecutor();
    List<VibrationSegment>? validated;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => VibrationConfigScreen(
                  entry: _entry,
                  hapticEngine: HapticEngine(executor: executor),
                  onValidate: (_, segments) => validated = segments,
                ),
              ),
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Ajouter un son long'));
    await tester.tap(find.bySemanticsLabel('Ajouter un son court'));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.play_arrow_outlined));
    await tester.pump();
    expect(executor.vibrateCalls, [
      [0, 500, 150, 150, 0],
    ]);

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(validated, [VibrationSegment.long, VibrationSegment.short]);
    expect(find.byType(VibrationConfigScreen), findsNothing);
  });

  test('un motif vide n\'existe pas', () {
    expect(VibrationConfigController().toPattern('x'), isNull);
  });
}
