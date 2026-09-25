import 'package:integration_test/integration_test_driver.dart';

/// Driver standard requis par `flutter drive` pour exécuter les tests
/// integration_test sur une plateforme web (Chrome) : `flutter test`
/// seul ne supporte pas les devices web pour integration_test.
Future<void> main() => integrationDriver();
