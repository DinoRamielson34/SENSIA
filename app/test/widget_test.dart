// Tests de smoke basiques pour l'application IZAHAY / SENSIA.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:izahay/main.dart';
import 'package:izahay/tutorial/tutorial_storage.dart';

/// Tutoriel déjà terminé : il ne recouvre pas l'écran pendant le test.
MemoryTutorialStorage _doneTutorial() =>
    MemoryTutorialStorage(const TutorialProgress(completed: true));

void main() {
  testWidgets('IzahayApp se construit avec un MaterialApp', (tester) async {
    await tester.pumpWidget(IzahayApp(tutorialStorage: _doneTutorial()));

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('le compteur de taps s\'incrémente au clic', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TestScreen()));

    expect(find.text('Bouton pressé : 0 fois'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Tester'));
    await tester.pump();

    expect(find.text('Bouton pressé : 1 fois'), findsOneWidget);
  });
}
