import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Bouton rond « home » placé en bas des écrans secondaires.
class HomeButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const HomeButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Accueil',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.background),
          ),
          child: const Icon(
            Icons.home_outlined,
            size: 24,
            color: AppColors.onPrimary,
          ),
        ),
      ),
    );
  }
}
