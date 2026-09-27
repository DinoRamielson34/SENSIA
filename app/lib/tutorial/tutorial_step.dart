import 'package:flutter/widgets.dart';

/// Côté préféré de la bulle par rapport à l'élément ciblé.
/// [auto] laisse le système choisir selon la place disponible.
enum CoachMarkPosition { auto, above, below, left, right }

/// Action attendue de l'utilisateur pendant une étape.
enum TutorialAction {
  /// Il lit puis utilise « Suivant ».
  none,

  /// Toucher l'élément mis en évidence passe à l'étape suivante. Le toucher
  /// n'active pas l'élément lui-même : le tutoriel n'a jamais d'effet de bord.
  tapTarget,
}

/// Une étape du tutoriel : quoi mettre en évidence et quoi dire.
class TutorialStep {
  /// Identifiant fourni à `TutorialController.target` sur l'élément ciblé.
  final String targetId;
  final String title;
  final String description;

  /// Les étapes sont jouées par [order] croissant.
  final int order;

  /// Pictogramme affiché à côté du titre, pour aider sans lecture.
  final IconData? icon;
  final CoachMarkPosition position;
  final TutorialAction action;

  /// Préparation de l'écran avant l'étape (ex. ouvrir un menu). Le tutoriel
  /// attend sa fin avant de mesurer l'élément.
  final Future<void> Function()? onEnter;

  const TutorialStep({
    required this.targetId,
    required this.title,
    required this.description,
    required this.order,
    this.icon,
    this.position = CoachMarkPosition.auto,
    this.action = TutorialAction.none,
    this.onEnter,
  });
}
