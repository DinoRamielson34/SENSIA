import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/config/settings_categories.dart';
import 'package:izahay/config/sound_labels.dart';
import 'package:izahay/config/sound_priority_config.dart';
import 'package:izahay/config/vibration_entries.dart';
import 'package:izahay/localization/app_strings.dart';

void main() {
  final ids = SoundPriorityConfig.rules.map((r) => r.category).toList();

  test('les réglages couvrent chaque catégorie de son une seule fois', () {
    final options = [
      for (final category in SettingsCategories.build(AppStrings.fr))
        ...category.options,
    ];
    expect(options.map((o) => o.id).toList()..sort(), [...ids]..sort());
  });

  test('les groupes sont triés du plus au moins prioritaire', () {
    final categories = SettingsCategories.build(AppStrings.fr);
    final titles = categories.map((c) => c.title).toList();
    expect(titles.first, 'Danger immédiat');
    expect(titles.last, 'Autres sons');
    expect(categories.first.options.map((o) => o.id), [
      'train',
      'fire_alarm',
      'smoke_alarm',
    ]);
  });

  test('la liste des vibrations couvre toutes les catégories', () {
    expect(
      VibrationEntries.build(AppStrings.fr).map((e) => e.id).toList(),
      ids,
    );
  });

  test('toute catégorie a un libellé français', () {
    for (final id in ids) {
      expect(
        SoundLabels.of(AppStrings.fr, id),
        isNot(id),
        reason: 'libellé manquant : $id',
      );
    }
  });
}
