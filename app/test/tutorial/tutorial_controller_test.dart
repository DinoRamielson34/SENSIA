import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/tutorial/tutorial_controller.dart';
import 'package:izahay/tutorial/tutorial_step.dart';
import 'package:izahay/tutorial/tutorial_storage.dart';

TutorialController _controller(MemoryTutorialStorage storage) =>
    TutorialController(
      storage: storage,
      steps: const [
        TutorialStep(order: 2, targetId: 'b', title: 'B', description: 'b'),
        TutorialStep(order: 1, targetId: 'a', title: 'A', description: 'a'),
      ],
    );

void main() {
  test('les étapes sont jouées par ordre croissant', () async {
    final c = _controller(MemoryTutorialStorage());
    await c.startIfNeeded();
    expect(c.current?.targetId, 'a');
    await c.next();
    expect(c.current?.targetId, 'b');
    expect(c.isLast, isTrue);
  });

  test('se lance automatiquement les 2 premières fois seulement', () async {
    final storage = MemoryTutorialStorage();
    for (var i = 0; i < 2; i++) {
      final c = _controller(storage);
      await c.startIfNeeded();
      expect(c.isActive, isTrue, reason: 'lancement ${i + 1}');
      await c.skip();
    }
    final third = _controller(storage);
    await third.startIfNeeded();
    expect(third.isActive, isFalse);
  });

  test('terminé : plus de lancement automatique, mais relançable', () async {
    final storage = MemoryTutorialStorage();
    final c = _controller(storage);
    await c.startIfNeeded();
    await c.next();
    await c.next(); // dernière étape : « Terminer »
    expect(c.isActive, isFalse);
    expect((await storage.load()).completed, isTrue);

    final again = _controller(storage);
    await again.startIfNeeded();
    expect(again.isActive, isFalse);
    await again.restart();
    expect(again.isActive, isTrue);
    expect(again.index, 0);
  });

  test('passer ne marque pas le tutoriel comme terminé', () async {
    final storage = MemoryTutorialStorage();
    final c = _controller(storage);
    await c.startIfNeeded();
    await c.skip();
    expect((await storage.load()).completed, isFalse);
  });

  test('précédent revient d\'une étape', () async {
    final c = _controller(MemoryTutorialStorage());
    await c.startIfNeeded();
    await c.next();
    await c.previous();
    expect(c.index, 0);
  });
}
