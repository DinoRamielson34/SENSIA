import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/localization/app_language.dart';
import 'package:izahay/localization/app_strings.dart';

void main() {
  test('forLanguage retourne la bonne instance', () {
    expect(AppStrings.forLanguage(AppLanguage.malagasy), same(AppStrings.mg));
    expect(AppStrings.forLanguage(AppLanguage.francais), same(AppStrings.fr));
  });

  test('mg et fr renseignent tous les champs (aucune chaîne vide)', () {
    for (final strings in [AppStrings.mg, AppStrings.fr]) {
      expect(strings.roleSelectionTitle, isNotEmpty);
      expect(strings.tutorialStepStartTitle, isNotEmpty);
      expect(strings.listeningCategoryLabels['train'], isNotEmpty);
      expect(strings.soundCategoryLabels['dog_bark'], isNotEmpty);
      expect(strings.priorityTitles[5], isNotEmpty);
    }
  });

  test('les gabarits interpolés insèrent bien la valeur fournie', () {
    expect(AppStrings.fr.contactAssociation('Alpha'), 'Contacter Alpha');
    expect(AppStrings.fr.vibrationPatternAction('Train'), 'Vibration Train');
    expect(AppStrings.fr.vibrationSettingsAction('Train'), 'Réglages Train');
    expect(
      AppStrings.fr.stepAnnouncement(
        title: 'T',
        description: 'D',
        number: 1,
        total: 5,
      ),
      'T. D. Étape 1 sur 5.',
    );
  });

  test('AppLanguage.code', () {
    expect(AppLanguage.malagasy.code, 'MG');
    expect(AppLanguage.francais.code, 'FR');
  });
}
