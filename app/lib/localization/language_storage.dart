import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';

/// Ce que l'app retient de la langue choisie entre deux lancements.
/// Même principe que `tutorial/tutorial_storage.dart`.
abstract class LanguageStorage {
  Future<AppLanguage?> load();
  Future<void> save(AppLanguage language);
}

/// Stockage en mémoire (tests, ou repli sans persistance).
class MemoryLanguageStorage implements LanguageStorage {
  AppLanguage? _language;

  MemoryLanguageStorage([this._language]);

  @override
  Future<AppLanguage?> load() async => _language;

  @override
  Future<void> save(AppLanguage language) async => _language = language;
}

/// Stockage local persistant (survit à la fermeture de l'app).
class SharedPreferencesLanguageStorage implements LanguageStorage {
  static const _key = 'app_language';

  @override
  Future<AppLanguage?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_key);
      return AppLanguage.values.asNameMap()[name];
    } on Exception {
      // Stockage illisible : l'app garde la langue par défaut du contrôleur.
      return null;
    }
  }

  @override
  Future<void> save(AppLanguage language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, language.name);
    } on Exception {
      // Sans persistance, la langue reste appliquée pour cette session.
    }
  }
}
