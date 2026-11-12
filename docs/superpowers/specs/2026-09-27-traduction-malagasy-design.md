# Système de traduction Malagasy / Français — design

Date : 2026-09-27
Auteur : Cindy
Statut : approuvé pour implémentation

## Contexte

L'application n'a aujourd'hui aucun système d'internationalisation : ni
`intl`/`flutter_localizations` dans `pubspec.yaml`, ni fichier `.arb`, ni
mécanisme de langue. Tous les textes affichés (labels, titres, messages
d'erreur, textes du tutoriel, libellés d'enums) sont des littéraux
français en dur, répartis dans une quinzaine d'écrans/widgets de
production.

Demande : que l'application soit utilisable nativement en malagasy, avec
un moyen simple de repasser en français.

## Décisions validées avec l'auteur

1. **Langue par défaut : malagasy.** Pas de détection automatique de la
   langue du téléphone — l'app démarre toujours en malagasy.
2. **Bascule manuelle vers le français via une icône présente sur toutes
   les pages** (haut d'écran). Un tap = bascule directe malagasy ⇄
   français (2 langues seulement, pas de menu déroulant).
3. **Choix persisté** sur l'appareil (`shared_preferences`, déjà une
   dépendance du projet) : la langue choisie survit au redémarrage de
   l'app.
4. **Traductions malagasy rédigées par Claude** dans cette itération (pas
   fournies par un locuteur natif) — à faire relire/corriger par un
   locuteur natif avant mise en production. Ce point est signalé dans le
   code (commentaire sur les fichiers de traduction) et dans le rapport de
   fin d'implémentation.
5. **Les écrans/points d'entrée de debug ne sont pas traduits** :
   `detection_test_screen.dart`, `microphone_test_screen.dart`,
   `preprocessing_test_screen.dart`, `yamnet_test_screen.dart`,
   `haptics_debug_main.dart`, `history_debug_main.dart`,
   `simulation_debug_main.dart`. Ce sont des écrans internes de
   développement, jamais vus par l'utilisateur final.
6. **Solution maison (pas `flutter_localizations` + ARB/gen-l10n
   officiel).** Avec une bascule 100% manuelle et 2 langues fixes, l'intérêt
   principal du système officiel (résolution automatique de la locale OS,
   pluriels/genres) ne s'applique pas ici, alors qu'il ajouterait une étape
   de génération de code (`flutter gen-l10n`) à retenir dans le workflow
   Docker. Une classe Dart directe est plus simple, sans dépendance
   supplémentaire, et cohérente avec le style du reste du repo
   (`ChangeNotifier` partout, pas de codegen).

## Objectifs

1. Tous les textes visibles des écrans de production (voir liste en
   Architecture) sont disponibles en malagasy et en français.
2. L'app démarre en malagasy par défaut.
3. Une icône, présente et identique sur chaque écran de production,
   permet de basculer instantanément entre les deux langues.
4. Le choix de langue est mémorisé entre deux lancements de l'app.
5. Les libellés des enums actuellement en dur (`UserRole.label`,
   `ColorVisionType.label`) sont traduits comme le reste.
6. Les 13 fichiers de test qui vérifient du texte français en dur
   (`find.text('...')`) continuent de passer.

## Non-objectifs

- Pas de détection de la langue du système (décision n°1).
- Pas de traduction des écrans/points d'entrée de debug (décision n°5).
- Pas de troisième langue ni d'infrastructure extensible à N langues
  (YAGNI) — deux instances fixes (`AppStrings.mg`, `AppStrings.fr`)
  suffisent ; si une 3e langue arrive un jour, l'architecture (une classe,
  une instance par langue) s'y prête sans réécriture.
- Pas de traduction des identifiants techniques stockés (ex. catégories
  Firestore `"aboiement"`, `"sonnette"`) — seuls leurs libellés d'affichage
  passent par le système de traduction.
- Pas de validation linguistique par un locuteur natif dans cette
  itération (décision n°4) — traduction de premier jet uniquement.

## Architecture

```
lib/localization/
├── app_language.dart        # enum AppLanguage { malagasy, francais }
├── app_strings.dart         # classe AppStrings (un champ final par texte), AppStrings.mg et AppStrings.fr
├── locale_controller.dart   # ChangeNotifier : langue courante, toggle(), persistance shared_preferences
└── locale_scope.dart        # InheritedNotifier exposant AppStrings.of(context) / LocaleController.of(context)

lib/widgets/
└── language_toggle_button.dart   # icône de bascule, appelle LocaleController.toggle()
```

### `AppLanguage` et `AppStrings`

```dart
enum AppLanguage { malagasy, francais }

class AppStrings {
  final String commencer;
  final String dernierSon;
  final String roleAccompagnateur;
  final String roleClient;
  // ... un champ par texte affiché de l'app (voir inventaire dans le plan)

  const AppStrings({required this.commencer, ...});

  static const mg = AppStrings(commencer: 'Manomboka', ...);
  static const fr = AppStrings(commencer: 'Commencer', ...);

  static AppStrings forLanguage(AppLanguage lang) =>
      switch (lang) { AppLanguage.malagasy => mg, AppLanguage.francais => fr };
}
```

Champs typés plutôt que clés `String` : une faute de frappe dans un nom de
champ casse la compilation, pas seulement l'affichage à l'exécution — même
philosophie que le reste du repo (pas d'erreur silencieuse détectable
seulement en testant manuellement chaque écran).

