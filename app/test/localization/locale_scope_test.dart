import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/localization/app_strings.dart';
import 'package:izahay/localization/locale_controller.dart';
import 'package:izahay/localization/locale_scope.dart';
import 'package:izahay/localization/language_storage.dart';

class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) => Text(LocaleScope.of(context).roleClient);
}

void main() {
  testWidgets('sans LocaleScope ancêtre, of() replie sur le français', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _Probe()));
    expect(find.text(AppStrings.fr.roleClient), findsOneWidget);
    expect(find.text(AppStrings.mg.roleClient), findsNothing);
  });

  testWidgets('avec LocaleScope, of() lit la langue du contrôleur', (
    tester,
  ) async {
    final controller = LocaleController(storage: MemoryLanguageStorage());
    await tester.pumpWidget(
      MaterialApp(
        home: LocaleScope(controller: controller, child: const _Probe()),
      ),
    );
    expect(find.text(AppStrings.mg.roleClient), findsOneWidget);

    await controller.toggle();
    await tester.pump();
    expect(find.text(AppStrings.fr.roleClient), findsOneWidget);
  });

  testWidgets('controllerOf retourne null sans ancêtre, le contrôleur avec', (
    tester,
  ) async {
    late BuildContext withoutScope;
    late BuildContext withScope;
    final controller = LocaleController(storage: MemoryLanguageStorage());
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            Builder(
              builder: (c) {
                withoutScope = c;
                return const SizedBox.shrink();
              },
            ),
            LocaleScope(
              controller: controller,
              child: Builder(
                builder: (c) {
                  withScope = c;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
    expect(LocaleScope.controllerOf(withoutScope), isNull);
    expect(LocaleScope.controllerOf(withScope), same(controller));
  });
}
