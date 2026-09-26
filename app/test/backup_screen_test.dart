import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/models/user_role.dart';
import 'package:izahay/profile/profile_store.dart';
import 'package:izahay/screens/backup_screen.dart';

import 'profile/fake_profile_repository.dart';

void _useMockupSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('affiche l\'ID puis sauvegarde et restaure', (tester) async {
    _useMockupSize(tester);
    final repository = FakeProfileRepository();
    final store = ProfileStore(repository: repository)
      ..setRole(UserRole.client);
    await tester.pumpWidget(MaterialApp(home: BackupScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('ID: uid-test-123'), findsOneWidget);

    await tester.tap(find.text('Sauvegarder mes donnees'));
    await tester.pumpAndSettle();
    expect(repository.saves, 1);
    expect(find.text('Données sauvegardées.'), findsOneWidget);

    // On perd le rôle en mémoire, la restauration le ramène.
    store.profile.role = null;
    await tester.tap(find.text('Restaurer les donnees'));
    await tester.pumpAndSettle();
    expect(store.profile.role, UserRole.client);
    expect(find.text('Données restaurées.'), findsOneWidget);
  });

  testWidgets('sans Firebase, l\'écran l\'indique sans planter', (
    tester,
  ) async {
    _useMockupSize(tester);
    await tester.pumpWidget(
      MaterialApp(home: BackupScreen(store: ProfileStore())),
    );
    await tester.pumpAndSettle();

    expect(find.text('ID: indisponible'), findsOneWidget);
    await tester.tap(find.text('Sauvegarder mes donnees'));
    await tester.pumpAndSettle();
    expect(find.text('Sauvegarde indisponible.'), findsOneWidget);
  });

  testWidgets('un échec du dépôt affiche un message d\'erreur', (tester) async {
    _useMockupSize(tester);
    final repository = FakeProfileRepository()..failing = true;
    await tester.pumpWidget(
      MaterialApp(
        home: BackupScreen(store: ProfileStore(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Restaurer les donnees'));
    await tester.pumpAndSettle();
    expect(find.text('Échec, réessayez plus tard.'), findsOneWidget);
  });
}
