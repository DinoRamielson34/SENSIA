import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Bouton « Suivants » commun aux écrans d'onboarding.
class NextButton extends StatelessWidget {
  final VoidCallback? onPressed;

  /// Affiche « Suivants » à côté de l'icône ; masqué sur la maquette du choix de rôle.
  final bool showLabel;

  const NextButton({super.key, required this.onPressed, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.disabled,
          disabledForegroundColor: AppColors.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showLabel) ...[
              const Text(
                'Suivants',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
            ],
            const Icon(Icons.skip_next_outlined, size: 24),
          ],
        ),
      ),
    );
  }
}
