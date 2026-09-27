import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/tutorial/coach_mark_layout.dart';
import 'package:izahay/tutorial/tutorial_step.dart';

const _screen = Size(360, 800);
const _bubble = Size(300, 160);

void main() {
  bool overlaps(Rect target, Offset offset) =>
      (offset & _bubble).overlaps(target);

  test('cible en haut : la bulle se place dessous', () {
    const target = Rect.fromLTWH(120, 100, 120, 60);
    final offset = resolveCoachMarkOffset(
      target: target,
      screen: _screen,
      bubble: _bubble,
    );
    expect(offset.dy, greaterThanOrEqualTo(target.bottom));
  });

  test('cible en bas : la bulle se place dessus', () {
    const target = Rect.fromLTWH(150, 690, 60, 60);
    final offset = resolveCoachMarkOffset(
      target: target,
      screen: _screen,
      bubble: _bubble,
    );
    expect(offset.dy + _bubble.height, lessThanOrEqualTo(target.top));
  });

  test('le côté préféré est respecté quand il tient', () {
    const target = Rect.fromLTWH(150, 400, 60, 60);
    final offset = resolveCoachMarkOffset(
      target: target,
      screen: _screen,
      bubble: _bubble,
      preferred: CoachMarkPosition.above,
    );
    expect(offset.dy + _bubble.height, lessThanOrEqualTo(target.top));
  });

  test('la bulle reste dans l\'écran et ne masque pas une grande cible', () {
    const target = Rect.fromLTWH(20, 150, 320, 330);
    final offset = resolveCoachMarkOffset(
      target: target,
      screen: _screen,
      bubble: _bubble,
    );
    expect(overlaps(target, offset), isFalse);
    expect(offset.dx, inInclusiveRange(16, _screen.width - 16 - 300));
    expect(offset.dy + _bubble.height, lessThanOrEqualTo(_screen.height - 16));
  });
}
