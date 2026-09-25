# Moteur de vibrations IZAHAY — design

Date: 2026-09-25
Auteur: Personne 3 (moteur de vibrations, événements, Firebase, historique, simulation)
Statut: approuvé pour implémentation

## Contexte

IZAHAY est une application Flutter (projet `app/`, package Android `mg.izahay.izahay`)
destinée aux personnes sourdes ou malentendantes : elle reconnaît des sons de
l'environnement et les traduit en vibrations. L'équipe compte trois
développeurs :

- Personne 1 : IA / reconnaissance sonore.
- Personne 2 : application mobile / interface utilisateur.
- Personne 3 (ce module) : moteur de vibrations, traitement des événements,
  Firebase, historique, simulation.

Ce document couvre uniquement le premier module de la personne 3 : le
**moteur de vibrations**. Il doit être utilisable et testable de façon
totalement indépendante de l'IA, de Firebase et des écrans applicatifs.

État du projet au moment de l'écriture : starter Flutter minimal
(`lib/main.dart` contient un seul `TestScreen` de smoke-test), aucune
dépendance de vibration, aucune permission Android déclarée, aucun module de
vibration existant.

## Objectifs

Un moteur haptique Android qui permet de :

1. Déclencher une vibration simple.
2. Déclencher une séquence de vibrations (motif).
3. Définir la durée de chaque vibration et les pauses entre elles.
4. Associer un motif à une catégorie sonore (catégories fournies dynamiquement
   par le module IA — aucune liste figée).
5. Recevoir un motif personnalisé défini par l'utilisateur (interface de la
   personne 2).
6. Être testé manuellement, sans reconnaissance sonore ni réseau.
7. Arrêter une vibration en cours.
8. Rester cohérent si plusieurs déclenchements arrivent en concurrence.
9. Vérifier la compatibilité matérielle avant de vibrer.
10. Gérer proprement les erreurs et cas non supportés.

## Non-objectifs

- Pas d'écrans applicatifs définitifs (domaine de la personne 2).
- Pas de reconnaissance sonore (domaine de la personne 1).
- Pas d'intégration Firebase ni de persistance des motifs (futur module de
  la personne 3, hors périmètre ici).
- Pas de migration de framework : le projet reste Flutter/Dart, package
  Android `mg.izahay.izahay` inchangé.

## Décisions de conception (validées)

1. **Vibration native via platform channel Kotlin**, pas de nouvelle
   dépendance pub. Contrôle total sur `VibrationEffect`/`Vibrator`, conforme
   à la contrainte "pas de dépendance si le natif suffit".
2. **Écran de test manuel isolé**, point d'entrée Dart séparé
   (`lib/haptics_debug_main.dart`), ne touche à aucun fichier partagé avec
   les autres développeurs.
3. **`test/widget_test.dart` corrigé** : il référence actuellement une
   classe `MyApp` et une icône `Icons.add` qui n'existent plus dans
   `main.dart` (`IzahayApp`/`TestScreen`) — `flutter test` échouerait sans
   rapport avec ce module. Correction ciblée pour refléter le vrai widget.
4. **`integration_test`** (package du SDK Flutter, pas une dépendance
   pub.dev externe) ajouté aux `dev_dependencies` pour les tests
   nécessitant un appareil physique.

## Architecture

Séparation stricte des responsabilités, chaque unité utilisable et
compréhensible indépendamment :

```
lib/haptics/
├── models/
│   └── vibration_pattern.dart      # Définition d'un motif (données pures)
├── pattern_validator.dart          # Validation d'un motif
├── pattern_registry.dart           # Association catégorie -> motif
├── vibration_executor.dart         # Interface d'exécution + impl. MethodChannel + fake de test
├── haptic_exceptions.dart          # Exceptions typées du module
└── haptic_engine.dart              # Façade publique (point d'entrée unique)

lib/haptics_debug_main.dart         # Entrypoint Dart séparé pour test manuel

android/app/src/main/kotlin/mg/izahay/izahay/
└── HapticsChannelHandler.kt        # Pont MethodChannel -> Vibrator Android
```

### Modèle de données (`vibration_pattern.dart`)

Un motif est une liste d'impulsions, chacune avec sa durée de vibration et
sa pause après elle. Modèle Dart explicite plutôt que le tableau brut
alterné qu'Android attend en interne (`[délai, vibre, pause, vibre, ...]`),
pour rester lisible :

```dart
class VibrationPulse {
  final Duration vibrate;
  final Duration pauseAfter; // Duration.zero si aucune pause après
}

class VibrationPattern {
  final String id;                 // ex: "sonnette", utile pour logs/erreurs
  final List<VibrationPulse> pulses;
}
```

