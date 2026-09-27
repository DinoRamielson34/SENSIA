import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:izahay/localization/app_language.dart';
import 'package:izahay/localization/app_strings.dart';
import 'package:izahay/localization/language_storage.dart';
import 'package:izahay/localization/locale_controller.dart';

void main() {
  test('malagasy par défaut sans stockage', () {
    final controller = LocaleController(storage: MemoryLanguageStorage());
    expect(controller.language, AppLanguage.malagasy);
    expect(controller.strings, same(AppStrings.mg));
  });

  test('toggle alterne et notifie', () async {
    final controller = LocaleController(storage: MemoryLanguageStorage());
    var notified = 0;
    controller.addListener(() => notified++);

    await controller.toggle();
    expect(controller.language, AppLanguage.francais);
    expect(notified, 1);

    await controller.toggle();
    expect(controller.language, AppLanguage.malagasy);
    expect(notified, 2);
  });

  test('toggle persiste dans le stockage', () async {
    final storage = MemoryLanguageStorage();
    final controller = LocaleController(storage: storage);
    await controller.toggle();
    expect(await storage.load(), AppLanguage.francais);
  });

  test('load() applique une langue déjà persistée', () async {
    final storage = MemoryLanguageStorage(AppLanguage.francais);
    final controller = LocaleController(storage: storage);
    expect(controller.language, AppLanguage.malagasy); // avant load()

    var notified = false;
    controller.addListener(() => notified = true);
    await controller.load();

    expect(controller.language, AppLanguage.francais);
    expect(notified, isTrue);
  });

  test('load() ne notifie pas si la langue persistée est déjà la langue courante', () async {
    final controller = LocaleController(storage: MemoryLanguageStorage(AppLanguage.malagasy));
    var notified = false;
    controller.addListener(() => notified = true);
    await controller.load();
    expect(notified, isFalse);
  });

  test('SharedPreferencesLanguageStorage : round-trip', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = SharedPreferencesLanguageStorage();
    expect(await storage.load(), isNull);
    await storage.save(AppLanguage.francais);
    expect(await storage.load(), AppLanguage.francais);
  });
}
