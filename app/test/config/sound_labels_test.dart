import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/config/sound_labels.dart';
import 'package:izahay/localization/app_strings.dart';

void main() {
  test('of() traduit une catégorie connue', () {
    expect(SoundLabels.of(AppStrings.fr, 'dog_bark'), 'Aboiement');
    expect(SoundLabels.of(AppStrings.mg, 'dog_bark'), 'Fikaikain\'alika');
  });

  test('of() replie sur l\'identifiant pour une catégorie inconnue', () {
    expect(SoundLabels.of(AppStrings.fr, 'inconnu'), 'inconnu');
  });

  test('priorityTitle() traduit une priorité connue', () {
    expect(SoundLabels.priorityTitle(AppStrings.fr, 5), 'Danger immédiat');
    expect(SoundLabels.priorityTitle(AppStrings.mg, 5), 'Loza eo no eo');
  });

  test('priorityTitle() replie sur un préfixe générique pour une priorité inconnue', () {
    expect(SoundLabels.priorityTitle(AppStrings.fr, 42), 'Priorité 42');
    expect(SoundLabels.priorityTitle(AppStrings.mg, 42), 'Laharana 42');
  });
}
