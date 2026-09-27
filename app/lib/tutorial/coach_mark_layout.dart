import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'tutorial_step.dart';

/// Choisit où poser la bulle pour qu'elle ne masque jamais [target].
///
/// Essaie d'abord le côté préféré, puis dessous, dessus, à droite, à gauche ;
/// retient le premier qui tient entièrement à l'écran (marges [safe]). Si
/// aucun ne tient, place la bulle du côté vertical le plus spacieux.
Offset resolveCoachMarkOffset({
  required Rect target,
  required Size screen,
  required Size bubble,
  CoachMarkPosition preferred = CoachMarkPosition.auto,
  EdgeInsets safe = const EdgeInsets.all(16),
  double gap = 16,
}) {
  final area = Rect.fromLTRB(
    safe.left,
    safe.top,
    screen.width - safe.right,
    screen.height - safe.bottom,
  );

  double clampX(double x) =>
      x.clamp(area.left, math.max(area.left, area.right - bubble.width));
  double clampY(double y) =>
      y.clamp(area.top, math.max(area.top, area.bottom - bubble.height));

  final offsets = <CoachMarkPosition, Offset>{
    CoachMarkPosition.below: Offset(
      clampX(target.center.dx - bubble.width / 2),
      target.bottom + gap,
    ),
    CoachMarkPosition.above: Offset(
      clampX(target.center.dx - bubble.width / 2),
      target.top - gap - bubble.height,
    ),
    CoachMarkPosition.right: Offset(
      target.right + gap,
      clampY(target.center.dy - bubble.height / 2),
    ),
    CoachMarkPosition.left: Offset(
      target.left - gap - bubble.width,
      clampY(target.center.dy - bubble.height / 2),
    ),
  };

  final order = [
    if (preferred != CoachMarkPosition.auto) preferred,
    CoachMarkPosition.below,
    CoachMarkPosition.above,
    CoachMarkPosition.right,
    CoachMarkPosition.left,
  ];
  for (final side in order) {
    final offset = offsets[side]!;
    final fits =
        area.contains(offset) &&
        area.contains(offset + Offset(bubble.width, bubble.height));
    if (fits) return offset;
  }

  // Rien ne tient : côté vertical le plus spacieux, ramené dans l'écran.
  final spaceBelow = area.bottom - target.bottom;
  final spaceAbove = target.top - area.top;
  final base = spaceBelow >= spaceAbove
      ? offsets[CoachMarkPosition.below]!
      : offsets[CoachMarkPosition.above]!;
  return Offset(base.dx, clampY(base.dy));
}

/// Place la bulle (taille connue après mesure) à côté de [target] ;
/// centrée à l'écran si aucune cible n'est disponible.
class CoachMarkLayoutDelegate extends SingleChildLayoutDelegate {
  final Rect? target;
  final CoachMarkPosition preferred;
  final EdgeInsets safe;

  CoachMarkLayoutDelegate({
    required this.target,
    required this.preferred,
    required this.safe,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.min(constraints.maxWidth - safe.horizontal, 340),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final hole = target;
    if (hole == null) {
      return Offset(
        (size.width - childSize.width) / 2,
        (size.height - childSize.height) / 2,
      );
    }
    return resolveCoachMarkOffset(
      target: hole,
      screen: size,
      bubble: childSize,
      preferred: preferred,
      safe: safe,
    );
  }

  @override
  bool shouldRelayout(CoachMarkLayoutDelegate old) =>
      old.target != target || old.preferred != preferred || old.safe != safe;
}
