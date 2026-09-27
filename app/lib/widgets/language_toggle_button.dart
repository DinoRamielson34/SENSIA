import 'package:flutter/material.dart';

import '../localization/app_language.dart';
import '../localization/locale_controller.dart';
import '../theme/app_theme.dart';

/// Icône présente sur chaque écran de production : un tap bascule
/// instantanément malagasy ⇄ français. Affiche le CODE de la langue vers
/// laquelle le tap bascule (ex. "FR" tant que l'app est en malagasy).
///
/// Sans contrôleur (écran monté seul, par exemple dans un test qui ne
/// fournit pas de `LocaleScope`), ne rend rien : la bascule n'a de sens
/// que dans l'app réelle.
class LanguageToggleButton extends StatelessWidget {
  final LocaleController? controller;

  const LanguageToggleButton({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final next = controller.language == AppLanguage.malagasy
            ? AppLanguage.francais
            : AppLanguage.malagasy;
        return Semantics(
          button: true,
          label: controller.strings.switchLanguageAction,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: controller.toggle,
            child: Container(
              width: 40,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.hover,
                border: Border.all(color: AppColors.primary),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                next.code,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
