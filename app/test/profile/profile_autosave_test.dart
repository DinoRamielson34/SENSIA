import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/models/user_profile.dart';
import 'package:izahay/models/user_role.dart';
import 'package:izahay/models/vibration_segment.dart';
import 'package:izahay/profile/profile_store.dart';

import 'fake_profile_repository.dart';

const _delay = Duration(milliseconds: 20);
Future<void> _wait() => Future<void>.delayed(const Duration(milliseconds: 120));

ProfileStore _store(FakeProfileRepository repository) =>
    ProfileStore(repository: repository, autosaveDelay: _delay);

void main() {
  test('chaque modification est sauvegardée, les rafales regroupées', () async {
    final repository = FakeProfileRepository();
    final store = _store(repository);
    await store.restore(); // aucune sauvegarde : l'état distant est connu

    store.setSetting('a', true);
    store.setRole(UserRole.client);
    store.setVibrationPattern('train', [VibrationSegment.short]);
    await _wait();

    expect(repository.saves, 1);
    expect(repository.stored!.role, UserRole.client);
    expect(repository.stored!.settings, {'a': true});
    expect(repository.stored!.vibrationPatterns['train'], [
      VibrationSegment.short,
    ]);

    store.setSetting('a', false);
    await _wait();
    expect(repository.saves, 2);
    expect(repository.stored!.settings, {'a': false});
    store.dispose();
  });

  test('rien n\'est sauvegardé avant que l\'état distant soit connu', () async {
    final repository = FakeProfileRepository()
      ..stored = UserProfile(role: UserRole.accompagnateur);
    final store = _store(repository);

    store.setSetting('a', true); // avant toute restauration
    await _wait();

    expect(repository.saves, 0);
    expect(repository.stored!.role, UserRole.accompagnateur);
    store.dispose();
  });

  test(
    'après un échec de lecture, la sauvegarde distante n\'est pas écrasée',
    () async {
      final repository = FakeProfileRepository()
        ..stored = UserProfile(role: UserRole.accompagnateur)
        ..failing = true;
      final store = _store(repository);
      expect(await store.restore(), ProfileSyncResult.failed);

      repository.failing = false;
      store.setSetting('a', true);
      await _wait();

      expect(repository.saves, 0);
      expect(repository.stored!.role, UserRole.accompagnateur);
      store.dispose();
    },
  );

  test(
    'une sauvegarde manuelle réussie active la sauvegarde automatique',
    () async {
      final repository = FakeProfileRepository()..failing = true;
      final store = _store(repository);
      await store.restore(); // échec : pas d'auto-sauvegarde

      repository.failing = false;
      expect(await store.save(), ProfileSyncResult.saved);
      store.setSetting('a', true);
      await _wait();

      expect(repository.saves, 2);
      store.dispose();
    },
  );

  test('flushPending sauvegarde tout de suite', () async {
    final repository = FakeProfileRepository();
    final store = ProfileStore(
      repository: repository,
      autosaveDelay: const Duration(seconds: 30),
    );
    await store.restore();

    store.setSetting('a', true);
    expect(repository.saves, 0);
    await store.flushPending();
    expect(repository.saves, 1);

    // Plus rien en attente : pas de seconde écriture.
    await store.flushPending();
    expect(repository.saves, 1);
    store.dispose();
  });

  test('un échec d\'écriture automatique est silencieux et réessayé', () async {
    final repository = FakeProfileRepository();
    final store = _store(repository);
    await store.restore();

    repository.failing = true;
    store.setSetting('a', true);
    await _wait(); // échoue sans lever d'exception

    repository.failing = false;
    store.setSetting('b', true);
    await _wait();
    expect(repository.stored!.settings, {'a': true, 'b': true});
    store.dispose();
  });

  test('fermer le store annule la sauvegarde en attente', () async {
    final repository = FakeProfileRepository();
    final store = _store(repository);
    await store.restore();

    store.setSetting('a', true);
    store.dispose();
    await _wait();
    expect(repository.saves, 0);
  });

  test('sans dépôt, aucune sauvegarde n\'est tentée', () async {
    final store = ProfileStore(autosaveDelay: _delay);
    store.setSetting('a', true);
    await _wait();
    store.dispose();
  });
}
