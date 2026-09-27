import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Assombrit tout l'écran sauf [hole], entouré d'un anneau orange.
/// Sans [hole], l'écran est simplement assombri.
class SpotlightPainter extends CustomPainter {
  final Rect? hole;

  const SpotlightPainter({required this.hole});

  static const scrim = Color(0xB8000000);

  /// Rond pour un élément à peu près carré, coins arrondis sinon.
  static RRect shape(Rect hole) {
    final ratio = hole.width / hole.height;
    final round = ratio > 0.8 && ratio < 1.25;
    final radius = round ? hole.shortestSide / 2 : 16.0;
    return RRect.fromRectAndRadius(hole, Radius.circular(radius));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    final area = hole;
    if (area != null) path.addRRect(shape(area));
    canvas.drawPath(path, Paint()..color = scrim);
    if (area != null) {
      canvas.drawRRect(
        shape(area),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = AppColors.hover,
      );
    }
  }

  @override
  bool shouldRepaint(SpotlightPainter old) => old.hole != hole;
}

/// Déplace le spotlight en douceur d'un élément au suivant.
class AnimatedSpotlight extends StatefulWidget {
  final Rect? hole;

  const AnimatedSpotlight({super.key, required this.hole});

  @override
  State<AnimatedSpotlight> createState() => _AnimatedSpotlightState();
}

class _AnimatedSpotlightState extends State<AnimatedSpotlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );
  Rect? _from;
  Rect? _to;

  @override
  void initState() {
    super.initState();
    _to = widget.hole;
    _from = widget.hole;
    _controller.value = 1;
  }

  @override
  void didUpdateWidget(AnimatedSpotlight old) {
    super.didUpdateWidget(old);
    if (widget.hole == _to) return;
    // Repart de la position affichée à cet instant pour éviter tout saut.
    _from = _current ?? widget.hole;
    _to = widget.hole;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  Rect? get _current =>
      _to == null ? null : Rect.lerp(_from, _to, _curve.value);

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: SpotlightPainter(hole: _current),
      ),
    );
  }
}