### `LocaleController`

```dart
class LocaleController extends ChangeNotifier {
  static const _prefsKey = 'app_language';

  AppLanguage _language = AppLanguage.malagasy; // défaut (décision n°1)
  AppLanguage get language => _language;
  AppStrings get strings => AppStrings.forLanguage(_language);

  Future<void> load(); // relit shared_preferences au démarrage, notifie si différent du défaut
  Future<void> toggle(); // malagasy <-> francais, persiste, notifie
}
```

Même pattern que `ProfileStore` déjà présent dans le repo (`ChangeNotifier`
+ persistance asynchrone + notification des écouteurs).

### Accès depuis les écrans (`locale_scope.dart`)

```dart
class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({required LocaleController controller, required super.child})
      : super(notifier: controller);

  static AppStrings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocaleScope>()!.notifier!.strings;

  static LocaleController controllerOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocaleScope>()!.notifier!;
}
```

`LocaleScope` enveloppe l'app une fois dans `main.dart`, au-dessus du
`MaterialApp` existant. Chaque écran remplace ses littéraux français par
`LocaleScope.of(context).xxx`, et se reconstruit automatiquement au
changement de langue (mécanisme standard `InheritedNotifier`, pas de
`setState` manuel à ajouter).

### `LanguageToggleButton`

Icône simple (texte "MG"/"FR" affichant la langue vers laquelle basculer —
pas de drapeau, pour éviter une dépendance à des assets graphiques)
posée en `Positioned(top:,
right:, ...)` dans le `Stack` que chaque écran de production a déjà (à
côté du `WaveDecor` déjà présent partout) :

```dart
Positioned(
  top: 12,
  right: 12,
  child: LanguageToggleButton(controller: LocaleScope.controllerOf(context)),
),
```

Ajoutée aux `Stack` de : `listening_screen.dart`, `settings_screen.dart`,
`role_selection_screen.dart`, `backup_screen.dart`,
`vibrations_screen.dart`, `vibration_config_screen.dart`,
`vision_problem_screen.dart`, `associations_screen.dart`.

### Écrans et fichiers migrés (textes en dur → `AppStrings`)

- `lib/screens/listening_screen.dart`
- `lib/screens/settings_screen.dart`
- `lib/screens/role_selection_screen.dart`
- `lib/screens/backup_screen.dart` (y compris les messages de
  `_message(ProfileSyncResult)`)
- `lib/screens/vibrations_screen.dart`
- `lib/screens/vibration_config_screen.dart`
- `lib/screens/vision_problem_screen.dart`
- `lib/screens/associations_screen.dart`
- `lib/widgets/home_menu.dart`, `lib/widgets/next_button.dart`
- `lib/tutorial/coach_mark.dart`
- `lib/config/listening_tutorial_steps.dart`
- `lib/models/user_role.dart` (`UserRole.label` → paramétré par
  `AppStrings`)
- `lib/models/color_vision_type.dart` (`ColorVisionType.label` → idem)

Écrans/points d'entrée **non touchés** (décision n°5) :
`detection_test_screen.dart`, `microphone_test_screen.dart`,
`preprocessing_test_screen.dart`, `yamnet_test_screen.dart`,
`haptics_debug_main.dart`, `history_debug_main.dart`,
`simulation_debug_main.dart`.

### `main.dart`

```dart
final localeController = LocaleController();
await localeController.load();
runApp(LocaleScope(controller: localeController, child: const SensiaApp()));
```

## Stratégie de tests

**Tests unitaires nouveaux** (`test/localization/`) :
- `LocaleController` : langue par défaut `malagasy`, `toggle()` alterne et
  notifie ses écouteurs, persistance round-trip via `shared_preferences`
  (valeur relue après un nouveau `load()`).
- `AppStrings.forLanguage` retourne bien l'instance correspondante pour
  chaque valeur de `AppLanguage`.

**Tests existants (13 fichiers utilisant `find.text('...')`)** : mis à
jour pour comparer contre `AppStrings.fr.xxx` (ou envelopper le widget
testé dans un `LocaleScope` forcé sur `AppLanguage.francais`) plutôt que
des littéraux français — les fait tenir indépendamment d'un futur
changement de texte, dans les deux langues.

**Nouveaux tests de non-régression** : au moins un test par écran de
production vérifiant qu'il s'affiche bien en malagasy par défaut (ex.
`ListeningScreen` affiche `AppStrings.mg.commencer` sans configuration
explicite), et un test de bascule (`LanguageToggleButton` tapé → le texte
affiché change de langue) sur un écran représentatif.

## Points d'intégration

- **`ProfileStore`** : aucun changement — la langue est un réglage
  d'affichage local (persisté via `shared_preferences`), pas une donnée de
  profil synchronisée sur Firestore. Elle n'entre pas dans
  `UserProfile.settings` (qui reste dédié aux réglages de l'écran
  Réglages).
- **`TutorialController` / `coach_mark.dart` / `listening_tutorial_steps.dart`** :
  les étapes du tutoriel deviennent une fonction de `AppStrings` plutôt que
  des littéraux, pour rester cohérentes avec la langue courante si
  l'utilisateur bascule pendant le tutoriel.
- **`UserRole` / `ColorVisionType`** : leur `label` actuel (getter fixe)
  devient paramétré par `AppStrings` — tous leurs appelants (écrans de
  sélection) sont mis à jour en conséquence.
