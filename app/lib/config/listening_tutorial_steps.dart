import 'package:flutter/material.dart';

import '../tutorial/tutorial_step.dart';

/// Étapes du tutoriel de l'écran principal.
///
/// Les identifiants doivent correspondre aux `target(...)` posés sur
/// `ListeningScreen` et `HomeMenu`. [menuOpen] pilote l'ouverture du menu
/// pour les étapes qui en montrent les boutons.
List<TutorialStep> listeningTutorialSteps(ValueNotifier<bool> menuOpen) {
  /// Ouvre ou ferme le menu et laisse finir son animation avant la mesure.
  Future<void> setMenu(bool open) async {
    if (menuOpen.value == open) return;
    menuOpen.value = open;
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  return [
    TutorialStep(
      order: 1,
      targetId: 'play',
      title: 'Commencer',
      description: 'Touchez ce bouton pour lancer la détection des sons.',
      icon: Icons.play_arrow_outlined,
      action: TutorialAction.tapTarget,
      onEnter: () => setMenu(false),
    ),
    TutorialStep(
      order: 2,
      targetId: 'lastSound',
      title: 'Dernier son',
      description: 'Le dernier son reconnu apparaît ici.',
      icon: Icons.hearing,
      onEnter: () => setMenu(false),
    ),
    TutorialStep(
      order: 3,
      targetId: 'menu',
      title: 'Menu',
      description: 'Touchez ce bouton pour ouvrir le menu.',
      icon: Icons.home_outlined,
      action: TutorialAction.tapTarget,
      onEnter: () => setMenu(false),
    ),
    TutorialStep(
      order: 4,
      targetId: 'help',
      title: 'Vos sons',
      description: 'Choisissez les sons que l’application doit reconnaître.',
      icon: Icons.checklist,
      onEnter: () => setMenu(true),
    ),
    TutorialStep(
      order: 5,
      targetId: 'settings',
      title: 'Vibrations',
      description: 'Choisissez une vibration différente pour chaque son.',
      icon: Icons.vibration,
      onEnter: () => setMenu(true),
    ),
    TutorialStep(
      order: 6,
      targetId: 'association',
      title: 'Associations',
      description: 'Trouvez des associations qui peuvent vous aider.',
      icon: Icons.groups_outlined,
      onEnter: () => setMenu(true),
    ),
    TutorialStep(
      order: 7,
      targetId: 'backup',
      title: 'Sauvegarde',
      description: 'Sauvegardez ou retrouvez vos réglages.',
      icon: Icons.person_outline,
      onEnter: () => setMenu(true),
    ),
  ];
}
