import 'package:flutter/widgets.dart';

import 'app_strings.dart';
import 'locale_controller.dart';

/// Expose la langue courante à tout l'arbre des widgets. Placé une fois
/// au-dessus du `MaterialApp` par `IzahayApp` (voir Task 5).
class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({
    super.key,
    required LocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Traductions de la langue courante. Sans [LocaleScope] ancêtre (écran
  /// monté seul, par exemple dans un test), replie sur le français : les
  /// écrans restent affichables et testables sans configuration
  /// supplémentaire — voir la spec, section « Notes de modélisation ».
  static AppStrings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    return scope?.notifier?.strings ?? AppStrings.fr;
  }

  /// Contrôleur courant, ou `null` sans [LocaleScope] ancêtre.
  static LocaleController? controllerOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocaleScope>()?.notifier;
}
