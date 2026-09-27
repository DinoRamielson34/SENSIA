import 'package:flutter/foundation.dart';

import 'app_language.dart';
import 'app_strings.dart';
import 'language_storage.dart';

/// Langue courante de l'app, avec bascule et persistance. Même pattern que
/// `profile/profile_store.dart` et `tutorial/tutorial_controller.dart`.
class LocaleController extends ChangeNotifier {
  AppLanguage _language;
  final LanguageStorage _storage;

  LocaleController({
    AppLanguage initialLanguage = AppLanguage.malagasy,
    LanguageStorage? storage,
  }) : _language = initialLanguage,
       _storage = storage ?? SharedPreferencesLanguageStorage();

  AppLanguage get language => _language;
  AppStrings get strings => AppStrings.forLanguage(_language);

  /// Relit la langue persistée, si elle diffère de la langue courante.
  /// Appelée une fois au démarrage réel de l'app (voir `main.dart`).
  Future<void> load() async {
    final saved = await _storage.load();
    if (saved != null && saved != _language) {
      _language = saved;
      notifyListeners();
    }
  }

  /// Bascule malagasy ⇄ français et persiste le nouveau choix.
  Future<void> toggle() async {
    _language = _language == AppLanguage.malagasy
        ? AppLanguage.francais
        : AppLanguage.malagasy;
    notifyListeners();
    await _storage.save(_language);
  }
}
