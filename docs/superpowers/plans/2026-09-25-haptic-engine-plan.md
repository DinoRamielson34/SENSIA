# Moteur de vibrations IZAHAY — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construire un moteur de vibrations Flutter/Android modulaire, testable sans IA/Firebase/écrans, qui joue des motifs personnalisables associés à des catégories sonores fournies dynamiquement.

**Architecture:** Une façade Dart (`HapticEngine`) orchestre validation, registre de motifs et exécution, découplée du natif via une interface `VibrationExecutor` (implémentation réelle par `MethodChannel`, double de test en mémoire). Le natif Android (`HapticsChannelHandler.kt`) traduit les appels en `VibrationEffect`/`Vibrator`.

**Tech Stack:** Flutter/Dart (SDK `^3.12.0`), Kotlin (Android, package `mg.izahay.izahay`), `flutter_test`, `integration_test` (package SDK Flutter).

**Spec:** [docs/superpowers/specs/2026-09-25-haptic-engine-design.md](../specs/2026-09-25-haptic-engine-design.md)

## Global Constraints

- Le package Android reste `mg.izahay.izahay` ; aucune migration de framework, aucun changement de nom de package.
- Aucune nouvelle dépendance pub.dev externe. Seule `integration_test` (package du SDK Flutter, pas pub.dev) est ajoutée aux `dev_dependencies`.
- Toute erreur remontée par le moteur doit être une des trois exceptions typées du module (`InvalidVibrationPatternException`, `HapticUnsupportedException`, `HapticPlatformException`) — jamais une exception générique non gérée, jamais avalée silencieusement.
- Pas de répétition infinie d'un motif : chaque vibration est jouée une seule fois (paramètre `-1` côté natif).
- Politique de concurrence : "la dernière demande gagne" — pas de file d'attente, pas de blocage.
- `app/lib/main.dart` n'est modifié par aucune tâche de ce plan.

## Review Focus

- Motif avec une pause nulle (`Duration.zero`) entre deux impulsions au milieu de la séquence : la conversion vers le tableau natif alterné doit rester correcte (pas de décalage de parité qui ferait interpréter une vibration comme une pause). Couvert par la Task 6.
- Deux appels `playPattern`/`playForCategory` déclenchés en concurrence rapprochée : seul le plus récent doit réellement vibrer — jamais les deux motifs mélangés, jamais aucun. Couvert par la Task 7.
- `PlatformException` remontée par le canal natif : doit être enveloppée en `HapticPlatformException`, jamais propagée telle quelle, jamais avalée. Couvert par la Task 5.
- Catégorie inconnue passée à `playForCategory` : comportement explicite et typé (`InvalidVibrationPatternException`), pas un crash générique ni un no-op silencieux non documenté. Couvert par la Task 6.
- Appareil sans vibreur : `playPattern` doit refuser avant tout appel natif à `vibrate`, sans dépendre du fait que l'appelant ait pensé à interroger `isDeviceCompatible()` au préalable. Couvert par la Task 6.

---

## Task 1: Corriger le test existant cassé

`test/widget_test.dart` référence encore une classe `MyApp` et une icône `Icons.add` qui n'existent plus dans `lib/main.dart` (qui définit `IzahayApp`/`TestScreen`, bouton "Tester", texte "Bouton pressé : N fois"). `flutter test` échoue actuellement pour une raison sans rapport avec le moteur haptique. Cette tâche assainit la base avant d'ajouter les tests du module.

**Files:**
- Modify: `app/test/widget_test.dart`

**Interfaces:**
- Consumes: `IzahayApp` (`app/lib/main.dart`, déjà existant)
- Produces: rien de nouveau pour les autres tâches

- [ ] **Step 1: Remplacer le contenu du test pour refléter le vrai widget**

```dart
// Test de smoke basique pour l'écran de test IZAHAY.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:izahay/main.dart';

void main() {
  testWidgets('le compteur de taps s\'incrémente au clic', (tester) async {
    await tester.pumpWidget(const IzahayApp());

    expect(find.text('Bouton pressé : 0 fois'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Tester'));
    await tester.pump();

    expect(find.text('Bouton pressé : 1 fois'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il passe**

Run: `cd app && flutter test test/widget_test.dart`
Expected: PASS (1 test)

- [ ] **Step 3: Commit**

```bash
git add app/test/widget_test.dart
git commit -m "fix: align widget_test.dart with the actual TestScreen widget"
```

---

## Task 2: Modèle de données du motif de vibration

Définit les types de données purs utilisés par tout le reste du module : une impulsion (`VibrationPulse`) et un motif complet (`VibrationPattern`).

**Files:**
- Create: `app/lib/haptics/models/vibration_pattern.dart`
- Test: `app/test/haptics/vibration_pattern_test.dart`

**Interfaces:**
- Produces: `VibrationPulse({required Duration vibrate, Duration pauseAfter = Duration.zero})`, `VibrationPattern({required String id, required List<VibrationPulse> pulses})` — utilisés par toutes les tâches suivantes.

- [ ] **Step 1: Écrire le test qui échoue**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/haptics/models/vibration_pattern.dart';

void main() {
  test('VibrationPulse expose vibrate et pauseAfter (pauseAfter par défaut à zéro)', () {
    const pulse = VibrationPulse(vibrate: Duration(milliseconds: 150));
    expect(pulse.vibrate, const Duration(milliseconds: 150));
    expect(pulse.pauseAfter, Duration.zero);
  });

  test('VibrationPattern expose id et la liste des impulsions', () {
    const pattern = VibrationPattern(
      id: 'sonnette',
      pulses: [
        VibrationPulse(
          vibrate: Duration(milliseconds: 150),
          pauseAfter: Duration(milliseconds: 150),
        ),
      ],
    );
    expect(pattern.id, 'sonnette');
    expect(pattern.pulses, hasLength(1));
    expect(pattern.pulses.single.vibrate, const Duration(milliseconds: 150));
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `cd app && flutter test test/haptics/vibration_pattern_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:izahay/haptics/models/vibration_pattern.dart'`

- [ ] **Step 3: Implémenter le modèle**

