import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    await tester.tap(find.text('Suivants'));
    await tester.pump();
    expect(result, isNull);

    await tester.tap(find.text('Client'));
    await tester.pump();
    await tester.tap(find.text('Suivants'));
    expect(result, UserRole.client);
  });
}
