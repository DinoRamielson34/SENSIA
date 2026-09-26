import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/models/color_vision_type.dart';
import 'package:izahay/screens/vision_problem_screen.dart';

void main() {
  testWidgets('Suivants renvoie le trouble choisi', (tester) async {
    ColorVisionType? result;
    await tester.pumpWidget(
      MaterialApp(home: VisionProblemScreen(onContinue: (t) => result = t)),
    );

    expect(find.text('Protanopie'), findsOneWidget);
    // Le contenu défile sur l'écran de test (600 px de haut).
    await tester.ensureVisible(find.byIcon(Icons.skip_next_outlined));
    await tester.tap(find.byIcon(Icons.skip_next_outlined));
    await tester.pump();
    expect(result, isNull);

    await tester.tap(find.text('Tritanopie'));
    await tester.pump();
    await tester.ensureVisible(find.byIcon(Icons.skip_next_outlined));
    await tester.tap(find.byIcon(Icons.skip_next_outlined));
    expect(result, ColorVisionType.tritanopie);
  });
}
