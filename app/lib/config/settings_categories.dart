import '../models/settings_category.dart';

/// Réglages affichés par [SettingsScreen].
// TODO: remplacer les libellés de la maquette (« Categorie Param 1 », etc.)
// par les vrais réglages, par ex. les catégories de [SoundPriorityConfig].
class SettingsCategories {
  SettingsCategories._();

  static const List<SettingsCategory> placeholder = [
    SettingsCategory(
      title: 'Categorie Param 1',
      options: [
        SettingsOption(id: 'cat1_param1', label: 'Parametre 1'),
        SettingsOption(id: 'cat1_param2', label: 'Parametre 2'),
        SettingsOption(id: 'cat1_param3', label: 'Parametre 3'),
      ],
    ),
    SettingsCategory(
      title: 'Categorie Param 2',
      options: [
        SettingsOption(id: 'cat2_param1', label: 'Parametre 1'),
        SettingsOption(id: 'cat2_param2', label: 'Parametre 2'),
        SettingsOption(id: 'cat2_param3', label: 'Parametre 3'),
      ],
    ),
    SettingsCategory(
      title: 'Categorie Param 3',
      options: [
        SettingsOption(id: 'cat3_param1', label: 'Parametre 1'),
        SettingsOption(id: 'cat3_param2', label: 'Parametre 2'),
        SettingsOption(id: 'cat3_param3', label: 'Parametre 3'),
      ],
    ),
  ];
}
