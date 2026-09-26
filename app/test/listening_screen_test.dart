import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/haptics/haptic_engine.dart';
import 'package:izahay/screens/listening_screen.dart';
import 'package:izahay/services/sound_haptic_pipeline.dart';

import 'haptics/fake_vibration_executor.dart';

/// Pipeline factice : pas de modèle ni de micro, l'état est piloté à la main.
class _FakePipeline extends SoundHapticPipeline {
  _FakePipeline()
    : super(hapticEngine: HapticEngine(executor: FakeVibrationExecutor()));

  bool listening = false;
  int starts = 0;

  @override
  Future<void> loadModel() async {}

  @override
  bool get modelReady => true;

  @override
  bool get modelLoading => false;

  @override
  bool get isListening => listening;

  @override
  Future<void> start() async {
    starts++;
    listening = true;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    listening = false;
    notifyListeners();
  }
}

void main() {
  testWidgets('le bouton play démarre puis arrête l\'écoute', (tester) async {
    final pipeline = _FakePipeline();
    await tester.pumpWidget(
      MaterialApp(home: ListeningScreen(pipeline: pipeline)),
    );

    expect(find.byIcon(Icons.play_arrow_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_arrow_outlined));
    await tester.pump();
    expect(pipeline.starts, 1);
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.stop_rounded));
    await tester.pump();
    expect(pipeline.listening, isFalse);
  });

  testWidgets('le bouton home déplie puis replie le menu', (tester) async {
    var associations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ListeningScreen(
          pipeline: _FakePipeline(),
          onAssociation: () => associations++,
        ),
      ),
    );

    expect(find.byIcon(Icons.close), findsNothing);
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.text('Association'));
    // Menu refermé : le bouton pulse en boucle, pumpAndSettle ne finirait pas.
    await tester.pump(const Duration(milliseconds: 400));
    expect(associations, 1);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('la pastille Help déclenche onHelp', (tester) async {
    var helps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ListeningScreen(pipeline: _FakePipeline(), onHelp: () => helps++),
      ),
    );

    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Help'));
    // Menu refermé : le bouton pulse en boucle, pumpAndSettle ne finirait pas.
    await tester.pump(const Duration(milliseconds: 400));
    expect(helps, 1);
  });

  testWidgets('la pastille Sauvegarde déclenche onBackup', (tester) async {
    var backups = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ListeningScreen(
          pipeline: _FakePipeline(),
          onBackup: () => backups++,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sauvegarde'));
    // Menu refermé : le bouton pulse en boucle, pumpAndSettle ne finirait pas.
    await tester.pump(const Duration(milliseconds: 400));
    expect(backups, 1);
  });

  testWidgets('le bouton home pulse tant que le menu est fermé', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ListeningScreen(pipeline: _FakePipeline())),
    );
    expect(tester.hasRunningAnimations, isTrue);

    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('pas de pulsation si les animations sont réduites', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: ListeningScreen(pipeline: _FakePipeline()),
      ),
    );

    expect(tester.hasRunningAnimations, isFalse);
  });
}