```dart
/// Une impulsion de vibration : une durée de vibration suivie d'une pause
/// optionnelle.
class VibrationPulse {
  /// Durée pendant laquelle le téléphone vibre. Doit être strictement
  /// positive (validé par [PatternValidator], pas ici).
  final Duration vibrate;

  /// Durée de la pause après cette impulsion. `Duration.zero` si aucune
  /// pause n'est nécessaire (par exemple la dernière impulsion d'un motif).
  final Duration pauseAfter;

  const VibrationPulse({
    required this.vibrate,
    this.pauseAfter = Duration.zero,
  });
}

/// Un motif de vibration complet : une suite ordonnée d'impulsions.
///
/// [id] identifie le motif dans les messages d'erreur et les logs, par
/// exemple "sonnette" ou "alarme".
class VibrationPattern {
  final String id;
  final List<VibrationPulse> pulses;

  const VibrationPattern({
    required this.id,
    required this.pulses,
  });
}
```

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `cd app && flutter test test/haptics/vibration_pattern_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/haptics/models/vibration_pattern.dart app/test/haptics/vibration_pattern_test.dart
git commit -m "feat: add VibrationPulse/VibrationPattern data model"
```

---

## Task 3: Exceptions du module et validation des motifs

Définit les trois exceptions typées du module et `PatternValidator`, qui garantit qu'un motif est exécutable avant qu'il n'atteigne le registre ou l'executor.

**Files:**
- Create: `app/lib/haptics/haptic_exceptions.dart`
- Create: `app/lib/haptics/pattern_validator.dart`
- Test: `app/test/haptics/pattern_validator_test.dart`

**Interfaces:**
- Consumes: `VibrationPattern`, `VibrationPulse` (Task 2)
- Produces: `InvalidVibrationPatternException`, `HapticUnsupportedException`, `HapticPlatformException` (classes `implements Exception`, champ `message`) ; `PatternValidator().validate(VibrationPattern pattern)` (lève `InvalidVibrationPatternException`, ne retourne rien si valide) — utilisés par les Tasks 4, 5, 6.

- [ ] **Step 1: Écrire le test qui échoue**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/haptics/haptic_exceptions.dart';
import 'package:izahay/haptics/models/vibration_pattern.dart';
import 'package:izahay/haptics/pattern_validator.dart';

