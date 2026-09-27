import 'package:flutter/material.dart';

import 'coach_mark.dart';
import 'coach_mark_layout.dart';
import 'spotlight.dart';
import 'tutorial_controller.dart';
import 'tutorial_step.dart';

/// Couche du tutoriel, à poser en dernier dans un `Stack` plein écran :
/// elle assombrit l'écran, met l'élément de l'étape en évidence et affiche
/// la bulle. Sans tutoriel actif, elle ne fait rien et ne bloque aucun toucher.
class TutorialScope extends StatefulWidget {
  final TutorialController controller;

  /// Espace laissé autour de l'élément mis en évidence.
  final double spotlightPadding;

  const TutorialScope({
    super.key,
    required this.controller,
    this.spotlightPadding = 8,
  });

  @override
  State<TutorialScope> createState() => _TutorialScopeState();
}

class _TutorialScopeState extends State<TutorialScope> {
  Rect? _rect;
  TutorialStep? _measuredStep;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _onControllerChanged();
  }

  @override
  void didUpdateWidget(TutorialScope old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final step = widget.controller.current;
    if (step == null) {
      _measuredStep = null;
      _rect = null;
    } else if (step != _measuredStep) {
      _measuredStep = step;
      _measure(step);
    }
  }

  /// Mesure la position de l'élément ciblé une fois l'écran dessiné, en le
  /// faisant défiler dans la zone visible si besoin.
  Future<void> _measure(TutorialStep step) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _measuredStep != step) return;
    final target = widget.controller.contextFor(step.targetId);
    if (target != null && target.mounted) {
      await Scrollable.ensureVisible(
        target,
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
      );
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted || _measuredStep != step) return;
    setState(() => _rect = _targetRect(step));
  }

  Rect? _targetRect(TutorialStep step) {
    final target = widget.controller.contextFor(step.targetId);
    final box = target?.findRenderObject();
    final me = context.findRenderObject();
    if (box is! RenderBox || !box.attached || me is! RenderBox) return null;
    return (box.localToGlobal(Offset.zero, ancestor: me) & box.size).inflate(
      widget.spotlightPadding,
    );
  }

  /// Un toucher dans le spotlight avance quand l'étape le demande.
  void _onTapUp(TapUpDetails details, TutorialStep step) {
    final rect = _rect;
    if (step.action == TutorialAction.tapTarget &&
        rect != null &&
        rect.contains(details.localPosition)) {
      widget.controller.next();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final step = controller.current;
        if (step == null) return const SizedBox.shrink();
        final reduceMotion = MediaQuery.disableAnimationsOf(context);
        final padding = MediaQuery.paddingOf(context);
        final safe = EdgeInsets.fromLTRB(
          16,
          16 + padding.top,
          16,
          16 + padding.bottom,
        );
        return Stack(
          children: [
            // Bloque tout le reste de l'écran et capte le toucher sur la cible.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => _onTapUp(details, step),
                child: AnimatedSpotlight(hole: _rect),
              ),
            ),
            Positioned.fill(
              child: CustomSingleChildLayout(
                delegate: CoachMarkLayoutDelegate(
                  target: _rect,
                  preferred: step.position,
                  safe: safe,
                ),
                child: AnimatedSwitcher(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  child: CoachMark(
                    key: ValueKey(step.targetId),
                    step: step,
                    number: controller.index + 1,
                    total: controller.steps.length,
                    onNext: controller.next,
                    onPrevious: controller.isFirst ? null : controller.previous,
                    onSkip: controller.skip,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
