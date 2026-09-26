import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/sound_events/category_settings.dart';

void main() {
  test(
    'contient les catégories par défaut sonnette et aboiement, activées',
    () {
      final settings = SoundEventSettings();
      expect(settings.lookup('sonnette'), isNotNull);
      expect(settings.lookup('aboiement'), isNotNull);
      expect(settings.lookup('sonnette')!.enabled, isTrue);
    },
  );

  test('lookup retourne null pour une catégorie inconnue', () {
    final settings = SoundEventSettings();
    expect(settings.lookup('inconnue'), isNull);
  });

  test('updateCategory ajoute une nouvelle catégorie', () {
    final settings = SoundEventSettings();
    const custom = CategorySettings(
      enabled: true,
      threshold: 0.6,
      requiredConfirmations: 2,
      cooldown: Duration(seconds: 10),
    );
    settings.updateCategory('alarme', custom);
    expect(settings.lookup('alarme'), same(custom));
  });

  test('updateCategory remplace des réglages existants', () {
    final settings = SoundEventSettings();
    const desactivee = CategorySettings(
      enabled: false,
      threshold: 0.75,
      requiredConfirmations: 1,
      cooldown: Duration(seconds: 5),
    );
    settings.updateCategory('sonnette', desactivee);
    expect(settings.lookup('sonnette'), same(desactivee));
  });

  test('all expose une copie non modifiable des réglages actuels', () {
    final settings = SoundEventSettings();
    const custom = CategorySettings(
      enabled: true,
      threshold: 0.6,
      requiredConfirmations: 2,
      cooldown: Duration(seconds: 10),
    );
    settings.updateCategory('alarme', custom);

    final all = settings.all;

    expect(all['sonnette'], isNotNull);
    expect(all['aboiement'], isNotNull);
    expect(all['alarme'], same(custom));
    expect(() => all['nouvelle'] = custom, throwsUnsupportedError);
  });
}