void main() {
  const validator = PatternValidator();

  test('accepte un motif avec au moins une impulsion valide', () {
    const pattern = VibrationPattern(
      id: 'test',
      pulses: [VibrationPulse(vibrate: Duration(milliseconds: 100))],
    );
    expect(() => validator.validate(pattern), returnsNormally);
  });

  test('rejette un motif sans impulsion', () {
    const pattern = VibrationPattern(id: 'vide', pulses: []);
    expect(
      () => validator.validate(pattern),
      throwsA(isA<InvalidVibrationPatternException>()),
    );
  });

  test('rejette une durée de vibration nulle', () {
    const pattern = VibrationPattern(
      id: 'nul',
      pulses: [VibrationPulse(vibrate: Duration.zero)],
    );
    expect(
      () => validator.validate(pattern),
      throwsA(isA<InvalidVibrationPatternException>()),
    );
  });

  test('rejette une durée de vibration négative', () {
    const pattern = VibrationPattern(
      id: 'negatif',
      pulses: [VibrationPulse(vibrate: Duration(milliseconds: -1))],
    );
    expect(
      () => validator.validate(pattern),
      throwsA(isA<InvalidVibrationPatternException>()),
    );
  });

  test('rejette une pause négative', () {
    const pattern = VibrationPattern(
      id: 'pause-negative',
      pulses: [
        VibrationPulse(
          vibrate: Duration(milliseconds: 100),
          pauseAfter: Duration(milliseconds: -1),
        ),
      ],
    );
    expect(
      () => validator.validate(pattern),
      throwsA(isA<InvalidVibrationPatternException>()),
    );
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `cd app && flutter test test/haptics/pattern_validator_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:izahay/haptics/pattern_validator.dart'`

- [ ] **Step 3: Implémenter les exceptions**

```dart
/// Exception levée quand un [VibrationPattern] ne respecte pas les règles de
/// validité (voir [PatternValidator]) : par exemple une liste d'impulsions
/// vide, ou une durée de vibration nulle/négative.
class InvalidVibrationPatternException implements Exception {
  final String message;
  const InvalidVibrationPatternException(this.message);

  @override
  String toString() => 'InvalidVibrationPatternException: $message';
}

/// Exception levée quand l'appareil ne dispose d'aucun vibreur matériel.
/// Vérifiable à l'avance via `HapticEngine.isDeviceCompatible`.
class HapticUnsupportedException implements Exception {
  final String message;
  const HapticUnsupportedException(this.message);

  @override
  String toString() => 'HapticUnsupportedException: $message';
}

/// Enveloppe une erreur native inattendue remontée par le canal de
/// communication Flutter <-> Android (ex : PlatformException).
class HapticPlatformException implements Exception {
  final String message;
  final Object? cause;
  const HapticPlatformException(this.message, {this.cause});

  @override
  String toString() => 'HapticPlatformException: $message'
      '${cause != null ? ' (cause: $cause)' : ''}';
}
```

- [ ] **Step 4: Implémenter le validateur**

```dart
import 'haptic_exceptions.dart';
import 'models/vibration_pattern.dart';

/// Valide qu'un [VibrationPattern] peut être exécuté en toute sécurité.
///
/// Un motif est valide s'il contient au moins une impulsion et si chaque
/// impulsion a une durée de vibration strictement positive et une pause
/// non négative.
class PatternValidator {
  const PatternValidator();

  /// Lève [InvalidVibrationPatternException] si [pattern] n'est pas valide.
  /// Ne retourne rien si le motif est valide.
  void validate(VibrationPattern pattern) {
    if (pattern.pulses.isEmpty) {
      throw InvalidVibrationPatternException(
        'Le motif "${pattern.id}" ne contient aucune impulsion',
      );
    }
    for (var i = 0; i < pattern.pulses.length; i++) {
      final pulse = pattern.pulses[i];
      if (pulse.vibrate <= Duration.zero) {
        throw InvalidVibrationPatternException(
          'Le motif "${pattern.id}" a une durée de vibration invalide à '
          'l\'impulsion $i : ${pulse.vibrate}',
        );
      }
      if (pulse.pauseAfter < Duration.zero) {
        throw InvalidVibrationPatternException(
          'Le motif "${pattern.id}" a une pause négative à l\'impulsion $i : '
          '${pulse.pauseAfter}',
        );
      }
    }
  }
}
```

- [ ] **Step 5: Lancer le test et vérifier qu'il passe**

Run: `cd app && flutter test test/haptics/pattern_validator_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 6: Commit**

```bash
git add app/lib/haptics/haptic_exceptions.dart app/lib/haptics/pattern_validator.dart app/test/haptics/pattern_validator_test.dart
git commit -m "feat: add haptic exceptions and pattern validator"
```

---

## Task 4: Registre catégorie → motif

`PatternRegistry` associe une catégorie sonore (fournie dynamiquement par le module IA) à un motif, avec deux motifs d'exemple préchargés à titre de démonstration.

**Files:**
- Create: `app/lib/haptics/pattern_registry.dart`
- Test: `app/test/haptics/pattern_registry_test.dart`

**Interfaces:**
- Consumes: `VibrationPattern` (Task 2), `PatternValidator` (Task 3)
- Produces: `PatternRegistry({PatternValidator validator})`, `.register(String category, VibrationPattern pattern)` (lève `InvalidVibrationPatternException` si invalide), `.lookup(String category) -> VibrationPattern?` — utilisés par la Task 6.

- [ ] **Step 1: Écrire le test qui échoue**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/haptics/haptic_exceptions.dart';
import 'package:izahay/haptics/models/vibration_pattern.dart';
import 'package:izahay/haptics/pattern_registry.dart';

void main() {
  test('contient les motifs par défaut sonnette et aboiement', () {
    final registry = PatternRegistry();
    expect(registry.lookup('sonnette'), isNotNull);
    expect(registry.lookup('aboiement'), isNotNull);
  });

  test('lookup retourne null pour une catégorie inconnue', () {
    final registry = PatternRegistry();
    expect(registry.lookup('inconnue'), isNull);
  });

  test('register ajoute une nouvelle catégorie', () {
    final registry = PatternRegistry();
    const pattern = VibrationPattern(
      id: 'alarme',
      pulses: [VibrationPulse(vibrate: Duration(milliseconds: 200))],
    );
    registry.register('alarme', pattern);
    expect(registry.lookup('alarme'), same(pattern));
  });

  test('register remplace un motif existant', () {
    final registry = PatternRegistry();
    const remplacement = VibrationPattern(
      id: 'sonnette',
      pulses: [VibrationPulse(vibrate: Duration(milliseconds: 999))],
    );
    registry.register('sonnette', remplacement);
    expect(registry.lookup('sonnette'), same(remplacement));
  });

  test('register rejette un motif invalide sans l\'enregistrer', () {
    final registry = PatternRegistry();
    const invalide = VibrationPattern(id: 'invalide', pulses: []);
    expect(
      () => registry.register('invalide', invalide),
      throwsA(isA<InvalidVibrationPatternException>()),
    );
    expect(registry.lookup('invalide'), isNull);
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `cd app && flutter test test/haptics/pattern_registry_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:izahay/haptics/pattern_registry.dart'`

- [ ] **Step 3: Implémenter le registre**

```dart
import 'models/vibration_pattern.dart';
import 'pattern_validator.dart';

/// Table en mémoire associant une catégorie sonore (fournie dynamiquement
/// par le module de reconnaissance sonore) à un [VibrationPattern].
///
/// Seedée avec deux motifs d'exemple ("sonnette", "aboiement") à titre de
/// démonstration : la liste des catégories réelles n'est pas figée et sera
/// alimentée par le module IA et personnalisée par l'utilisateur via
/// l'interface.
class PatternRegistry {
  final PatternValidator _validator;
  final Map<String, VibrationPattern> _patterns = {};

  PatternRegistry({PatternValidator validator = const PatternValidator()})
      : _validator = validator {
    _seedDefaults();
  }

  void _seedDefaults() {
    register(
      'sonnette',
      const VibrationPattern(
        id: 'sonnette',
        pulses: [
          VibrationPulse(
            vibrate: Duration(milliseconds: 150),
            pauseAfter: Duration(milliseconds: 150),
          ),
          VibrationPulse(vibrate: Duration(milliseconds: 150)),
        ],
      ),
    );
    register(
      'aboiement',
      const VibrationPattern(
        id: 'aboiement',
        pulses: [
          VibrationPulse(
            vibrate: Duration(milliseconds: 400),
            pauseAfter: Duration(milliseconds: 200),
          ),
          VibrationPulse(
            vibrate: Duration(milliseconds: 400),
            pauseAfter: Duration(milliseconds: 200),
          ),
          VibrationPulse(vibrate: Duration(milliseconds: 400)),
        ],
      ),
    );
  }

  /// Enregistre [pattern] pour [category], en remplaçant tout motif déjà
  /// enregistré pour cette catégorie.
  ///
  /// Lève [InvalidVibrationPatternException] (via [PatternValidator]) si
  /// [pattern] n'est pas valide — rien n'est enregistré dans ce cas.
  void register(String category, VibrationPattern pattern) {
    _validator.validate(pattern);
    _patterns[category] = pattern;
  }

  /// Retourne le motif enregistré pour [category], ou `null` si aucune
  /// catégorie de ce nom n'a été enregistrée.
  VibrationPattern? lookup(String category) => _patterns[category];
}
```

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `cd app && flutter test test/haptics/pattern_registry_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/haptics/pattern_registry.dart app/test/haptics/pattern_registry_test.dart
git commit -m "feat: add PatternRegistry mapping categories to vibration patterns"
```

---

## Task 5: Interface d'exécution + implémentation MethodChannel

Définit le contrat `VibrationExecutor` (qui découple le moteur du natif) et son implémentation réelle basée sur un `MethodChannel`, avec conversion des `PlatformException` en `HapticPlatformException`. Testé avec un canal mocké — aucun appareil requis.

**Files:**
- Create: `app/lib/haptics/vibration_executor.dart`
- Test: `app/test/haptics/vibration_executor_test.dart`

**Interfaces:**
- Consumes: `HapticPlatformException` (Task 3)
- Produces: `abstract class VibrationExecutor { Future<bool> hasVibrator(); Future<void> vibrate(List<int> nativeTimingsMs); Future<void> cancel(); }`, `MethodChannelVibrationExecutor` (implémente `VibrationExecutor`, canal `"mg.izahay.izahay/haptics"`) — l'interface est consommée par les Tasks 6/7/9, le canal est consommé côté natif par la Task 8.

- [ ] **Step 1: Écrire le test qui échoue**

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/haptics/haptic_exceptions.dart';
import 'package:izahay/haptics/vibration_executor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('mg.izahay.izahay/haptics');
  const executor = MethodChannelVibrationExecutor();

  void mockChannel(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('hasVibrator retourne la valeur renvoyée par le canal natif', () async {
    mockChannel((call) async {
      expect(call.method, 'hasVibrator');
      return true;
    });
    expect(await executor.hasVibrator(), isTrue);
  });

  test('vibrate envoie les timings au canal natif', () async {
    List<Object?>? receivedTimings;
    mockChannel((call) async {
      expect(call.method, 'vibrate');
      receivedTimings = (call.arguments as Map)['timings'] as List<Object?>;
      return null;
    });
    await executor.vibrate([0, 150, 150, 150]);
    expect(receivedTimings, [0, 150, 150, 150]);
  });

  test('cancel appelle la méthode native cancel', () async {
    var called = false;
    mockChannel((call) async {
      called = true;
      expect(call.method, 'cancel');
      return null;
    });
    await executor.cancel();
    expect(called, isTrue);
  });

  test('une PlatformException est enveloppée dans HapticPlatformException',
      () async {
    mockChannel((call) async {
      throw PlatformException(code: 'ERROR', message: 'panne simulée');
    });
    expect(
      () => executor.hasVibrator(),
      throwsA(isA<HapticPlatformException>()),
    );
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `cd app && flutter test test/haptics/vibration_executor_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:izahay/haptics/vibration_executor.dart'`

- [ ] **Step 3: Implémenter l'interface et le canal**

```dart
import 'package:flutter/services.dart';

import 'haptic_exceptions.dart';

/// Contrat d'exécution des vibrations, indépendant de toute plateforme.
///
/// Permet à `HapticEngine` de rester testable sans dépendre d'un canal
/// Android réel (voir la fausse implémentation utilisée dans les tests).
abstract class VibrationExecutor {
  /// Indique si l'appareil dispose d'un vibreur matériel.
  Future<bool> hasVibrator();

  /// Déclenche une vibration décrite par [nativeTimingsMs] : un tableau
  /// alterné `[délai_initial, vibre, pause, vibre, pause, ...]` en
  /// millisecondes, au format attendu par l'API Android.
  Future<void> vibrate(List<int> nativeTimingsMs);

  /// Annule toute vibration en cours. Ne fait rien si aucune vibration
  /// n'est en cours.
  Future<void> cancel();
}

/// Implémentation réelle de [VibrationExecutor], qui délègue au code natif
/// Android via un [MethodChannel].
class MethodChannelVibrationExecutor implements VibrationExecutor {
  static const _channel = MethodChannel('mg.izahay.izahay/haptics');

  const MethodChannelVibrationExecutor();

  @override
  Future<bool> hasVibrator() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasVibrator');
      return result ?? false;
    } on PlatformException catch (e) {
      throw HapticPlatformException(
        'Échec de la vérification du vibreur',
        cause: e,
      );
    }
  }

  @override
  Future<void> vibrate(List<int> nativeTimingsMs) async {
    try {
      await _channel.invokeMethod<void>('vibrate', {
        'timings': nativeTimingsMs,
      });
    } on PlatformException catch (e) {
      throw HapticPlatformException(
        'Échec du déclenchement de la vibration',
        cause: e,
      );
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } on PlatformException catch (e) {
      throw HapticPlatformException(
        'Échec de l\'annulation de la vibration',
        cause: e,
      );
    }
  }
}
```

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `cd app && flutter test test/haptics/vibration_executor_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/haptics/vibration_executor.dart app/test/haptics/vibration_executor_test.dart
git commit -m "feat: add VibrationExecutor contract and MethodChannel implementation"
```

---

## Task 6: HapticEngine — cœur (validation, exécution, arrêt, catégories)

La façade publique du module. Cette tâche couvre le chemin nominal : validation, vérification de compatibilité, conversion du motif vers le tableau natif, exécution, arrêt, et résolution par catégorie. La politique de concurrence (Task 7) n'est pas encore en place — un appel `playPattern` annule toujours la vibration précédente avant de démarrer, sans protection contre les appels concurrents chevauchants.

**Files:**
- Create: `app/lib/haptics/haptic_engine.dart`
- Create: `app/test/haptics/fake_vibration_executor.dart`
- Test: `app/test/haptics/haptic_engine_test.dart`

**Interfaces:**
- Consumes: `VibrationExecutor` (Task 5), `VibrationPattern`/`VibrationPulse` (Task 2), `PatternRegistry` (Task 4), `PatternValidator` (Task 3), les trois exceptions (Task 3)
- Produces: `HapticEngine({required VibrationExecutor executor, PatternRegistry? registry, PatternValidator? validator})`, `.playPattern(VibrationPattern)`, `.playForCategory(String category)`, `.registerPattern(String category, VibrationPattern pattern)`, `.stop()`, `.isDeviceCompatible() -> Future<bool>` ; `FakeVibrationExecutor` (double de test, champs `hasVibratorResult`, `cancelDelay`, `vibrateCalls`, `callLog`) — l'engine est consommé par la Task 9, le fake par les Tasks 7 et 9.

- [ ] **Step 1: Créer le double de test**

```dart
import 'package:izahay/haptics/vibration_executor.dart';

/// Double de test pour [VibrationExecutor] : n'appelle aucune API Android,
/// enregistre simplement les appels reçus pour que les tests puissent les
/// vérifier.
class FakeVibrationExecutor implements VibrationExecutor {
  bool hasVibratorResult = true;

  /// Délai artificiel appliqué à [cancel], pour simuler une opération native
  /// lente et pouvoir tester les scénarios de concurrence (Task 7).
  Duration cancelDelay = Duration.zero;

  final List<List<int>> vibrateCalls = [];
  final List<String> callLog = [];

  @override
  Future<bool> hasVibrator() async {
    callLog.add('hasVibrator');
    return hasVibratorResult;
  }

  @override
  Future<void> vibrate(List<int> nativeTimingsMs) async {
    callLog.add('vibrate');
    vibrateCalls.add(nativeTimingsMs);
  }

  @override
  Future<void> cancel() async {
    if (cancelDelay > Duration.zero) {
      await Future<void>.delayed(cancelDelay);
    }
    callLog.add('cancel');
  }
}
```

- [ ] **Step 2: Écrire le test qui échoue**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/haptics/haptic_engine.dart';
import 'package:izahay/haptics/haptic_exceptions.dart';
import 'package:izahay/haptics/models/vibration_pattern.dart';

import 'fake_vibration_executor.dart';

void main() {
  late FakeVibrationExecutor executor;
  late HapticEngine engine;

  setUp(() {
    executor = FakeVibrationExecutor();
    engine = HapticEngine(executor: executor);
  });

  test('playPattern déclenche la vibration avec les bons timings natifs',
      () async {
    const pattern = VibrationPattern(
      id: 'simple',
      pulses: [VibrationPulse(vibrate: Duration(milliseconds: 200))],
    );

    await engine.playPattern(pattern);

    expect(executor.vibrateCalls.single, [0, 200, 0]);
  });

  test('playPattern convertit correctement un motif avec une pause nulle '
      'au milieu de la séquence', () async {
    const pattern = VibrationPattern(
      id: 'pauses-multiples',
      pulses: [
        VibrationPulse(
          vibrate: Duration(milliseconds: 100),
          pauseAfter: Duration(milliseconds: 50),
        ),
        VibrationPulse(vibrate: Duration(milliseconds: 80)),
        VibrationPulse(
          vibrate: Duration(milliseconds: 120),
          pauseAfter: Duration(milliseconds: 60),
        ),
      ],
    );

    await engine.playPattern(pattern);

    expect(executor.vibrateCalls.single, [0, 100, 50, 80, 0, 120, 60]);
  });

  test('playPattern lève InvalidVibrationPatternException pour un motif '
      'invalide et n\'appelle jamais l\'executor', () async {
    const invalide = VibrationPattern(id: 'vide', pulses: []);

    await expectLater(
      () => engine.playPattern(invalide),
      throwsA(isA<InvalidVibrationPatternException>()),
    );
    expect(executor.callLog, isEmpty);
  });

  test('playPattern lève HapticUnsupportedException si l\'appareil n\'a pas '
      'de vibreur et n\'appelle jamais vibrate', () async {
    executor.hasVibratorResult = false;
    const pattern = VibrationPattern(
      id: 'simple',
      pulses: [VibrationPulse(vibrate: Duration(milliseconds: 100))],
    );

    await expectLater(
      () => engine.playPattern(pattern),
      throwsA(isA<HapticUnsupportedException>()),
    );
    expect(executor.vibrateCalls, isEmpty);
  });

  test('playPattern annule toute vibration en cours avant de démarrer la '
      'nouvelle', () async {
    const pattern = VibrationPattern(
      id: 'simple',
      pulses: [VibrationPulse(vibrate: Duration(milliseconds: 100))],
    );

    await engine.playPattern(pattern);

    expect(executor.callLog, ['hasVibrator', 'cancel', 'vibrate']);
  });

  test('stop appelle cancel sur l\'executor', () async {
    await engine.stop();
    expect(executor.callLog, ['cancel']);
  });

  test('registerPattern puis playForCategory joue le motif enregistré',
      () async {
    const pattern = VibrationPattern(
      id: 'alarme',
      pulses: [VibrationPulse(vibrate: Duration(milliseconds: 300))],
    );
    engine.registerPattern('alarme', pattern);

    await engine.playForCategory('alarme');

    expect(executor.vibrateCalls.single, [0, 300, 0]);
  });

  test('playForCategory lève InvalidVibrationPatternException pour une '
      'catégorie inconnue', () async {
    await expectLater(
      () => engine.playForCategory('inconnue'),
      throwsA(isA<InvalidVibrationPatternException>()),
    );
    expect(executor.callLog, isEmpty);
  });
}
```

- [ ] **Step 3: Lancer le test et vérifier qu'il échoue**

Run: `cd app && flutter test test/haptics/haptic_engine_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:izahay/haptics/haptic_engine.dart'`

- [ ] **Step 4: Implémenter HapticEngine (sans protection de concurrence)**

```dart
import 'haptic_exceptions.dart';
import 'models/vibration_pattern.dart';
import 'pattern_registry.dart';
import 'pattern_validator.dart';
import 'vibration_executor.dart';

/// Point d'entrée public du moteur de vibrations. C'est la seule classe que
/// les autres modules (IA, interface utilisateur) doivent utiliser.
class HapticEngine {
  final VibrationExecutor _executor;
  final PatternRegistry _registry;
  final PatternValidator _validator;

  HapticEngine({
    required VibrationExecutor executor,
    PatternRegistry? registry,
    PatternValidator? validator,
  })  : _executor = executor,
        _registry = registry ?? PatternRegistry(),
        _validator = validator ?? const PatternValidator();

  /// Enregistre ou remplace le motif associé à [category]. Valide le motif
  /// avant de l'enregistrer.
  ///
  /// Lève [InvalidVibrationPatternException] si [pattern] n'est pas valide.
  void registerPattern(String category, VibrationPattern pattern) {
    _registry.register(category, pattern);
  }

  /// Indique si l'appareil dispose d'un vibreur matériel.
  Future<bool> isDeviceCompatible() => _executor.hasVibrator();

  /// Joue le motif enregistré pour [category].
  ///
  /// Lève [InvalidVibrationPatternException] si aucun motif n'est enregistré
  /// pour cette catégorie. Lève [HapticUnsupportedException] si l'appareil
  /// n'a pas de vibreur.
  Future<void> playForCategory(String category) async {
    final pattern = _registry.lookup(category);
    if (pattern == null) {
      throw InvalidVibrationPatternException(
        'Aucun motif enregistré pour la catégorie "$category"',
      );
    }
    await playPattern(pattern);
  }

  /// Joue [pattern] immédiatement, en annulant toute vibration en cours.
  ///
  /// Lève [InvalidVibrationPatternException] si [pattern] n'est pas valide,
  /// [HapticUnsupportedException] si l'appareil n'a pas de vibreur.
  Future<void> playPattern(VibrationPattern pattern) async {
    _validator.validate(pattern);

    final hasVibrator = await _executor.hasVibrator();
    if (!hasVibrator) {
      throw HapticUnsupportedException(
        'Cet appareil ne dispose d\'aucun vibreur',
      );
    }

    await _executor.cancel();
    await _executor.vibrate(_toNativeTimings(pattern));
  }

  /// Arrête toute vibration en cours.
  Future<void> stop() => _executor.cancel();

  /// Convertit un [VibrationPattern] vers le format attendu par Android :
  /// un tableau alterné [délai_initial, vibre, pause, vibre, pause, ...].
  /// IZAHAY ne différant jamais la première impulsion, le délai initial est
  /// toujours 0. Chaque impulsion ajoute systématiquement ses deux valeurs
  /// (même une pause de 0ms) pour que l'alternance vibre/pause reste
  /// correcte : omettre une pause nulle décalerait la parité du tableau et
  /// ferait interpréter la vibration suivante comme une pause.
  List<int> _toNativeTimings(VibrationPattern pattern) {
    final timings = <int>[0];
    for (final pulse in pattern.pulses) {
      timings.add(pulse.vibrate.inMilliseconds);
      timings.add(pulse.pauseAfter.inMilliseconds);
    }
    return timings;
  }
}
```

- [ ] **Step 5: Lancer le test et vérifier qu'il passe**

Run: `cd app && flutter test test/haptics/haptic_engine_test.dart`
Expected: PASS (8 tests)

- [ ] **Step 6: Commit**

```bash
git add app/lib/haptics/haptic_engine.dart app/test/haptics/fake_vibration_executor.dart app/test/haptics/haptic_engine_test.dart
git commit -m "feat: add HapticEngine core (validate, execute, stop, categories)"
```

---

## Task 7: HapticEngine — politique de concurrence

Ajoute la protection "la dernière demande gagne" : si un appel `playPattern` plus récent est déclenché pendant qu'un appel précédent attend encore son annulation, le précédent abandonne sans vibrer.

**Files:**
- Modify: `app/lib/haptics/haptic_engine.dart`
- Modify: `app/test/haptics/haptic_engine_test.dart`

**Interfaces:**
- Consumes: `FakeVibrationExecutor.cancelDelay` (Task 6, déjà présent pour ce scénario)
- Produces: le comportement de concurrence de `HapticEngine.playPattern` devient définitif pour les tâches suivantes (Task 9).

- [ ] **Step 1: Ajouter le test qui échoue**

Ajouter ce test à la fin de `main()` dans `app/test/haptics/haptic_engine_test.dart` :

```dart
  test('un appel plus récent annule le précédent avant qu\'il ne vibre',
      () async {
    executor.cancelDelay = const Duration(milliseconds: 50);
    const patternA = VibrationPattern(
      id: 'A',
      pulses: [VibrationPulse(vibrate: Duration(milliseconds: 100))],
    );
    const patternB = VibrationPattern(
      id: 'B',
      pulses: [VibrationPulse(vibrate: Duration(milliseconds: 200))],
    );

    final first = engine.playPattern(patternA);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    executor.cancelDelay = Duration.zero;
    final second = engine.playPattern(patternB);

    await Future.wait([first, second]);

    expect(executor.vibrateCalls, [
      [0, 200, 0],
    ]);
  });
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `cd app && flutter test test/haptics/haptic_engine_test.dart --name "un appel plus récent"`
Expected: FAIL — `executor.vibrateCalls` contient les deux motifs (A et B), ou uniquement A, au lieu de B seul — sans jeton, rien n'empêche le premier appel de vibrer après son `cancel()` tardif.

- [ ] **Step 3: Ajouter la protection par jeton dans HapticEngine**

Remplacer le corps de `playPattern` dans `app/lib/haptics/haptic_engine.dart` :

```dart
  int _requestToken = 0;

  Future<void> playPattern(VibrationPattern pattern) async {
    _validator.validate(pattern);

    final hasVibrator = await _executor.hasVibrator();
    if (!hasVibrator) {
      throw HapticUnsupportedException(
        'Cet appareil ne dispose d\'aucun vibreur',
      );
    }

    // Chaque appel obtient un jeton unique juste avant d'annuler. Si un
    // appel plus récent a déjà incrémenté ce jeton pendant notre attente de
    // cancel(), on abandonne : seul le dernier motif demandé doit vibrer.
    final myToken = ++_requestToken;
    await _executor.cancel();
    if (myToken != _requestToken) return;

    await _executor.vibrate(_toNativeTimings(pattern));
  }
```

(Ajouter le champ `int _requestToken = 0;` comme membre de la classe, juste après les champs `_executor`/`_registry`/`_validator`.)

- [ ] **Step 4: Lancer tous les tests du fichier et vérifier qu'ils passent**

Run: `cd app && flutter test test/haptics/haptic_engine_test.dart`
Expected: PASS (9 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/haptics/haptic_engine.dart app/test/haptics/haptic_engine_test.dart
git commit -m "feat: make HapticEngine cancel stale concurrent vibration requests"
```

---

## Task 8: Pont natif Android (Kotlin)

Traduit les appels du `MethodChannel` `"mg.izahay.izahay/haptics"` en appels réels à l'API Android de vibration, avec repli pour les versions d'Android antérieures à l'API 26. Aucun test automatisé possible ici (code de plateforme) — vérification manuelle en Task 9/10.

**Files:**
- Create: `app/android/app/src/main/kotlin/mg/izahay/izahay/HapticsChannelHandler.kt`
- Modify: `app/android/app/src/main/kotlin/mg/izahay/izahay/MainActivity.kt`
- Modify: `app/android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: canal `"mg.izahay.izahay/haptics"`, méthodes `"hasVibrator"`, `"vibrate"` (argument `"timings": List<Int>`), `"cancel"` — déjà appelées côté Dart par `MethodChannelVibrationExecutor` (Task 5).
- Produces: rien de consommé par une tâche Dart ultérieure ; ferme la boucle Dart → natif.

- [ ] **Step 1: Créer le gestionnaire du canal**

```kotlin
package mg.izahay.izahay

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Pont entre le MethodChannel Flutter "mg.izahay.izahay/haptics" et l'API
 * de vibration d'Android.
 *
 * Expose trois méthodes au canal :
 * - "hasVibrator" : indique si l'appareil a un vibreur.
 * - "vibrate" : déclenche un motif décrit par l'argument "timings", un
 *   tableau alterné [délai, vibre, pause, vibre, pause, ...] en millisecondes.
 * - "cancel" : arrête toute vibration en cours.
 */
class HapticsChannelHandler(context: Context) : MethodChannel.MethodCallHandler {

    private val vibrator: Vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val manager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
        manager.defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasVibrator" -> result.success(vibrator.hasVibrator())
            "vibrate" -> {
                val timings = call.argument<List<Int>>("timings")
                if (timings == null) {
                    result.error(
                        "INVALID_ARGUMENT",
                        "L'argument \"timings\" est requis pour \"vibrate\"",
                        null,
                    )
                    return
                }
                vibrate(timings.map { it.toLong() }.toLongArray())
                result.success(null)
            }
            "cancel" -> {
                vibrator.cancel()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun vibrate(timings: LongArray) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // -1 : pas de répétition, le motif est joué une seule fois.
            vibrator.vibrate(VibrationEffect.createWaveform(timings, -1))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(timings, -1)
        }
    }
}
```

- [ ] **Step 2: Brancher le canal dans MainActivity**

Remplacer le contenu de `app/android/app/src/main/kotlin/mg/izahay/izahay/MainActivity.kt` :

```kotlin
package mg.izahay.izahay

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val hapticsChannelName = "mg.izahay.izahay/haptics"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            hapticsChannelName,
        ).setMethodCallHandler(HapticsChannelHandler(applicationContext))
    }
}
```

- [ ] **Step 3: Ajouter la permission VIBRATE**

Dans `app/android/app/src/main/AndroidManifest.xml`, ajouter la ligne suivante juste après la balise ouvrante `<manifest ...>` et avant `<application`  :

```xml
    <uses-permission android:name="android.permission.VIBRATE"/>
```

- [ ] **Step 4: Vérifier que le projet Android compile**

Run (nécessite Docker Desktop démarré, voir `README.md` à la racine du dépôt) :
```bash
docker compose run --rm android
```
Expected: build réussi, `app/build/app/outputs/flutter-apk/app-debug.apk` généré, aucune erreur Kotlin dans les logs.

Si un toolchain Flutter/Android local est disponible à la place de Docker :
```bash
cd app && flutter build apk --debug
```

- [ ] **Step 5: Commit**

```bash
git add app/android/app/src/main/kotlin/mg/izahay/izahay/HapticsChannelHandler.kt app/android/app/src/main/kotlin/mg/izahay/izahay/MainActivity.kt app/android/app/src/main/AndroidManifest.xml
git commit -m "feat: bridge the haptics MethodChannel to Android's Vibrator API"
```

---

## Task 9: Écran de debug manuel (point d'entrée séparé)

Point d'entrée Dart indépendant pour déclencher manuellement les motifs sans reconnaissance sonore, sans toucher à `lib/main.dart`. Testé avec `FakeVibrationExecutor` (aucun appareil requis pour les tests automatisés — la vérification sensorielle réelle est couverte par la Task 10).

**Files:**
- Create: `app/lib/haptics_debug_main.dart`
- Test: `app/test/haptics/haptics_debug_screen_test.dart`

**Interfaces:**
- Consumes: `HapticEngine`, `MethodChannelVibrationExecutor` (Task 5/6), `FakeVibrationExecutor` (Task 6), les trois exceptions (Task 3)
- Produces: `HapticsDebugApp({required HapticEngine engine})`, `HapticsDebugScreen({required HapticEngine engine})` — utilisables tels quels via `flutter run -t lib/haptics_debug_main.dart`.

- [ ] **Step 1: Écrire le test qui échoue**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/haptics/haptic_engine.dart';
import 'package:izahay/haptics_debug_main.dart';

import 'fake_vibration_executor.dart';

void main() {
  testWidgets('tapper sur un bouton de motif déclenche la vibration '
      'correspondante', (tester) async {
    final executor = FakeVibrationExecutor();
    final engine = HapticEngine(executor: executor);

    await tester.pumpWidget(HapticsDebugApp(engine: engine));
    await tester.tap(find.text('Tester "sonnette"'));
    await tester.pumpAndSettle();

    expect(executor.vibrateCalls, isNotEmpty);
    expect(find.textContaining('sonnette'), findsWidgets);
  });

  testWidgets('le bouton Arrêter appelle stop sur le moteur', (tester) async {
    final executor = FakeVibrationExecutor();
    final engine = HapticEngine(executor: executor);

    await tester.pumpWidget(HapticsDebugApp(engine: engine));
    await tester.tap(find.text('Arrêter'));
    await tester.pumpAndSettle();

    expect(executor.callLog, contains('cancel'));
  });

  testWidgets('un appareil sans vibreur affiche un message clair',
      (tester) async {
    final executor = FakeVibrationExecutor()..hasVibratorResult = false;
    final engine = HapticEngine(executor: executor);

    await tester.pumpWidget(HapticsDebugApp(engine: engine));
    await tester.tap(find.text('Tester "aboiement"'));
    await tester.pumpAndSettle();

    expect(find.text('Appareil sans vibreur'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `cd app && flutter test test/haptics/haptics_debug_screen_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:izahay/haptics_debug_main.dart'`

- [ ] **Step 3: Implémenter l'écran de debug**

```dart
import 'package:flutter/material.dart';

import 'haptics/haptic_engine.dart';
import 'haptics/haptic_exceptions.dart';
import 'haptics/vibration_executor.dart';

/// Point d'entrée séparé pour tester le moteur de vibrations manuellement,
/// sans dépendre de la reconnaissance sonore ni de l'application principale.
///
/// Lancer avec : flutter run -t lib/haptics_debug_main.dart
void main() {
  runApp(HapticsDebugApp(
    engine: HapticEngine(executor: const MethodChannelVibrationExecutor()),
  ));
}

class HapticsDebugApp extends StatelessWidget {
  final HapticEngine engine;

  const HapticsDebugApp({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IZAHAY — Test moteur haptique',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: HapticsDebugScreen(engine: engine),
    );
  }
}

class HapticsDebugScreen extends StatefulWidget {
  final HapticEngine engine;

  const HapticsDebugScreen({super.key, required this.engine});

  @override
  State<HapticsDebugScreen> createState() => _HapticsDebugScreenState();
}

class _HapticsDebugScreenState extends State<HapticsDebugScreen> {
  static const _categories = ['sonnette', 'aboiement'];

  String _status = '';

  Future<void> _play(String category) async {
    try {
      await widget.engine.playForCategory(category);
      setState(() => _status = 'Motif "$category" déclenché');
    } on HapticUnsupportedException {
      setState(() => _status = 'Appareil sans vibreur');
    } on InvalidVibrationPatternException catch (e) {
      setState(() => _status = 'Motif invalide : ${e.message}');
    } on HapticPlatformException catch (e) {
      setState(() => _status = 'Erreur native : ${e.message}');
    }
  }

  Future<void> _stop() async {
    await widget.engine.stop();
    setState(() => _status = 'Vibration arrêtée');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test moteur haptique')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final category in _categories)
              Padding(
                padding: const EdgeInsets.all(8),
                child: FilledButton(
                  onPressed: () => _play(category),
                  child: Text('Tester "$category"'),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: OutlinedButton(
                onPressed: _stop,
                child: const Text('Arrêter'),
              ),
            ),
            const SizedBox(height: 16),
            Text(_status),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `cd app && flutter test test/haptics/haptics_debug_screen_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/haptics_debug_main.dart app/test/haptics/haptics_debug_screen_test.dart
git commit -m "feat: add standalone debug entrypoint for manual haptics testing"
```

---

## Task 10: Test d'intégration sur appareil physique

Ajoute `integration_test` (package SDK Flutter) et les scénarios qui nécessitent réellement un appareil Android : ils ne peuvent pas être vérifiés en émulateur ou en CI (le moteur haptique n'est généralement pas simulé).

**Files:**
- Modify: `app/pubspec.yaml`
- Create: `app/integration_test/haptics_manual_test.dart`

**Interfaces:**
- Consumes: `HapticEngine`, `MethodChannelVibrationExecutor` (Task 6/5), `VibrationPattern`/`VibrationPulse` (Task 2)
- Produces: rien — tâche terminale du plan.

- [ ] **Step 1: Ajouter la dépendance integration_test**

Dans `app/pubspec.yaml`, sous `dev_dependencies:` (après `flutter_lints: ^6.0.0`), ajouter :

```yaml
  integration_test:
    sdk: flutter
```

- [ ] **Step 2: Récupérer les dépendances**

Run: `cd app && flutter pub get`
Expected: succès, `integration_test` apparaît dans `pubspec.lock`.

- [ ] **Step 3: Écrire le test d'intégration**

```dart
// Ce test nécessite un appareil Android physique avec un vibreur : il ne
// peut pas être vérifié de façon fiable sur un émulateur (le moteur haptique
// n'est généralement pas simulé) ni en CI.
//
// Exécution : flutter test integration_test/haptics_manual_test.dart
//   (nécessite un appareil connecté, voir `flutter devices`)
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:izahay/haptics/haptic_engine.dart';
import 'package:izahay/haptics/models/vibration_pattern.dart';
import 'package:izahay/haptics/vibration_executor.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Moteur de vibrations sur appareil physique', () {
    late HapticEngine engine;

    setUp(() {
      engine = HapticEngine(
        executor: const MethodChannelVibrationExecutor(),
      );
    });

    testWidgets('l\'appareil de test est compatible', (tester) async {
      expect(await engine.isDeviceCompatible(), isTrue);
    });

    testWidgets('joue le motif "sonnette" sans erreur', (tester) async {
      await engine.playForCategory('sonnette');
    });

    testWidgets('joue un motif personnalisé avec plusieurs pauses sans '
        'erreur', (tester) async {
      const pattern = VibrationPattern(
        id: 'personnalise',
        pulses: [
          VibrationPulse(
            vibrate: Duration(milliseconds: 100),
            pauseAfter: Duration(milliseconds: 100),
          ),
          VibrationPulse(vibrate: Duration(milliseconds: 300)),
        ],
      );
      await engine.playPattern(pattern);
    });

    testWidgets('stop arrête une vibration en cours sans erreur',
        (tester) async {
      const longPattern = VibrationPattern(
        id: 'longue',
        pulses: [VibrationPulse(vibrate: Duration(seconds: 3))],
      );
      unawaited(engine.playPattern(longPattern));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await engine.stop();
    });
  });
}
```

- [ ] **Step 4: Exécuter sur un appareil physique connecté**

Run: `cd app && flutter test integration_test/haptics_manual_test.dart`
Expected (uniquement avec un téléphone Android connecté, débogage USB activé) : 4 tests PASS, vibrations effectivement ressenties pour "sonnette" et le motif personnalisé.
**Si aucun appareil n'est connecté, cette étape doit être marquée comme non vérifiée plutôt que passée en CI/émulateur.**

- [ ] **Step 5: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock app/integration_test/haptics_manual_test.dart
git commit -m "test: add physical-device integration tests for the haptic engine"
```
