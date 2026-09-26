import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/models/user_role.dart';
import 'package:izahay/models/vibration_segment.dart';
import 'package:izahay/profile/profile_store.dart';

import 'fake_profile_repository.dart';

void main() {
  test('sauvegarder puis restaurer redonne les données', () async {
    final repository = FakeProfileRepository();
    final store = ProfileStore(repository: repository);
    store.setRole(UserRole.accompagnateur);
    store.setSetting('a', true);
    store.setVibrationPattern('baby_cry', [VibrationSegment.short]);

    expect(await store.save(), ProfileSyncResult.saved);

    // Un autre appareil : profil vide, même dépôt.
    final other = ProfileStore(repository: repository);
    expect(await other.restore(), ProfileSyncResult.restored);
    expect(other.profile.role, UserRole.accompagnateur);
    expect(other.profile.settings, {'a': true});
    expect(other.profile.vibrationPatterns['baby_cry'], [
      VibrationSegment.short,
    ]);
  });

  test('restaurer sans sauvegarde le signale', () async {
    final store = ProfileStore(repository: FakeProfileRepository());
    expect(await store.restore(), ProfileSyncResult.nothingToRestore);
  });

  test('une erreur du dépôt donne failed et libère busy', () async {
    final repository = FakeProfileRepository()..failing = true;
    final store = ProfileStore(repository: repository);

    expect(await store.save(), ProfileSyncResult.failed);
    expect(await store.restore(), ProfileSyncResult.failed);
    expect(store.busy, isFalse);
  });

  test('sans dépôt (Firebase absent) la sauvegarde est indisponible', () async {
    final store = ProfileStore();
    expect(await store.save(), ProfileSyncResult.unavailable);
    expect(await store.restore(), ProfileSyncResult.unavailable);
    expect(await store.userId(), isNull);
  });
}
