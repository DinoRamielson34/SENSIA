import '../localization/app_strings.dart';
import '../models/settings_category.dart';
import 'sound_labels.dart';
import 'sound_priority_config.dart';

/// Réglages affichés par [SettingsScreen] : un interrupteur par catégorie de
/// son (activer ou non sa détection), regroupées par niveau de priorité.
class SettingsCategories {
  SettingsCategories._();

  static List<SettingsCategory> build(AppStrings strings) {
    final byPriority = <int, List<SoundRule>>{};
    for (final rule in SoundPriorityConfig.rules) {
      byPriority.putIfAbsent(rule.vibrationPriority, () => []).add(rule);
    }
    final priorities = byPriority.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final priority in priorities)
        SettingsCategory(
          title: SoundLabels.priorityTitle(strings, priority),
          options: [
            for (final rule in byPriority[priority]!)
              SettingsOption(
                id: rule.category,
                label: SoundLabels.of(strings, rule.category),
                initialValue: true,
              ),
          ],
        ),
    ];
  }
}
