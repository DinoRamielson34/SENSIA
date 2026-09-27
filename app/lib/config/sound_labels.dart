import '../localization/app_strings.dart';

/// Libellés des catégories de sons (identifiants de `SoundPriorityConfig`)
/// et des niveaux de priorité, dans la langue de [strings].
class SoundLabels {
  SoundLabels._();

  /// Libellé de [category] dans la langue de [strings] ; l'identifiant
  /// lui-même si elle est inconnue.
  static String of(AppStrings strings, String category) =>
      strings.soundCategoryLabels[category] ?? category;

  static String priorityTitle(AppStrings strings, int priority) =>
      strings.priorityTitles[priority] ??
      '${strings.priorityFallbackPrefix} $priority';
}
