import 'package:flutter/material.dart';

import '../models/color_vision_type.dart';
import '../theme/app_theme.dart';
import '../widgets/color_vision_dots.dart';
import '../widgets/next_button.dart';
import '../widgets/wave_decor.dart';

class VisionProblemController extends ChangeNotifier {
  ColorVisionType? _selected;

  ColorVisionType? get selected => _selected;

  void select(ColorVisionType type) {
    if (_selected == type) return;
    _selected = type;
    notifyListeners();
  }
}

class VisionProblemScreen extends StatefulWidget {
  final VisionProblemController? controller;

  /// Appelé au tap sur « Suivants » avec le trouble choisi.
  // TODO: brancher la suite du parcours quand la maquette existera.
  final void Function(ColorVisionType type)? onContinue;

  const VisionProblemScreen({super.key, this.controller, this.onContinue});

  @override
  State<VisionProblemScreen> createState() => _VisionProblemScreenState();
}

class _VisionProblemScreenState extends State<VisionProblemScreen> {
  late final VisionProblemController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? VisionProblemController();
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final selected = _controller.selected;
        return Scaffold(
          backgroundColor: AppColors.backgroundVision,
          body: Stack(
            children: [
              const Positioned.fill(child: WaveDecor()),
              SafeArea(
                // Défilement de secours : le contenu (≈700 px) dépasse les petits écrans.
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(child: _buildContent(selected)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(ColorVisionType? selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 36),
        const Padding(
          padding: EdgeInsets.only(left: 4),
          child: _BackButton(),
        ),
        const SizedBox(height: 18),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 27),
          child: Text(
            'Quel trouble de la vision\ndes couleurs\nprésentez-vous ?',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 27,
              fontWeight: FontWeight.w700,
              height: 1.33,
              color: AppColors.title,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 27),
          child: Column(
            children: [
              for (final type in ColorVisionType.values) ...[
                _VisionOption(
                  type: type,
                  selected: selected == type,
                  onTap: () => _controller.select(type),
                ),
                if (type != ColorVisionType.values.last)
                  const SizedBox(height: 12.6),
              ],
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 27),
          child: NextButton(
            showLabel: false,
            onPressed: selected == null
                ? null
                : () => widget.onContinue?.call(selected),
          ),
        ),
        const SizedBox(height: 93),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Retour',
      child: GestureDetector(
        onTap: () => Navigator.maybePop(context),
        behavior: HitTestBehavior.opaque,
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: CustomPaint(size: Size(8.9, 16.1), painter: _ChevronPainter()),
          ),
        ),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(7.69, 14.88)
      ..lineTo(1.19, 8.03)
      ..lineTo(7.69, 1.19);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.38
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.title,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _VisionOption extends StatelessWidget {
  final ColorVisionType type;
  final bool selected;
  final VoidCallback onTap;

  const _VisionOption({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: type.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 64.2,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.backgroundVision,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.optionBorder, width: 1.2),
          ),
          child: Row(
            children: [
              const SizedBox(width: 17),
              ColorVisionDots(type: type),
              const SizedBox(width: 23),
              Expanded(
                child: Text(
                  type.label,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.onPrimary : AppColors.title,
                  ),
                ),
              ),
              Icon(
                Icons.fingerprint,
                size: 28,
                color: selected ? AppColors.onPrimary : AppColors.title,
              ),
              const SizedBox(width: 19),
            ],
          ),
        ),
      ),
    );
  }
}
