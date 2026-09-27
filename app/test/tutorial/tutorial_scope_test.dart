import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/tutorial/tutorial_controller.dart';
import 'package:izahay/tutorial/tutorial_scope.dart';
import 'package:izahay/tutorial/tutorial_step.dart';
import 'package:izahay/tutorial/tutorial_storage.dart';

Widget _app(TutorialController controller, {required VoidCallback onTap}) {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          Positioned(
            left: 40,
            top: 100,
            child: controller.target(
              'button',
              ElevatedButton(onPressed: onTap, child: const Text('Cible')),
            ),
          ),
          Positioned(
            left: 40,
            top: 300,
            child: controller.target('label', const Text('Texte ciblé')),
          ),
          Positioned.fill(child: TutorialScope(controller: controller)),
        ],
      ),
    ),
  );
}

TutorialController _controller() => TutorialController(
  storage: MemoryTutorialStorage(),
  steps: const [
    TutorialStep(
      order: 1,
      targetId: 'button',
      title: 'Commencer',
      description: 'Touchez le bouton.',
      action: TutorialAction.tapTarget,
    ),
    TutorialStep(
      order: 2,
      targetId: 'label',
      title: 'Lire',
      description: 'Un texte.',
    ),
  ],
);

void main() {
  testWidgets('affiche la bulle, avance au toucher de la cible puis termine', (
    tester,
  ) async {
    final controller = _controller();
    var taps = 0;
    await tester.pumpWidget(_app(controller, onTap: () => taps++));
    expect(find.text('Commencer'), findsNothing);

    await controller.startIfNeeded();
    await tester.pumpAndSettle();
    expect(find.text('Commencer'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Précédent'), findsNothing);

    // Toucher la cible avance sans activer le vrai bouton.
    await tester.tapAt(tester.getCenter(find.text('Cible')));
    await tester.pumpAndSettle();
    expect(taps, 0);
    expect(find.text('Lire'), findsOneWidget);
    expect(find.text('Terminer'), findsOneWidget);

    await tester.tap(find.text('Terminer'));
    await tester.pumpAndSettle();
    expect(find.text('Lire'), findsNothing);
    expect(controller.completed, isTrue);

    // Le tutoriel fermé ne bloque plus l'écran.
    await tester.tap(find.text('Cible'));
    expect(taps, 1);
  });

  testWidgets('Passer le tutoriel ferme sans le terminer', (tester) async {
    final controller = _controller();
    await tester.pumpWidget(_app(controller, onTap: () {}));
    await controller.startIfNeeded();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Passer le tutoriel'));
    await tester.pumpAndSettle();
    expect(controller.isActive, isFalse);
    expect(controller.completed, isFalse);
  });
}
