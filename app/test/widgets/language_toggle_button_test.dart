import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/localization/language_storage.dart';
import 'package:izahay/localization/locale_controller.dart';
import 'package:izahay/widgets/language_toggle_button.dart';

void main() {
  testWidgets('sans contrôleur, ne rend rien', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LanguageToggleButton(controller: null),
      ),
    );
    expect(find.byType(SizedBox), findsOneWidget);
    expect(find.text('MG'), findsNothing);
    expect(find.text('FR'), findsNothing);
  });

  testWidgets('affiche la langue cible et bascule au tap', (tester) async {
    final controller = LocaleController(storage: MemoryLanguageStorage());
    await tester.pumpWidget(
      MaterialApp(home: LanguageToggleButton(controller: controller)),
    );

    // Actuellement malagasy : le bouton propose de passer en français.
    expect(find.text('FR'), findsOneWidget);

    await tester.tap(find.text('FR'));
    await tester.pump();

    expect(controller.language.name, 'francais');
    expect(find.text('MG'), findsOneWidget);
  });
}
