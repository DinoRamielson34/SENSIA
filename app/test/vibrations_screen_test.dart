import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/models/vibration_entry.dart';
import 'package:izahay/screens/vibrations_screen.dart';

void main() {
  testWidgets('les boutons d\'une carte signalent l\'entrée concernée', (
    tester,
  ) async {
    VibrationEntry? pattern;
    VibrationEntry? settings;
    await tester.pumpWidget(
      MaterialApp(
        home: VibrationsScreen(
          entries: const [
            VibrationEntry(id: 'a', label: 'Alpha'),
            VibrationEntry(id: 'b', label: 'Beta'),
          ],
          onPattern: (e) => pattern = e,
          onSettings: (e) => settings = e,
        ),
      ),
    );

    expect(find.text('Alpha'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.waves).last);
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    expect(pattern?.id, 'b');
    expect(settings?.id, 'a');
  });

  testWidgets('le bouton home revient à l\'écran précédent', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const VibrationsScreen()),
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.byType(VibrationsScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(VibrationsScreen), findsNothing);
  });
}
