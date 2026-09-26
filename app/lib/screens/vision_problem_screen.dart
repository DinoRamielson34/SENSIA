import 'package:flutter/material.dart';

import '../models/color_vision_type.dart';
import '../theme/app_theme.dart';
import '../widgets/next_button.dart';

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
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),
                  const Text(
                    'Quel trouble de la vision des couleurs présentez-vous ?',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                    ),
                  ),
                  const Spacer(),
                  for (final type in ColorVisionType.values) ...[
                    _VisionOption(
                      type: type,
                      selected: selected == type,
                      onTap: () => _controller.select(type),
                    ),
                    if (type != ColorVisionType.values.last)
                      const SizedBox(height: 16),
                  ],
                  const Spacer(),
                  NextButton(
                    onPressed: selected == null
                        ? null
                        : () => widget.onContinue?.call(selected),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
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
          height: 51,
          padding: const EdgeInsets.only(left: 15),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  type.label,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    color: selected ? AppColors.onPrimary : AppColors.text,
                  ),
                ),
              ),
              SizedBox(
                width: 50,
                height: 50,
                child: Icon(
                  Icons.fingerprint,
                  size: 30,
                  color: selected ? AppColors.onPrimary : AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
