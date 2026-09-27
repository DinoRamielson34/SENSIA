import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'tutorial_step.dart';

/// Bulle explicative d'une étape : titre court, phrase simple, progression
/// et actions. Boutons de 48 px minimum, textes de 16 px et plus.
class CoachMark extends StatelessWidget {
  final TutorialStep step;

  /// Numéro de l'étape (à partir de 1) et nombre total, pour « 1 / 5 ».
  final int number;
  final int total;
  final VoidCallback onNext;
  final VoidCallback? onPrevious;
  final VoidCallback onSkip;

  const CoachMark({
    super.key,
    required this.step,
    required this.number,
    required this.total,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
  });

  bool get _isLast => number == total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: '${step.title}. ${step.description}. Étape $number sur $total.',
      child: Material(
        color: AppColors.background,
        elevation: 6,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary, width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (step.icon != null) ...[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.hover,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(step.icon, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      step.title,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.title,
                      ),
                    ),
                  ),
                  Text(
                    '$number / $total',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.title,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                step.description,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 16,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (onPrevious != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onPrevious,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          textStyle: _buttonStyle,
                        ),
                        child: const Text('Précédent'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: onNext,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        textStyle: _buttonStyle,
                      ),
                      child: Text(_isLast ? 'Terminer' : 'Suivant'),
                    ),
                  ),
                ],
              ),
              if (!_isLast)
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: AppColors.title,
                    textStyle: _buttonStyle,
                  ),
                  child: const Text('Passer le tutoriel'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static const _buttonStyle = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );
}
