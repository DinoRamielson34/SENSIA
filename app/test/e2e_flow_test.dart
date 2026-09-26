import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/haptics/haptic_engine.dart';
import 'package:izahay/main.dart';
import 'package:izahay/models/user_profile.dart';
import 'package:izahay/models/user_role.dart';
import 'package:izahay/models/vibration_segment.dart';
import 'package:izahay/screens/vibration_config_screen.dart';
import 'package:izahay/services/sound_haptic_pipeline.dart';

import 'haptics/fake_vibration_executor.dart';
import 'profile/fake_profile_repository.dart';

/// Vrai pipeline (vrais réglages, vrai moteur haptique factice), sans
/// modèle ni micro.
class _Pipeline extends SoundHapticPipeline {
  _Pipeline(FakeVibrationExecutor executor)
    : super(hapticEngine: HapticEngine(executor: executor));

  @override
  Future<void> loadModel() async {}

  @override
  bool get modelReady => true;

  @override
  bool get modelLoading => false;
}

void main() {
  testWidgets('parcours complet : réglages, vibrations et sauvegarde agissent '
      'sur le vrai pipeline', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final executor = FakeVibrationExecutor();
    final pipeline = _Pipeline(executor);
    final repository = FakeProfileRepository();
    await tester.pumpWidget(
      IzahayApp(pipeline: pipeline, profileRepository: repository),
    );

    // Le bouton home pulse en boucle : on avance par durée, pas par
    // pumpAndSettle, sauf menu ouvert.
    // Une navigation demande deux frames : l'une pour insérer la route, la
    // suivante pour la construire.
    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> openMenu() async {
      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();
    }

    // Onboarding.
    await tester.tap(find.text('Client'));
    await tester.pump();
    await tester.tap(find.text('Suivants'));
    await settle();
    await tester.tap(find.text('Protanopie'));
    await tester.pump();
    await tester.tap(find.text('Suivants'));
    await settle();

    // Help → réglages : couper le train agit sur le pipeline.
    await openMenu();
    await tester.tap(find.text('Help'));
    await settle();
    expect(pipeline.isCategoryEnabled('train'), isTrue);
    await tester.tap(find.text('Train'));
    await tester.pump();
    expect(pipeline.isCategoryEnabled('train'), isFalse);

    // Sauvegarde automatique : aucun bouton, la modification part seule.
    // Le rôle et le trouble de la vision sont déjà partis ; pas encore le train.
    expect(repository.stored!.role, UserRole.client);
    expect(repository.stored!.settings.containsKey('train'), isFalse);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(repository.stored!.settings['train'], isFalse);

    await tester.tap(find.byIcon(Icons.home_outlined));
    await settle();

    // Settings → vibrations → configuration du train.
    await openMenu();
    await tester.tap(find.text('Settings'));
    await settle();
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await settle();
    // Point de départ : le motif actuel du train (longue, courte, courte).
    expect(find.byType(SegmentMark), findsNWidgets(3 + 2));
    await tester.tap(find.byIcon(Icons.replay));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Ajouter un son court'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check));
    await settle();

    // Le motif validé est celui que joue le pipeline (test comme détection).
    expect(pipeline.patternFor('train')!.pulses.length, 1);
    await tester.tap(find.byIcon(Icons.waves).first);
    await tester.pump();
    expect(executor.vibrateCalls.last, [0, 150, 0]);
    await tester.tap(find.byIcon(Icons.home_outlined));
    await settle();

    // Sauvegarde puis restauration.
    await openMenu();
    await tester.tap(find.text('Sauvegarde'));
    await settle();
    await tester.tap(find.text('Sauvegarder mes donnees'));
    await tester.pumpAndSettle();
    final stored = repository.stored!;
    expect(stored.role, UserRole.client);
    expect(stored.settings['train'], isFalse);
    expect(stored.vibrationPatterns['train'], [VibrationSegment.short]);

    // Le pipeline dérive, la restauration le remet comme sauvegardé.
    pipeline.setCategoryEnabled('train', true);
    await tester.tap(find.text('Restaurer les donnees'));
    await tester.pumpAndSettle();
    expect(pipeline.isCategoryEnabled('train'), isFalse);
  });

  testWidgets('la dernière sauvegarde est restaurée automatiquement au '
      'démarrage', (tester) async {
    final pipeline = _Pipeline(FakeVibrationExecutor());
    final repository = FakeProfileRepository()
      ..stored = UserProfile(
        role: UserRole.accompagnateur,
        settings: {'train': false},
        vibrationPatterns: {
          'train': [VibrationSegment.short],
        },
      );

    expect(pipeline.isCategoryEnabled('train'), isTrue);
    await tester.pumpWidget(
      IzahayApp(pipeline: pipeline, profileRepository: repository),
    );
    await tester.pump();

    // Aucune action de l'utilisateur : le pipeline a repris la sauvegarde.
    expect(pipeline.isCategoryEnabled('train'), isFalse);
    expect(pipeline.patternFor('train')!.pulses.length, 1);
  });

  testWidgets(
    'sans sauvegarde ou en cas d\'échec, l\'app démarre normalement',
    (tester) async {
      final pipeline = _Pipeline(FakeVibrationExecutor());
      final repository = FakeProfileRepository()..failing = true;
      await tester.pumpWidget(
        IzahayApp(pipeline: pipeline, profileRepository: repository),
      );
      await tester.pump();

      expect(find.text('Êtes-vous...'), findsOneWidget);
      expect(pipeline.isCategoryEnabled('train'), isTrue);
    },
  );
}
