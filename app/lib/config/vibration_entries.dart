import '../models/vibration_entry.dart';
import 'sound_labels.dart';
import 'sound_priority_config.dart';

/// Sons affichés par [VibrationsScreen] : toutes les catégories reconnues
/// par l'IA, de la plus prioritaire à la moins prioritaire.
class VibrationEntries {
  VibrationEntries._();

  static final List<VibrationEntry> all = [
    for (final rule in SoundPriorityConfig.rules)
      VibrationEntry(id: rule.category, label: SoundLabels.of(rule.category)),
  ];
}
