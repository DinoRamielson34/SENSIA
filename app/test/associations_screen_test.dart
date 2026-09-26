import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/models/association.dart';
import 'package:izahay/screens/associations_screen.dart';

void main() {
  testWidgets('affiche les associations et signale le contact choisi', (
    tester,
  ) async {
    Association? contacted;
    await tester.pumpWidget(
      MaterialApp(
        home: AssociationsScreen(
          associations: const [
            Association(name: 'Alpha'),
            Association(name: 'Beta'),
          ],
          onContact: (a) => contacted = a,
        ),
      ),
    );

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.sms_outlined).last);
    expect(contacted?.name, 'Beta');
  });

  testWidgets('le bouton home revient à l\'écran précédent', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AssociationsScreen(),
              ),
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.byType(AssociationsScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(AssociationsScreen), findsNothing);
  });
}
