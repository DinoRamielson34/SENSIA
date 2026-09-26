import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Décor des écrans d'onboarding : forme en haut à droite et vagues en bas.
/// Tracés issus de la maquette Figma (viewBox 360 de large), mis à l'échelle
/// sur la largeur de l'écran.
class WaveDecor extends StatelessWidget {
  const WaveDecor({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: _Shape(painter: _CornerPainter(), aspect: 74 / 77.8947),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _Shape(painter: _WavePainter(), aspect: 360 / 130.526),
          ),
        ],
      ),
    );
  }
}

class _Shape extends StatelessWidget {
  final CustomPainter painter;
  final double aspect;

  const _Shape({required this.painter, required this.aspect});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // La forme du coin fait 74/360 de la largeur de la maquette.
    final w = aspect > 1 ? width : width * 74 / 360;
    return SizedBox(
      width: w,
      height: w / aspect,
      child: CustomPaint(painter: painter),
    );
  }
}

Shader _horizontal(Rect r, List<Color> colors, [List<double>? stops]) =>
    LinearGradient(colors: colors, stops: stops).createShader(r);

class _CornerPainter extends CustomPainter {
  const _CornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 74;
    final path = Path()
      ..moveTo(0, 0)
      ..cubicTo(4 * k, 40 * k, 32 * k, 69.4737 * k, 74 * k, 77.8947 * k)
      ..lineTo(74 * k, 0)
      ..close();
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [AppColors.cornerStart, AppColors.cornerEnd],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _WavePainter extends CustomPainter {
  const _WavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 360;
    canvas.scale(k);
    const rect = Rect.fromLTWH(0, 0, 360, 130.526);

    final fond = Path()
      ..moveTo(0, 67.3684)
      ..cubicTo(73.8462, 56.8421, 138.462, 67.3684, 203.077, 52.6316)
      ..cubicTo(267.692, 40, 313.846, 14.7368, 360, 0)
      ..lineTo(360, 130.526)
      ..lineTo(0, 130.526)
      ..close();
    canvas.drawPath(
      fond,
      Paint()
        ..shader = _horizontal(rect, const [
          AppColors.waveStart,
          AppColors.waveEnd,
        ]),
    );

    final jaune = Path()
      ..moveTo(0, 42.1053)
      ..cubicTo(55.3846, 35.7895, 110.769, 54.7369, 166.154, 71.579)
      ..cubicTo(221.538, 88.4211, 276.923, 84.2105, 360, 67.3684)
      ..lineTo(360, 130.526)
      ..lineTo(0, 130.526)
      ..close();
    canvas.drawPath(
      jaune,
      Paint()
        ..shader = _horizontal(
          rect,
          [
            const Color(0xFFFED182),
            const Color(0xFFFEC79F),
            const Color(0xFFFDBBA0),
          ].map((c) => c.withValues(alpha: 0.9)).toList(),
          const [0, 0.6, 1],
        ),
    );

    final avant = Path()
      ..moveTo(0, 111.579)
      ..cubicTo(64.6154, 96.8421, 120, 84.2105, 184.615, 87.3684)
      ..cubicTo(249.231, 90.5263, 304.615, 109.474, 360, 101.053)
      ..lineTo(360, 130.526)
      ..lineTo(0, 130.526)
      ..close();
    canvas.drawPath(
      avant,
      Paint()
        ..shader = _horizontal(
          rect,
          [
            const Color(0xFFFDB77E),
            const Color(0xFFFB9A80),
          ].map((c) => c.withValues(alpha: 0.85)).toList(),
        ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
