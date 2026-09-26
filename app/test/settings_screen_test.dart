import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/screens/settings_screen.dart';

void main() {
  testWidgets('un tap bascule le réglage et prévient onChanged', (
    tester,
  ) async {
    final changes = <String, bool>{};
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(onChanged: (id, value) => changes[id] = value),
      ),
    );

    expect(find.text('Categorie Param 1'), findsOneWidget);
    await tester.tap(find.text('Parametre 1').first);
    await tester.pump();
    expect(changes, {'cat1_param1': true});

    await tester.tap(find.text('Parametre 1').first);
    await tester.pump();
    expect(changes['cat1_param1'], isFalse);
  });

  testWidgets('le bouton home revient à l\'écran précédent', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
  });
}
