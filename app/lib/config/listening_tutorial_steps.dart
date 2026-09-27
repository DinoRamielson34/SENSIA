import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../tutorial/tutorial_step.dart';

/// Étapes du tutoriel de l'écran principal, dans la langue de [strings].
///
/// Les identifiants doivent correspondre aux `target(...)` posés sur
/// `ListeningScreen` et `HomeMenu`. [menuOpen] pilote l'ouverture du menu
/// pour les étapes qui en montrent les boutons.
List<TutorialStep> listeningTutorialSteps(
  ValueNotifier<bool> menuOpen,
  AppStrings strings,
) {
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
      title: strings.tutorialStepStartTitle,
      description: strings.tutorialStepStartDescription,
      icon: Icons.play_arrow_outlined,
      action: TutorialAction.tapTarget,
      onEnter: () => setMenu(false),
    ),
    TutorialStep(
      order: 2,
      targetId: 'lastSound',
      title: strings.tutorialStepLastSoundTitle,
      description: strings.tutorialStepLastSoundDescription,
      icon: Icons.hearing,
      onEnter: () => setMenu(false),
    ),
    TutorialStep(
      order: 3,
      targetId: 'menu',
      title: strings.tutorialStepMenuTitle,
      description: strings.tutorialStepMenuDescription,
      icon: Icons.home_outlined,
      action: TutorialAction.tapTarget,
      onEnter: () => setMenu(false),
    ),
    TutorialStep(
      order: 4,
      targetId: 'help',
      title: strings.tutorialStepYourSoundsTitle,
      description: strings.tutorialStepYourSoundsDescription,
      icon: Icons.checklist,
      onEnter: () => setMenu(true),
    ),
    TutorialStep(
      order: 5,
      targetId: 'settings',
      title: strings.tutorialStepVibrationsTitle,
      description: strings.tutorialStepVibrationsDescription,
      icon: Icons.vibration,
      onEnter: () => setMenu(true),
    ),
    TutorialStep(
      order: 6,
      targetId: 'association',
      title: strings.tutorialStepAssociationsTitle,
      description: strings.tutorialStepAssociationsDescription,
      icon: Icons.groups_outlined,
      onEnter: () => setMenu(true),
    ),
    TutorialStep(
      order: 7,
      targetId: 'backup',
      title: strings.tutorialStepBackupTitle,
      description: strings.tutorialStepBackupDescription,
      icon: Icons.person_outline,
      onEnter: () => setMenu(true),
    ),
  ];
}
