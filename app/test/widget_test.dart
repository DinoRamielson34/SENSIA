// Test de smoke basique pour l'écran de test IZAHAY.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:izahay/main.dart';

void main() {
  testWidgets('le compteur de taps s\'incrémente au clic', (tester) async {
    await tester.pumpWidget(const IzahayApp());

    expect(find.text('Bouton pressé : 0 fois'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Tester'));
    await tester.pump();

    expect(find.text('Bouton pressé : 1 fois'), findsOneWidget);
  });
}