Pas de notion de répétition infinie (YAGNI — non demandée, ajoute de la
complexité de gestion d'arrêt sans bénéfice actuel).

### `pattern_validator.dart`

Valide un `VibrationPattern` avant tout usage (à l'enregistrement dans le
registre et avant exécution) :

- au moins une impulsion,
- chaque `vibrate` strictement positif,
- chaque `pauseAfter` non négatif.

Lève `InvalidVibrationPatternException` sinon.

### `pattern_registry.dart`

Table en mémoire `Map<String, VibrationPattern>` catégorie → motif.

- Seedée avec deux motifs d'exemple (`sonnette` : deux vibrations courtes,
  `aboiement` : trois vibrations longues) — à titre de démonstration/tests,
  pas une liste figée.
- `register(category, pattern)` : ajoute ou remplace (permet à l'IA
  d'introduire de nouvelles catégories, et à l'UI de la personne 2 de
  personnaliser un motif existant). Valide le motif avant stockage.
- `lookup(category)` : retourne le motif ou `null` si catégorie inconnue —
  laisse à l'appelant (`HapticEngine`) la décision (repli silencieux plutôt
  que crash, car les catégories réelles ne sont pas connues à l'avance).

### `vibration_executor.dart`

Interface abstraite découplant `HapticEngine` du canal natif, pour rendre
le moteur testable sans device :

```dart
abstract class VibrationExecutor {
  Future<bool> hasVibrator();
  Future<void> vibrate(List<int> nativeTimingsMs); // format Android natif
  Future<void> cancel();
}
```

- `MethodChannelVibrationExecutor` : implémentation réelle, canal
  `mg.izahay.izahay/haptics`, convertit les `PlatformException` en
  `HapticPlatformException`.
- `FakeVibrationExecutor` (dans `test/`) : enregistre les appels reçus pour
  les tests unitaires de `HapticEngine` (ordre d'appel, annulation avant
  relance, etc.) sans dépendre d'Android.

### `haptic_engine.dart` — façade publique

Seul point d'entrée que les autres modules doivent appeler :

```dart
class HapticEngine {
  Future<void> playPattern(VibrationPattern pattern);
  Future<void> playForCategory(String category);
  void registerPattern(String category, VibrationPattern pattern);
  Future<void> stop();
  Future<bool> isDeviceCompatible();
}
```

**Politique de concurrence** (exigence n°9) : "la dernière demande gagne".
Chaque `playPattern()`/`playForCategory()` :

1. valide le motif (`PatternValidator`),
2. annule toute vibration en cours (`executor.cancel()`),
3. incrémente un jeton interne `_requestToken`,
4. démarre la nouvelle vibration en capturant le jeton courant,
5. si un jeton plus récent a été émis entre-temps (nouvel appel concurrent),
   le résultat de l'appel obsolète est ignoré silencieusement.

Pas de file d'attente : cohérent avec un système d'alerte temps réel où le
son le plus récent doit primer sur le précédent.

**Compatibilité** : `isDeviceCompatible()` interroge
`executor.hasVibrator()`. `playPattern`/`playForCategory` vérifient la
compatibilité avant d'exécuter et lèvent `HapticUnsupportedException` si
absente, plutôt que d'échouer silencieusement.

### Exceptions (`haptic_exceptions.dart`)

- `InvalidVibrationPatternException` — motif mal formé (détectée en Dart
  pur, avant tout appel natif).
- `HapticUnsupportedException` — appareil sans vibreur.
- `HapticPlatformException` — erreur native inattendue, encapsule la cause
  d'origine pour le débogage.

Aucune exception générique non typée ne doit remonter aux appelants du
moteur.

### Côté natif — `HapticsChannelHandler.kt`

Nouveau fichier, instancié et branché sur le `MethodChannel` dans
`MainActivity.configureFlutterEngine` (seule modification de
`MainActivity.kt`).

- `hasVibrator` → `Vibrator.hasVibrator()` (via `VibratorManager` sur
  API 31+, `Vibrator` directement avant).
