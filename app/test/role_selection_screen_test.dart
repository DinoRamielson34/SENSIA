import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/localization/language_storage.dart';
import 'package:izahay/localization/locale_controller.dart';
import 'package:izahay/localization/locale_scope.dart';
import 'package:izahay/models/user_role.dart';
import 'package:izahay/screens/role_selection_screen.dart';

void main() {
  testWidgets('Suivants est inactif tant qu\'aucun rôle n\'est choisi', (
    tester,
  ) async {
    UserRole? result;
    await tester.pumpWidget(
      MaterialApp(home: RoleSelectionScreen(onContinue: (r) => result = r)),
    );

    expect(find.text('Êtes-vous...'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.skip_next_outlined));
    await tester.pump();
    expect(result, isNull);

    await tester.tap(find.text('Client'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.skip_next_outlined));
    expect(result, UserRole.client);
  });

  testWidgets('affiche en malagasy avec un LocaleScope, bascule au tap', (
    tester,
  ) async {
    final controller = LocaleController(storage: MemoryLanguageStorage());
    await tester.pumpWidget(
      MaterialApp(
        home: LocaleScope(
          controller: controller,
          child: const RoleSelectionScreen(),
        ),
      ),
    );

    expect(find.text('Ianao ve dia...'), findsOneWidget);
    expect(find.text('Mpanjifa'), findsOneWidget);

    await tester.tap(find.text('FR'));
    await tester.pump();

    expect(find.text('Êtes-vous...'), findsOneWidget);
    expect(find.text('Client'), findsOneWidget);
  });
}
