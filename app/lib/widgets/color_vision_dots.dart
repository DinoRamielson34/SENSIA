import 'package:flutter/material.dart';

import '../models/color_vision_type.dart';

/// Pastilles colorées de la maquette illustrant chaque trouble de la vision.
/// Grille 3×3 (ellipses 6,8×7,16) ou, pour le daltonisme, 6 ronds en cercle.
class ColorVisionDots extends StatelessWidget {
  final ColorVisionType type;

  const ColorVisionDots({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final circle = type == ColorVisionType.daltonisme;
    return SizedBox(
      width: circle ? 26 : 23.8,
      height: circle ? 24.84 : 25.05,
      child: CustomPaint(painter: _DotsPainter(type)),
    );
  }
}

const _grid = <ColorVisionType, List<int>>{
  ColorVisionType.protanopie: [
    0xFFFE8D84, 0xFFFBB5AE, 0xFFF7706A,
    0xFFFDA39B, 0xFFF46F6A, 0xFFFCC2BC,
    0xFFF98A82, 0xFFF25F5B, 0xFFFDB0A8,
  ],
  ColorVisionType.deuteranopie: [
    0xFF12D98B, 0xFF7FE5B8, 0xFF20C77F,
    0xFF5ADFA3, 0xFF0FBF78, 0xFF9BEBC8,
    0xFF2BD493, 0xFF16B870, 0xFF6FE3AF,
  ],
  ColorVisionType.tritanopie: [
    0xFF8FB6F0, 0xFF5E8FE6, 0xFFAFC9EA,
    0xFF4E7FE0, 0xFF9DBDF2, 0xFF6C98E8,
    0xFFBCD2F0, 0xFF5585E2, 0xFF86AEEE,
  ],
  ColorVisionType.achromatopsie: [
    0xFFA8A4A0, 0xFFCFCBC6, 0xFF8E8A86,
    0xFFBDB9B4, 0xFF7F7B78, 0xFFD8D4CF,
    0xFF9A9692, 0xFFB3AFAA, 0xFF8A8683,
  ],
};

// Centres (x, y) puis couleur des 6 ronds du daltonisme.
const _daltonisme = <(double, double, int)>[
  (8.5, 4.21, 0xFFF25F5B),
  (17.5, 4.21, 0xFF4E8FE6),
  (22, 12.42, 0xFF12C981),
  (17.5, 20.63, 0xFFFFC94D),
  (8.5, 20.63, 0xFFF4A04A),
  (4, 12.42, 0xFFE86A8F),
];

class _DotsPainter extends CustomPainter {
  final ColorVisionType type;

  const _DotsPainter(this.type);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    if (type == ColorVisionType.daltonisme) {
      for (final (x, y, color) in _daltonisme) {
        paint.color = Color(color);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 8, height: 8.42),
          paint,
        );
      }
      return;
    }
    final colors = _grid[type]!;
    for (var i = 0; i < 9; i++) {
      paint.color = Color(colors[i]);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(3.4 + 8.5 * (i % 3), 3.58 + 8.947 * (i ~/ 3)),
          width: 6.8,
          height: 7.16,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter old) => old.type != type;
}