- `vibrate(timings: LongArray)` → `VibrationEffect.createWaveform(timings, -1)`
  sur API 26+ ; repli sur l'API dépréciée `Vibrator.vibrate(LongArray, -1)`
  pour les versions antérieures. `-1` = pas de répétition (cohérent avec
  l'absence de boucle infinie décidée plus haut).
- `cancel` → `Vibrator.cancel()`.

Format natif : tableau alterné `[délai_initial, vibre, pause, vibre, pause, ...]`
— la conversion `VibrationPattern` → `List<int>` est une fonction pure
côté Dart (`haptic_engine.dart` ou un fichier dédié), testée
unitairement, avec un commentaire expliquant explicitement cette
convention Android (logique non évidente à la lecture).

### Manifest Android

Ajout de `<uses-permission android:name="android.permission.VIBRATE"/>`
dans `android/app/src/main/AndroidManifest.xml` — permission normale, pas
de popup runtime à gérer.

## Fichiers créés

- `app/lib/haptics/models/vibration_pattern.dart`
- `app/lib/haptics/pattern_validator.dart`
- `app/lib/haptics/pattern_registry.dart`
- `app/lib/haptics/vibration_executor.dart`
- `app/lib/haptics/haptic_exceptions.dart`
- `app/lib/haptics/haptic_engine.dart`
- `app/lib/haptics_debug_main.dart`
- `app/android/app/src/main/kotlin/mg/izahay/izahay/HapticsChannelHandler.kt`
- `app/test/haptics/pattern_validator_test.dart`
- `app/test/haptics/pattern_registry_test.dart`
- `app/test/haptics/haptic_engine_test.dart`
- `app/test/haptics/fake_vibration_executor.dart`
- `app/integration_test/haptics_manual_test.dart` (nécessite un appareil
  physique — clairement indiqué dans le fichier et dans la livraison)

## Fichiers modifiés

- `app/android/app/src/main/AndroidManifest.xml` — ajout de la permission
  `VIBRATE`.
- `app/android/app/src/main/kotlin/mg/izahay/izahay/MainActivity.kt` —
  enregistrement du `MethodChannel`.
- `app/test/widget_test.dart` — correction pour refléter `IzahayApp`/
  `TestScreen` (le test référence actuellement une classe et une icône qui
  n'existent plus).
- `app/pubspec.yaml` — ajout de `integration_test` (SDK Flutter) en
  `dev_dependency`.

`app/lib/main.dart` n'est pas modifié.

## Stratégie de tests

**Tests unitaires purs (`flutter test`, aucun device requis)** :

- `pattern_validator_test.dart` : motif valide accepté ; liste vide,
  durée nulle/négative rejetées.
- `pattern_registry_test.dart` : enregistrement, remplacement, lookup
  catégorie inconnue (retourne `null`).
- `haptic_engine_test.dart` (avec `FakeVibrationExecutor`) : vibration
  simple, motif avec plusieurs pauses (conversion vers le tableau natif
  vérifiée), `stop()` appelle bien `cancel()`, deux appels concurrents
  rapprochés → le premier est annulé avant que le second ne s'exécute,
  motif invalide rejeté avant tout appel à l'executor, appareil
  incompatible → `HapticUnsupportedException` sans appel à `vibrate`.

**Tests nécessitant un appareil physique Android** (clairement marqués,
non exécutables en CI/émulateur de façon fiable) :

- `integration_test/haptics_manual_test.dart` : vibration réellement
  ressentie pour un motif simple et un motif personnalisé, comportement de
  `stop()` en cours de séquence.
- Usage de `lib/haptics_debug_main.dart` (`flutter run -t lib/haptics_debug_main.dart`)
  pour déclenchement manuel exploratoire sans IA ni réseau.

## Exemple d'utilisation (autres modules)

```dart
final engine = HapticEngine(executor: MethodChannelVibrationExecutor());

// Motif prédéfini par catégorie (fournie par le module IA)
await engine.playForCategory('sonnette');

// Motif personnalisé (depuis l'UI de la personne 2)
engine.registerPattern('alarme', VibrationPattern(
  id: 'alarme',
  pulses: [
    VibrationPulse(vibrate: Duration(milliseconds: 150), pauseAfter: Duration(milliseconds: 100)),
    VibrationPulse(vibrate: Duration(milliseconds: 400), pauseAfter: Duration.zero),
  ],
));
await engine.playForCategory('alarme');

// Arrêt manuel
await engine.stop();
```

## Limites matérielles connues

- `VibrationEffect.createWaveform` (API 26+) est utilisé quand disponible ;
  repli sur l'API dépréciée pour les appareils plus anciens — le
  comportement exact des motifs très courts (< ~20ms) dépend du moteur
  haptique du téléphone et peut être arrondi par le système.
- Certains émulateurs Android ne simulent pas de moteur de vibration
  physique : les appels natifs peuvent réussir sans retour sensoriel
  perceptible — la vérification "ressentie" nécessite un appareil physique.
- `Vibrator.hasVibrator()` peut retourner `true` sur des appareils avec un
  vibreur très faible ; le moteur ne juge pas de la qualité perçue,
  seulement de la présence matérielle.
