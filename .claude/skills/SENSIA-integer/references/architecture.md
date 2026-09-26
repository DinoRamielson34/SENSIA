# Architecture SENSIA (app Flutter dans `app/`)

Relevé au 2026-09-26 ; revérifie avec un `Glob app/lib/**` si ça date, la structure évolue.

## Stack
- Flutter, Dart SDK ^3.12, Material 3 (`ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true)` dans `lib/main.dart`).
- Package nommé `izahay` (pubspec) ; l'app s'appelle SENSIA à l'écran.
- Dépendances : firebase_core/auth, cloud_firestore, record, permission_handler, tflite_flutter, flutter_foreground_task.
- Pas de gestionnaire d'état externe : `ChangeNotifier` + `ListenableBuilder`.
- Pas de routeur : écran d'accueil = `ListeningScreen` via `MaterialApp(home:)`.

## Dossiers de `app/lib/`
| Dossier | Rôle |
|---|---|
| `screens/` | Un fichier par écran, `<nom>_screen.dart`, classe `<Nom>Screen`. Écrans actuels : listening (principal), microphone/preprocessing/yamnet/detection `_test_screen` (écrans de debug). |
| `services/` | Logique métier/IO (`audio_capture_service`, `yamnet_service`, `sound_haptic_pipeline` = `ChangeNotifier` orchestrateur, etc.) |
| `models/` | Objets de données purs (`audio_frame`, `sound_detection_result`) |
| `config/` | Constantes/config (priorités des sons, patterns haptiques) |
| `haptics/` | Moteur de vibration (+ `models/`) |
| `history/` | Historique des événements (repository Firestore, exceptions, `models/`) |
| `sound_events/` | Traitement des événements sonores |
| `simulation/` | Simulateur d'événements |
| racine | `main.dart`, `firebase_options.dart`, `*_debug_main.dart` (points d'entrée de debug) |

Dossiers **absents** (à créer au premier besoin) : `widgets/`, `theme/`.

## Conventions observées
- Un écran = `StatefulWidget` qui reçoit ses dépendances par le constructeur avec un paramètre optionnel (`final SoundHapticPipeline? pipeline;`), construit un défaut dans `initState`, et ne `dispose()` que ce qu'il a créé lui-même.
- Rebuild via `ListenableBuilder(listenable: _pipeline, builder: …)`.
- Helpers visuels en méthodes privées `_statusCard(context)`, etc. → à extraire en widgets quand ça se répète.
- Couleurs via `Theme.of(context).colorScheme` (ex. `errorContainer` / `onErrorContainer`).
- Textes et commentaires en français ; classes en PascalCase, fichiers en snake_case ; imports relatifs (`'../services/…'`).
- Tests dans `app/test/` (widget tests) et `app/integration_test/`.

## Vérification
```
cd app && dart format <fichiers> && flutter analyze && flutter test <fichier_test>
```
