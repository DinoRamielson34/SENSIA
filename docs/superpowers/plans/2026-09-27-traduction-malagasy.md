# Traduction Malagasy / Français — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** L'app SENSIA démarre en malagasy par défaut, avec une icône sur
chaque écran de production pour basculer instantanément vers le français ;
tous les textes de production (hors écrans de debug) sont disponibles dans
les deux langues.

**Architecture:** Une classe `AppStrings` (champs typés, deux instances
`mg`/`fr` constantes) exposée via un `LocaleController` (`ChangeNotifier`,
persisté via `shared_preferences`) et un `LocaleScope`
(`InheritedNotifier`). Chaque écran lit `LocaleScope.of(context)` au lieu
de littéraux français, et affiche un `LanguageToggleButton` commun.

**Tech Stack:** Flutter/Dart, `shared_preferences` (déjà une dépendance),
aucune nouvelle dépendance.

**Spec:** [docs/superpowers/specs/2026-09-27-traduction-malagasy-design.md](../specs/2026-09-27-traduction-malagasy-design.md)

## Global Constraints

- Langue par défaut de l'app réelle : `AppLanguage.malagasy` (spec décision 1).
- Bascule manuelle uniquement, un icône par écran de production, tap = bascule directe MG ⇄ FR (spec décision 2).
- Choix persisté via `shared_preferences` (spec décision 3).
- Écrans de debug/test (`*_test_screen.dart`, `*_debug_main.dart`) non traduits (spec décision 5).
- Pas de `flutter_localizations`/ARB/gen-l10n : classe Dart maison uniquement (spec décision 6).
- Aucun test existant ne doit changer de comportement observable sauf ceux qui pompent `IzahayApp` en entier (ceux-là sont explicitement mis à jour dans ce plan pour forcer le français).

## Review Focus

- **Écran de production pompé seul dans un test, sans `LocaleScope` ancêtre** (9 fichiers de test existants) — doit continuer d'afficher le texte français attendu sans aucune modification de ces tests. Couvert par le repli de `LocaleScope.of` vers `AppStrings.fr` (Task 3).
- **`IzahayApp` pompé sans réglage de langue explicite** (`widget_test.dart`) — ne doit jamais toucher le vrai plugin `shared_preferences` pendant un test (aucun test existant ne le fait aujourd'hui). Couvert par l'injection systématique de `MemoryLanguageStorage` (Task 5).
- **Persistance : redémarrage de l'app après un choix de langue** — la langue choisie doit être relue et appliquée, pas seulement mémorisée en mémoire vive. Couvert par le test de round-trip `LocaleController` (Task 2).
- **Catégorie de son inconnue** (identifiant absent des tables de libellés) — `SoundLabels.of`/`priorityTitle` doivent replier sur l'identifiant/le préfixe plutôt que planter ou afficher une chaîne vide. Couvert par un test dédié dans Task 7.
- **Tutoriel déjà actif pendant une bascule de langue** — ne doit pas planter ni changer de contenu au milieu d'une étape affichée. Couvert par le garde `if (_active) return;` de `updateSteps` et son test dans Task 13.

---

## Task 1 : `AppLanguage` et `AppStrings`

**Files:**
- Create: `app/lib/localization/app_language.dart`
- Create: `app/lib/localization/app_strings.dart`
- Test: `app/test/localization/app_strings_test.dart`

**Interfaces:**
- Produces: `enum AppLanguage { malagasy, francais }` avec `AppLanguage.code` (`'MG'`/`'FR'`) ; `class AppStrings` avec tous les champs de texte listés ci-dessous, `AppStrings.mg`, `AppStrings.fr` (instances `const`), `AppStrings.forLanguage(AppLanguage)`.

- [ ] **Step 1: Write the failing test**

`app/test/localization/app_strings_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/localization/app_language.dart';
import 'package:izahay/localization/app_strings.dart';

void main() {
  test('forLanguage retourne la bonne instance', () {
    expect(AppStrings.forLanguage(AppLanguage.malagasy), same(AppStrings.mg));
    expect(AppStrings.forLanguage(AppLanguage.francais), same(AppStrings.fr));
  });

  test('mg et fr renseignent tous les champs (aucune chaîne vide)', () {
    for (final strings in [AppStrings.mg, AppStrings.fr]) {
      expect(strings.roleSelectionTitle, isNotEmpty);
      expect(strings.tutorialStepStartTitle, isNotEmpty);
      expect(strings.listeningCategoryLabels['train'], isNotEmpty);
      expect(strings.soundCategoryLabels['dog_bark'], isNotEmpty);
      expect(strings.priorityTitles[5], isNotEmpty);
    }
  });

  test('les gabarits interpolés insèrent bien la valeur fournie', () {
    expect(AppStrings.fr.contactAssociation('Alpha'), 'Contacter Alpha');
    expect(AppStrings.fr.vibrationPatternAction('Train'), 'Vibration Train');
    expect(AppStrings.fr.vibrationSettingsAction('Train'), 'Réglages Train');
    expect(
      AppStrings.fr.stepAnnouncement(
        title: 'T',
        description: 'D',
        number: 1,
        total: 5,
      ),
      'T. D. Étape 1 sur 5.',
    );
  });

  test('AppLanguage.code', () {
    expect(AppLanguage.malagasy.code, 'MG');
    expect(AppLanguage.francais.code, 'FR');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run (depuis `app/`, dans le conteneur Docker du projet) : `flutter test test/localization/app_strings_test.dart`
Expected: FAIL — `package:izahay/localization/app_language.dart` et `app_strings.dart` n'existent pas encore.

- [ ] **Step 3: Write `app_language.dart`**

```dart
/// Langue d'affichage de l'app. Le code (`MG`/`FR`) sert d'étiquette
/// courte, indépendante de la langue, pour l'icône de bascule.
enum AppLanguage {
  malagasy('MG'),
  francais('FR');

  final String code;
  const AppLanguage(this.code);
}
```

- [ ] **Step 4: Write `app_strings.dart`**

```dart
import 'app_language.dart';

/// Tous les textes affichés par l'app, en malagasy ([mg]) et en français
/// ([fr]). Traductions malagasy rédigées par Claude (pas par un locuteur
/// natif) : premier jet à faire relire avant mise en production — voir
/// docs/superpowers/specs/2026-09-27-traduction-malagasy-design.md,
/// décision n°4.
class AppStrings {
  // Sélection du rôle
  final String roleSelectionTitle;
  final String roleAccompagnateur;
  final String roleClient;

  // Trouble de la vision des couleurs
  final String visionProblemTitle;
  final String back;
  final String visionProtanopie;
  final String visionDeuteranopie;
  final String visionTritanopie;
  final String visionAchromatopsie;
  final String visionDaltonisme;

  // Boutons partagés / tutoriel
  final String nextButtonLabel;
  final String tutorialPrevious;
  final String tutorialNext;
  final String tutorialFinish;
  final String tutorialSkip;
  final String tutorialStepPrefix;
  final String tutorialStepSeparator;

  // Étapes du tutoriel de l'écran principal
  final String tutorialStepStartTitle;
  final String tutorialStepStartDescription;
  final String tutorialStepLastSoundTitle;
  final String tutorialStepLastSoundDescription;
  final String tutorialStepMenuTitle;
  final String tutorialStepMenuDescription;
  final String tutorialStepYourSoundsTitle;
  final String tutorialStepYourSoundsDescription;
  final String tutorialStepVibrationsTitle;
  final String tutorialStepVibrationsDescription;
  final String tutorialStepAssociationsTitle;
  final String tutorialStepAssociationsDescription;
  final String tutorialStepBackupTitle;
  final String tutorialStepBackupDescription;

  // Écran Réglages
  final String settingsTitle;
  final String replayTutorial;

  // Écran Sauvegarde
  final String backupTitle;
  final String backupSaveButton;
  final String backupRestoreButton;
  final String backupIdUnavailableValue;
  final String backupSaved;
  final String backupRestored;
  final String backupNothingToRestore;
  final String backupUnavailable;
  final String backupAuthFailed;
  final String backupPermissionDenied;
  final String backupFailed;

  // Écran Vibrations (liste)
  final String vibrationsListTitle;
  final String vibrationPatternPrefix;
  final String vibrationSettingsPrefix;

  // Écran de configuration d'une vibration
  final String vibrationUnsupportedMessage;
  final String vibrationInvalidPatternMessage;
  final String addLongSegment;
  final String addShortSegment;
  final String clearPattern;
  final String tryVibration;
  final String validate;

  // Écran Associations
  final String associationsTitle;
  final String contactPrefix;

  // Écran principal (écoute)
  final String startListening;
  final String stopListening;
  final String noSound;

  /// Libellés des catégories de sons utilisés par `listening_screen.dart`
  /// (`_SoundCard`). Table séparée de [soundCategoryLabels] : les deux
  /// existaient déjà comme deux tables françaises légèrement différentes
  /// avant cette traduction (ex. "Alarme voiture" vs "Alarme de voiture") ;
  /// les unifier serait un refactor hors du périmètre de cette tâche.
  final Map<String, String> listeningCategoryLabels;

  /// Libellés utilisés par `config/sound_labels.dart` (Réglages, Vibrations).
  final Map<String, String> soundCategoryLabels;
  final Map<int, String> priorityTitles;
  final String priorityFallbackPrefix;

  // Menu « home »
  final String pillAssociation;
  final String pillHelp;
  final String pillSettings;
  final String pillBackup;
  final String centerAccueil;
  final String centerFermerMenu;

  /// Décrit, dans la langue courante, l'action de bascule vers l'AUTRE
  /// langue (ex. dans [fr] : "Passer en malagasy").
  final String switchLanguageAction;

  const AppStrings({
    required this.roleSelectionTitle,
    required this.roleAccompagnateur,
    required this.roleClient,
    required this.visionProblemTitle,
    required this.back,
    required this.visionProtanopie,
    required this.visionDeuteranopie,
    required this.visionTritanopie,
    required this.visionAchromatopsie,
    required this.visionDaltonisme,
    required this.nextButtonLabel,
    required this.tutorialPrevious,
    required this.tutorialNext,
    required this.tutorialFinish,
    required this.tutorialSkip,
    required this.tutorialStepPrefix,
    required this.tutorialStepSeparator,
    required this.tutorialStepStartTitle,
    required this.tutorialStepStartDescription,
    required this.tutorialStepLastSoundTitle,
    required this.tutorialStepLastSoundDescription,
    required this.tutorialStepMenuTitle,
    required this.tutorialStepMenuDescription,
    required this.tutorialStepYourSoundsTitle,
    required this.tutorialStepYourSoundsDescription,
    required this.tutorialStepVibrationsTitle,
    required this.tutorialStepVibrationsDescription,
    required this.tutorialStepAssociationsTitle,
    required this.tutorialStepAssociationsDescription,
    required this.tutorialStepBackupTitle,
    required this.tutorialStepBackupDescription,
    required this.settingsTitle,
    required this.replayTutorial,
    required this.backupTitle,
    required this.backupSaveButton,
    required this.backupRestoreButton,
    required this.backupIdUnavailableValue,
    required this.backupSaved,
    required this.backupRestored,
    required this.backupNothingToRestore,
    required this.backupUnavailable,
    required this.backupAuthFailed,
    required this.backupPermissionDenied,
    required this.backupFailed,
    required this.vibrationsListTitle,
    required this.vibrationPatternPrefix,
    required this.vibrationSettingsPrefix,
    required this.vibrationUnsupportedMessage,
    required this.vibrationInvalidPatternMessage,
    required this.addLongSegment,
    required this.addShortSegment,
    required this.clearPattern,
    required this.tryVibration,
    required this.validate,
    required this.associationsTitle,
    required this.contactPrefix,
    required this.startListening,
    required this.stopListening,
    required this.noSound,
    required this.listeningCategoryLabels,
    required this.soundCategoryLabels,
    required this.priorityTitles,
    required this.priorityFallbackPrefix,
    required this.pillAssociation,
    required this.pillHelp,
    required this.pillSettings,
    required this.pillBackup,
    required this.centerAccueil,
    required this.centerFermerMenu,
    required this.switchLanguageAction,
  });

  String contactAssociation(String name) => '$contactPrefix $name';

  String vibrationPatternAction(String soundLabel) =>
      '$vibrationPatternPrefix $soundLabel';

  String vibrationSettingsAction(String soundLabel) =>
      '$vibrationSettingsPrefix $soundLabel';

  String stepAnnouncement({
    required String title,
    required String description,
    required int number,
    required int total,
  }) => '$title. $description. $tutorialStepPrefix $number $tutorialStepSeparator $total.';

  static AppStrings forLanguage(AppLanguage language) => switch (language) {
    AppLanguage.malagasy => mg,
    AppLanguage.francais => fr,
  };

  static const _soundCategoriesListeningFr = <String, String>{
    'train': 'Train',
    'fire_alarm': 'Alarme incendie',
    'smoke_alarm': 'Détecteur de fumée',
    'car_horn': 'Klaxon',
    'emergency_siren': 'Sirène d\'urgence',
    'car_alarm': 'Alarme voiture',
    'baby_cry': 'Pleurs de bébé',
    'alarm': 'Alarme',
    'doorbell': 'Sonnette',
    'door_knock': 'Frappe à la porte',
    'telephone': 'Téléphone',
    'alarm_clock': 'Réveil',
    'dog_bark': 'Aboiement',
  };

  static const _soundCategoriesListeningMg = <String, String>{
    'train': 'Fiaran-dalamby',
    'fire_alarm': 'Alarma afo',
    'smoke_alarm': 'Mpitily setroka',
    'car_horn': 'Korintsan\'ny fiara',
    'emergency_siren': 'Sivan\'ny vonjy taitra',
    'car_alarm': 'Alarman\'ny fiara',
    'baby_cry': 'Fitomanian-jaza',
    'alarm': 'Alarma',
    'doorbell': 'Lakolosin\'ny varavarana',
    'door_knock': 'Fandonanana varavarana',
    'telephone': 'Telefaonina',
    'alarm_clock': 'Famantaranandro fanairana',
    'dog_bark': 'Fikaikain\'alika',
  };

  static const _soundCategoriesFr = <String, String>{
    'train': 'Train',
    'fire_alarm': 'Alarme incendie',
    'smoke_alarm': 'Détecteur de fumée',
    'car_horn': 'Klaxon',
    'emergency_siren': 'Sirène d\'urgence',
    'car_alarm': 'Alarme de voiture',
    'baby_cry': 'Pleurs de bébé',
    'alarm': 'Alarme',
    'doorbell': 'Sonnette',
    'door_knock': 'Coups à la porte',
    'telephone': 'Téléphone',
    'alarm_clock': 'Réveil',
    'dog_bark': 'Aboiement',
  };

  static const _soundCategoriesMg = <String, String>{
    'train': 'Fiaran-dalamby',
    'fire_alarm': 'Alarma afo',
    'smoke_alarm': 'Mpitily setroka',
    'car_horn': 'Korintsan\'ny fiara',
    'emergency_siren': 'Sivan\'ny vonjy taitra',
    'car_alarm': 'Alarman\'ny fiara',
    'baby_cry': 'Fitomanian-jaza',
    'alarm': 'Alarma',
    'doorbell': 'Lakolosin\'ny varavarana',
    'door_knock': 'Fandonanana varavarana',
    'telephone': 'Telefaonina',
    'alarm_clock': 'Famantaranandro fanairana',
    'dog_bark': 'Fikaikain\'alika',
  };

  static const _priorityTitlesFr = <int, String>{
    5: 'Danger immédiat',
    4: 'Alertes',
    3: 'Vigilance',
    2: 'Sons du quotidien',
    1: 'Autres sons',
  };

  static const _priorityTitlesMg = <int, String>{
    5: 'Loza eo no eo',
    4: 'Fampitandremana',
    3: 'Fitandremana',
    2: 'Feo andavanandro',
    1: 'Feo hafa',
  };

  static const mg = AppStrings(
    roleSelectionTitle: 'Ianao ve dia...',
    roleAccompagnateur: 'Mpanotrona',
    roleClient: 'Mpanjifa',
    visionProblemTitle: 'Inona no olana amin\'ny\nfahitana loko\nananao ?',
    back: 'Miverina',
    visionProtanopie: 'Protanopia',
    visionDeuteranopie: 'Deoteranopia',
    visionTritanopie: 'Tritanopia',
    visionAchromatopsie: 'Akromatopsia',
    visionDaltonisme: 'Daltonisma',
    nextButtonLabel: 'Manaraka',
    tutorialPrevious: 'Teo aloha',
    tutorialNext: 'Manaraka',
    tutorialFinish: 'Vita',
    tutorialSkip: 'Tsy hanao ny fampianarana',
    tutorialStepPrefix: 'Dingana',
    tutorialStepSeparator: 'amin\'ny',
    tutorialStepStartTitle: 'Manomboka',
    tutorialStepStartDescription:
        'Kasiho ity bokotra ity mba hanombohana ny fisavana feo.',
    tutorialStepLastSoundTitle: 'Feo farany',
    tutorialStepLastSoundDescription:
        'Miseho eto ny feo farany fantatra.',
    tutorialStepMenuTitle: 'Menu',
    tutorialStepMenuDescription:
        'Kasiho ity bokotra ity mba hanokafana ny menu.',
    tutorialStepYourSoundsTitle: 'Ny feo anao',
    tutorialStepYourSoundsDescription:
        'Safidio ireo feo tokony ho fantatry ny rindrankajy.',
    tutorialStepVibrationsTitle: 'Fihozongozonana',
    tutorialStepVibrationsDescription:
        'Safidio fihozongozonana samihafa ho an\'ny feo tsirairay.',
    tutorialStepAssociationsTitle: 'Fikambanana',
    tutorialStepAssociationsDescription:
        'Mitadiava fikambanana afaka manampy anao.',
    tutorialStepBackupTitle: 'Tahiry',
    tutorialStepBackupDescription: 'Tehirizo na alao indray ny fandrindranao.',
    settingsTitle: 'Fandrindrana ny feo',
    replayTutorial: 'Jereo indray ny fampianarana',
    backupTitle: 'Tehirizo ny angon-drakitrao ary alefaso',
    backupSaveButton: 'Tehirizo ny angon-drakitro',
    backupRestoreButton: 'Alao indray ny angon-drakitra',
    backupIdUnavailableValue: 'tsy misy',
    backupSaved: 'Voatahiry ny angon-drakitra.',
    backupRestored: 'Naverina ny angon-drakitra.',
    backupNothingToRestore: 'Tsy nisy tahiry hita.',
    backupUnavailable: 'Tsy azo atao ny fitahirizana (tsy misy Firebase).',
    backupAuthFailed:
        'Tsy nahomby ny fanamarinana. Alefaso ny fidirana tsy fantatra ao amin\'ny Firebase Console.',
    backupPermissionDenied: 'Nolavina ny fidirana. Jereo ny fitsipiky Firestore.',
    backupFailed: 'Tsy nahomby, andramo indray any aoriana.',
    vibrationsListTitle: 'Lisitry ny fihozongozonana',
    vibrationPatternPrefix: 'Fihozongozonana',
    vibrationSettingsPrefix: 'Fandrindrana',
    vibrationUnsupportedMessage: 'Tsy afaka mihozongozona ity fitaovana ity.',
    vibrationInvalidPatternMessage: 'Tsy mety ny lamin\'ny fihozongozonana.',
    addLongSegment: 'Ampio feo lava',
    addShortSegment: 'Ampio feo fohy',
    clearPattern: 'Fafao ny lamina',
    tryVibration: 'Andramo ny fihozongozonana',
    validate: 'Ekeo',
    associationsTitle: 'Mitadiava\nvondrona afaka\nmanampy anao.',
    contactPrefix: 'Mifandraisa amin\'i',
    startListening: 'Atomboy ny fihainoana',
    stopListening: 'Ajanony ny fihainoana',
    noSound: 'Tsy misy feo',
    listeningCategoryLabels: _soundCategoriesListeningMg,
    soundCategoryLabels: _soundCategoriesMg,
    priorityTitles: _priorityTitlesMg,
    priorityFallbackPrefix: 'Laharana',
    pillAssociation: 'Fikambanana',
    pillHelp: 'Fanampiana',
    pillSettings: 'Fandrindrana',
    pillBackup: 'Tahiry',
    centerAccueil: 'Fandraisana',
    centerFermerMenu: 'Hidio ny menu',
    switchLanguageAction: 'Miova amin\'ny teny frantsay',
  );

  static const fr = AppStrings(
    roleSelectionTitle: 'Êtes-vous...',
    roleAccompagnateur: 'Accompagnateur',
    roleClient: 'Client',
    visionProblemTitle: 'Quel trouble de la vision\ndes couleurs\nprésentez-vous ?',
    back: 'Retour',
    visionProtanopie: 'Protanopie',
    visionDeuteranopie: 'Deutéranopie',
    visionTritanopie: 'Tritanopie',
    visionAchromatopsie: 'Achromatopsie',
    visionDaltonisme: 'Daltonisme',
    nextButtonLabel: 'Suivants',
    tutorialPrevious: 'Précédent',
    tutorialNext: 'Suivant',
    tutorialFinish: 'Terminer',
    tutorialSkip: 'Passer le tutoriel',
    tutorialStepPrefix: 'Étape',
    tutorialStepSeparator: 'sur',
    tutorialStepStartTitle: 'Commencer',
    tutorialStepStartDescription:
        'Touchez ce bouton pour lancer la détection des sons.',
    tutorialStepLastSoundTitle: 'Dernier son',
    tutorialStepLastSoundDescription: 'Le dernier son reconnu apparaît ici.',
    tutorialStepMenuTitle: 'Menu',
    tutorialStepMenuDescription: 'Touchez ce bouton pour ouvrir le menu.',
    tutorialStepYourSoundsTitle: 'Vos sons',
    tutorialStepYourSoundsDescription:
        'Choisissez les sons que l\'application doit reconnaître.',
    tutorialStepVibrationsTitle: 'Vibrations',
    tutorialStepVibrationsDescription:
        'Choisissez une vibration différente pour chaque son.',
    tutorialStepAssociationsTitle: 'Associations',
    tutorialStepAssociationsDescription:
        'Trouvez des associations qui peuvent vous aider.',
    tutorialStepBackupTitle: 'Sauvegarde',
    tutorialStepBackupDescription: 'Sauvegardez ou retrouvez vos réglages.',
    settingsTitle: 'Parametres des sons',
    replayTutorial: 'Revoir le tutoriel',
    backupTitle: 'Sauvegardez vos donnees et exportez les',
    backupSaveButton: 'Sauvegarder mes donnees',
    backupRestoreButton: 'Restaurer les donnees',
    backupIdUnavailableValue: 'indisponible',
    backupSaved: 'Données sauvegardées.',
    backupRestored: 'Données restaurées.',
    backupNothingToRestore: 'Aucune sauvegarde trouvée.',
    backupUnavailable: 'Sauvegarde indisponible (pas de Firebase).',
    backupAuthFailed:
        'Authentification échouée. Activez l\'auth anonyme dans Firebase Console.',
    backupPermissionDenied: 'Accès refusé. Vérifiez les règles Firestore.',
    backupFailed: 'Échec, réessayez plus tard.',
    vibrationsListTitle: 'Liste des vibrations',
    vibrationPatternPrefix: 'Vibration',
    vibrationSettingsPrefix: 'Réglages',
    vibrationUnsupportedMessage: 'Cet appareil ne peut pas vibrer.',
    vibrationInvalidPatternMessage: 'Motif de vibration invalide.',
    addLongSegment: 'Ajouter un son long',
    addShortSegment: 'Ajouter un son court',
    clearPattern: 'Effacer le motif',
    tryVibration: 'Essayer la vibration',
    validate: 'Valider',
    associationsTitle: 'Trouvez\nquelles entités pour\nvous aider.',
    contactPrefix: 'Contacter',
    startListening: 'Démarrer l\'écoute',
    stopListening: 'Arrêter l\'écoute',
    noSound: 'Aucun son',
    listeningCategoryLabels: _soundCategoriesListeningFr,
    soundCategoryLabels: _soundCategoriesFr,
    priorityTitles: _priorityTitlesFr,
    priorityFallbackPrefix: 'Priorité',
    pillAssociation: 'Association',
    pillHelp: 'Help',
    pillSettings: 'Settings',
    pillBackup: 'Sauvegarde',
    centerAccueil: 'Accueil',
    centerFermerMenu: 'Fermer le menu',
    switchLanguageAction: 'Passer en malagasy',
  );
}
```

Note : `backupUnavailable` (fr) reprend le texte **actuel** du code source
(`'Sauvegarde indisponible (pas de Firebase).'`), qui diffère déjà du
texte attendu par `test/backup_screen_test.dart` (`'Sauvegarde
indisponible.'`) — une incohérence préexistante, non introduite par cette
tâche. Task 8 la traite explicitement.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/localization/app_strings_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/lib/localization/app_language.dart app/lib/localization/app_strings.dart app/test/localization/app_strings_test.dart
git commit -m "feat: add AppLanguage and AppStrings (mg/fr translations)"
```

---

## Task 2 : `LanguageStorage` et `LocaleController`

**Files:**
- Create: `app/lib/localization/language_storage.dart`
- Create: `app/lib/localization/locale_controller.dart`
- Test: `app/test/localization/locale_controller_test.dart`

**Interfaces:**
- Consumes: `AppLanguage`, `AppStrings.forLanguage` (Task 1).
- Produces: `abstract class LanguageStorage { Future<AppLanguage?> load(); Future<void> save(AppLanguage language); }`, `MemoryLanguageStorage`, `SharedPreferencesLanguageStorage` ; `class LocaleController extends ChangeNotifier` avec `AppLanguage get language`, `AppStrings get strings`, `Future<void> load()`, `Future<void> toggle()`.

- [ ] **Step 1: Write the failing test**

`app/test/localization/locale_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/localization/app_language.dart';
import 'package:izahay/localization/app_strings.dart';
import 'package:izahay/localization/language_storage.dart';
import 'package:izahay/localization/locale_controller.dart';

void main() {
  test('malagasy par défaut sans stockage', () {
    final controller = LocaleController(storage: MemoryLanguageStorage());
    expect(controller.language, AppLanguage.malagasy);
    expect(controller.strings, same(AppStrings.mg));
  });

  test('toggle alterne et notifie', () async {
    final controller = LocaleController(storage: MemoryLanguageStorage());
    var notified = 0;
    controller.addListener(() => notified++);

    await controller.toggle();
    expect(controller.language, AppLanguage.francais);
    expect(notified, 1);

    await controller.toggle();
    expect(controller.language, AppLanguage.malagasy);
    expect(notified, 2);
  });

  test('toggle persiste dans le stockage', () async {
    final storage = MemoryLanguageStorage();
    final controller = LocaleController(storage: storage);
    await controller.toggle();
    expect(await storage.load(), AppLanguage.francais);
  });

  test('load() applique une langue déjà persistée', () async {
    final storage = MemoryLanguageStorage(AppLanguage.francais);
    final controller = LocaleController(storage: storage);
    expect(controller.language, AppLanguage.malagasy); // avant load()

    var notified = false;
    controller.addListener(() => notified = true);
    await controller.load();

    expect(controller.language, AppLanguage.francais);
    expect(notified, isTrue);
  });

  test('load() ne notifie pas si la langue persistée est déjà la langue courante', () async {
    final controller = LocaleController(storage: MemoryLanguageStorage(AppLanguage.malagasy));
    var notified = false;
    controller.addListener(() => notified = true);
    await controller.load();
    expect(notified, isFalse);
  });

  test('SharedPreferencesLanguageStorage : round-trip', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = SharedPreferencesLanguageStorage();
    expect(await storage.load(), isNull);
    await storage.save(AppLanguage.francais);
    expect(await storage.load(), AppLanguage.francais);
  });
}
```

Ajouter l'import `package:shared_preferences/shared_preferences.dart` en
tête du fichier de test pour `SharedPreferences.setMockInitialValues`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/localization/locale_controller_test.dart`
Expected: FAIL — fichiers `language_storage.dart`/`locale_controller.dart` inexistants.

- [ ] **Step 3: Write `language_storage.dart`**

```dart
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';

/// Ce que l'app retient de la langue choisie entre deux lancements.
/// Même principe que `tutorial/tutorial_storage.dart`.
abstract class LanguageStorage {
  Future<AppLanguage?> load();
  Future<void> save(AppLanguage language);
}

/// Stockage en mémoire (tests, ou repli sans persistance).
class MemoryLanguageStorage implements LanguageStorage {
  AppLanguage? _language;

  MemoryLanguageStorage([this._language]);

  @override
  Future<AppLanguage?> load() async => _language;

  @override
  Future<void> save(AppLanguage language) async => _language = language;
}

/// Stockage local persistant (survit à la fermeture de l'app).
class SharedPreferencesLanguageStorage implements LanguageStorage {
  static const _key = 'app_language';

  @override
  Future<AppLanguage?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_key);
      return AppLanguage.values.asNameMap()[name];
    } on Exception {
      // Stockage illisible : l'app garde la langue par défaut du contrôleur.
      return null;
    }
  }

  @override
  Future<void> save(AppLanguage language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, language.name);
    } on Exception {
      // Sans persistance, la langue reste appliquée pour cette session.
    }
  }
}
```

- [ ] **Step 4: Write `locale_controller.dart`**

```dart
import 'package:flutter/foundation.dart';

import 'app_language.dart';
import 'app_strings.dart';
import 'language_storage.dart';

/// Langue courante de l'app, avec bascule et persistance. Même pattern que
/// `profile/profile_store.dart` et `tutorial/tutorial_controller.dart`.
class LocaleController extends ChangeNotifier {
  AppLanguage _language;
  final LanguageStorage _storage;

  LocaleController({
    AppLanguage initialLanguage = AppLanguage.malagasy,
    LanguageStorage? storage,
  }) : _language = initialLanguage,
       _storage = storage ?? SharedPreferencesLanguageStorage();

  AppLanguage get language => _language;
  AppStrings get strings => AppStrings.forLanguage(_language);

  /// Relit la langue persistée, si elle diffère de la langue courante.
  /// Appelée une fois au démarrage réel de l'app (voir `main.dart`).
  Future<void> load() async {
    final saved = await _storage.load();
    if (saved != null && saved != _language) {
      _language = saved;
      notifyListeners();
    }
  }

  /// Bascule malagasy ⇄ français et persiste le nouveau choix.
  Future<void> toggle() async {
    _language = _language == AppLanguage.malagasy
        ? AppLanguage.francais
        : AppLanguage.malagasy;
    notifyListeners();
    await _storage.save(_language);
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/localization/locale_controller_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/lib/localization/language_storage.dart app/lib/localization/locale_controller.dart app/test/localization/locale_controller_test.dart
git commit -m "feat: add LocaleController with persisted language toggle"
```

---

## Task 3 : `LocaleScope`

**Files:**
- Create: `app/lib/localization/locale_scope.dart`
- Test: `app/test/localization/locale_scope_test.dart`

**Interfaces:**
- Consumes: `LocaleController`, `AppStrings` (Tasks 1-2).
- Produces: `class LocaleScope extends InheritedNotifier<LocaleController>` avec `static AppStrings of(BuildContext)` (replie sur `AppStrings.fr` sans ancêtre) et `static LocaleController? controllerOf(BuildContext)`.

- [ ] **Step 1: Write the failing test**

`app/test/localization/locale_scope_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/localization/app_language.dart';
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
            Builder(builder: (c) => withoutScope = c),
            LocaleScope(
              controller: controller,
              child: Builder(builder: (c) => withScope = c),
            ),
          ],
        ),
      ),
    );
    expect(LocaleScope.controllerOf(withoutScope), isNull);
    expect(LocaleScope.controllerOf(withScope), same(controller));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/localization/locale_scope_test.dart`
Expected: FAIL — `locale_scope.dart` inexistant.

- [ ] **Step 3: Write `locale_scope.dart`**

```dart
import 'package:flutter/widgets.dart';

import 'app_strings.dart';
import 'locale_controller.dart';

/// Expose la langue courante à tout l'arbre des widgets. Placé une fois
/// au-dessus du `MaterialApp` par `IzahayApp` (voir Task 5).
class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({
    super.key,
    required LocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Traductions de la langue courante. Sans [LocaleScope] ancêtre (écran
  /// monté seul, par exemple dans un test), replie sur le français : les
  /// écrans restent affichables et testables sans configuration
  /// supplémentaire — voir la spec, section « Notes de modélisation ».
  static AppStrings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    return scope?.notifier?.strings ?? AppStrings.fr;
  }

  /// Contrôleur courant, ou `null` sans [LocaleScope] ancêtre.
  static LocaleController? controllerOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocaleScope>()?.notifier;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/localization/locale_scope_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/lib/localization/locale_scope.dart app/test/localization/locale_scope_test.dart
git commit -m "feat: add LocaleScope with French fallback for ancestor-less screens"
```

---

## Task 4 : `LanguageToggleButton`

**Files:**
- Create: `app/lib/widgets/language_toggle_button.dart`
- Test: `app/test/widgets/language_toggle_button_test.dart`

**Interfaces:**
- Consumes: `LocaleController` (Task 2).
- Produces: `class LanguageToggleButton extends StatelessWidget` avec `LanguageToggleButton({required LocaleController? controller})`.

- [ ] **Step 1: Write the failing test**

`app/test/widgets/language_toggle_button_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/language_toggle_button_test.dart`
Expected: FAIL — `language_toggle_button.dart` inexistant.

- [ ] **Step 3: Write `language_toggle_button.dart`**

```dart
import 'package:flutter/material.dart';

import '../localization/app_language.dart';
import '../localization/locale_controller.dart';
import '../theme/app_theme.dart';

/// Icône présente sur chaque écran de production : un tap bascule
/// instantanément malagasy ⇄ français. Affiche le CODE de la langue vers
/// laquelle le tap bascule (ex. "FR" tant que l'app est en malagasy).
///
/// Sans contrôleur (écran monté seul, par exemple dans un test qui ne
/// fournit pas de `LocaleScope`), ne rend rien : la bascule n'a de sens
/// que dans l'app réelle.
class LanguageToggleButton extends StatelessWidget {
  final LocaleController? controller;

  const LanguageToggleButton({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final next = controller.language == AppLanguage.malagasy
            ? AppLanguage.francais
            : AppLanguage.malagasy;
        return Semantics(
          button: true,
          label: controller.strings.switchLanguageAction,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: controller.toggle,
            child: Container(
              width: 40,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.hover,
                border: Border.all(color: AppColors.primary),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                next.code,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/language_toggle_button_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/lib/widgets/language_toggle_button.dart app/test/widgets/language_toggle_button_test.dart
git commit -m "feat: add LanguageToggleButton"
```

---

## Task 5 : Câblage dans `IzahayApp`

**Files:**
- Modify: `app/lib/main.dart`
- Modify: `app/test/widget_test.dart`
- Modify: `app/test/e2e_flow_test.dart`

**Interfaces:**
- Consumes: `LocaleController`, `LanguageStorage`, `MemoryLanguageStorage`, `LocaleScope` (Tasks 1-3).
- Produces: `IzahayApp({..., LanguageStorage? languageStorage})` ; `_IzahayAppState` expose en interne `_locale` (utilisé par les tâches suivantes pour construire `listeningTutorialSteps`).

- [ ] **Step 1: Write the failing test**

Ajouter à `app/test/widget_test.dart` (import `MemoryLanguageStorage` en tête) :

```dart
  testWidgets('IzahayApp démarre en malagasy par défaut', (tester) async {
    await tester.pumpWidget(
      IzahayApp(
        tutorialStorage: _doneTutorial(),
        languageStorage: MemoryLanguageStorage(),
      ),
    );
    await tester.pump();

    expect(find.text('Ianao ve dia...'), findsOneWidget);
  });
```

Et corriger le test existant `'IzahayApp se construit avec un MaterialApp'`
pour lui aussi injecter `languageStorage: MemoryLanguageStorage()` (évite
tout appel réel au plugin `shared_preferences` pendant les tests, comme
`tutorialStorage` le fait déjà pour le tutoriel) :

```dart
  testWidgets('IzahayApp se construit avec un MaterialApp', (tester) async {
    await tester.pumpWidget(
      IzahayApp(
        tutorialStorage: _doneTutorial(),
        languageStorage: MemoryLanguageStorage(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
```

Dans `app/test/e2e_flow_test.dart`, ajouter l'import de
`package:izahay/localization/app_language.dart` et
`package:izahay/localization/language_storage.dart`, puis
`languageStorage: MemoryLanguageStorage(AppLanguage.francais),` à
**chacun** des 3 appels `IzahayApp(...)` du fichier (lignes ~46, ~152,
~171) — ces tests vérifient un comportement (pas du texte traduit) et
doivent rester déterministes en français, langue dans laquelle ils ont été
écrits.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart test/e2e_flow_test.dart`
Expected: FAIL — `IzahayApp` n'a pas encore de paramètre `languageStorage`, et le texte malagasy n'existe pas encore dans `RoleSelectionScreen`.

- [ ] **Step 3: Modify `main.dart`**

Ajouter les imports :

```dart
import 'localization/language_storage.dart';
import 'localization/locale_controller.dart';
import 'localization/locale_scope.dart';
```

Dans `IzahayApp`, ajouter le champ et le paramètre :

```dart
  /// Stockage de la langue choisie ; `SharedPreferencesLanguageStorage` par
  /// défaut (voir `LocaleController`).
  final LanguageStorage? languageStorage;

  const IzahayApp({
    super.key,
    this.profileRepository,
    this.historySink,
    this.pipeline,
    this.tutorialStorage,
    this.languageStorage,
  });
```

Dans `_IzahayAppState`, ajouter le champ et l'initialiser en tout premier
dans `initState` (avant `_tutorial`, qui en a besoin — voir Task 13) :

```dart
  late final LocaleController _locale;
```

`listeningTutorialSteps` garde ici sa signature actuelle à un seul
paramètre (`_menuOpen`) — Task 14 la fera évoluer pour prendre `AppStrings`
en plus ; ne pas anticiper ce changement ici :

```dart
  @override
  void initState() {
    super.initState();
    _locale = LocaleController(storage: widget.languageStorage);
    unawaited(_locale.load());
    _menuOpen = ValueNotifier(false);
    _tutorial = TutorialController(
      steps: listeningTutorialSteps(_menuOpen),
      storage: widget.tutorialStorage ?? SharedPreferencesTutorialStorage(),
    );
    _pipeline =
        widget.pipeline ??
        SoundHapticPipeline(
          hapticEngine: HapticEngine(
            executor: const MethodChannelVibrationExecutor(),
          ),
          historySink: widget.historySink,
        );
    _profile = ProfileStore(
      repository: widget.profileRepository,
      onRestored: _applyProfile,
    );
    unawaited(_profile.restore());
    WidgetsBinding.instance.addObserver(this);
  }
```

Dans `dispose()` :

```dart
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _profile.dispose();
    _tutorial.dispose();
    _menuOpen.dispose();
    _locale.dispose();
    if (widget.pipeline == null) _pipeline.dispose();
    super.dispose();
  }
```

Envelopper le `MaterialApp` retourné par `build()` :

```dart
  @override
  Widget build(BuildContext context) {
    return LocaleScope(
      controller: _locale,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SENSIA',
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: Builder(
          builder: (context) => RoleSelectionScreen(
            onContinue: (role) {
              _profile.setRole(role);
              _open(
                context,
                (context) => VisionProblemScreen(
                  onContinue: (type) {
                    _profile.setColorVision(type);
                    _open(context, _listening);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart test/e2e_flow_test.dart`
Expected: le nouveau test malagasy échoue encore normalement tant que
`RoleSelectionScreen` n'affiche pas `AppStrings` (Task 6) — à ce stade,
vérifier seulement que **la compilation réussit** et que les tests déjà
existants du fichier (hors le nouveau) passent :
`flutter test test/widget_test.dart test/e2e_flow_test.dart --plain-name "IzahayApp se construit"`
Expected: PASS. Le test « démarre en malagasy » sera vérifié à la fin de Task 6.

- [ ] **Step 5: Commit**

```bash
git add app/lib/main.dart app/test/widget_test.dart app/test/e2e_flow_test.dart
git commit -m "feat: wire LocaleController into IzahayApp"
```

---

## Task 6 : Onboarding — `UserRole`, `ColorVisionType`, `RoleSelectionScreen`, `VisionProblemScreen`, `NextButton`

**Files:**
- Modify: `app/lib/models/user_role.dart`
- Modify: `app/lib/models/color_vision_type.dart`
- Modify: `app/lib/widgets/next_button.dart`
- Modify: `app/lib/screens/role_selection_screen.dart`
- Modify: `app/lib/screens/vision_problem_screen.dart`

**Interfaces:**
- Consumes: `AppStrings`, `LocaleScope`, `LanguageToggleButton` (Tasks 1, 3, 4).
- Produces: `UserRole.label(AppStrings)`, `ColorVisionType.label(AppStrings)` (méthodes, remplacent l'ancien champ `label`).

- [ ] **Step 1: Write the failing test**

Compléter `app/test/widget_test.dart` (le test ajouté en Task 5 exerce déjà
ce chemin) — ajouter en plus, dans `app/test/role_selection_screen_test.dart`,
un test de bascule explicite (les autres tests du fichier restent
inchangés, protégés par le repli français de `LocaleScope.of`) :

```dart
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
```

Ajouter les imports nécessaires en tête du fichier :
`package:izahay/localization/locale_controller.dart`,
`package:izahay/localization/locale_scope.dart`,
`package:izahay/localization/language_storage.dart`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/role_selection_screen_test.dart test/widget_test.dart`
Expected: FAIL — `UserRole.label` est encore un champ fixe en français, pas de `LanguageToggleButton` dans l'écran.

- [ ] **Step 3: Modify `user_role.dart`**

```dart
import '../localization/app_strings.dart';

enum UserRole {
  accompagnateur,
  client;

  String label(AppStrings strings) => switch (this) {
    UserRole.accompagnateur => strings.roleAccompagnateur,
    UserRole.client => strings.roleClient,
  };
}
```

- [ ] **Step 4: Modify `color_vision_type.dart`**

```dart
import '../localization/app_strings.dart';

enum ColorVisionType {
  protanopie,
  deuteranopie,
  tritanopie,
  achromatopsie,
  daltonisme;

  String label(AppStrings strings) => switch (this) {
    ColorVisionType.protanopie => strings.visionProtanopie,
    ColorVisionType.deuteranopie => strings.visionDeuteranopie,
    ColorVisionType.tritanopie => strings.visionTritanopie,
    ColorVisionType.achromatopsie => strings.visionAchromatopsie,
    ColorVisionType.daltonisme => strings.visionDaltonisme,
  };
}
```

- [ ] **Step 5: Modify `next_button.dart`**

Ajouter l'import `'../localization/locale_scope.dart'` et remplacer le
littéral :

```dart
            if (showLabel) ...[
              Text(
                LocaleScope.of(context).nextButtonLabel,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
            ],
```

(Retirer le `const` devant `Text(` puisqu'il n'est plus construit à partir
d'un littéral constant.)

- [ ] **Step 6: Modify `role_selection_screen.dart`**

Ajouter les imports :

```dart
import '../localization/locale_scope.dart';
import '../widgets/language_toggle_button.dart';
```

Dans `build()`, ajouter le bouton de bascule au `Stack` :

```dart
          body: Stack(
            children: [
              const Positioned.fill(child: WaveDecor()),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(child: _buildContent(context, selected)),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: LanguageToggleButton(
                  controller: LocaleScope.controllerOf(context),
                ),
              ),
            ],
          ),
```

`_buildContent` prend maintenant `context` en plus :

```dart
  Widget _buildContent(BuildContext context, UserRole? selected) {
    final strings = LocaleScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 100),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              strings.roleSelectionTitle,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 27,
                fontWeight: FontWeight.w700,
                height: 1.33,
                color: AppColors.title,
              ),
            ),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _RoleCard(
                  role: UserRole.accompagnateur,
                  image: 'assets/images/role_accompagnateur.png',
                  selected: selected == UserRole.accompagnateur,
                  onTap: () => _controller.select(UserRole.accompagnateur),
                ),
              ),
              const SizedBox(width: 17),
              Expanded(
                child: _RoleCard(
                  role: UserRole.client,
                  image: 'assets/images/role_client.png',
                  selected: selected == UserRole.client,
                  onTap: () => _controller.select(UserRole.client),
                ),
              ),
            ],
          ),
          const Spacer(),
          NextButton(
            showLabel: false,
            onPressed: selected == null
                ? null
                : () => widget.onContinue?.call(selected),
          ),
          const SizedBox(height: 96),
        ],
      ),
    );
  }
```

Et l'appel dans `build()` devient `_buildContent(context, selected)` (déjà
montré ci-dessus).

Dans `_RoleCard.build()`, remplacer `role.label` par
`role.label(LocaleScope.of(context))` aux deux emplacements (Semantics
`label:` et le `Text(role.label, ...)`).

- [ ] **Step 7: Modify `vision_problem_screen.dart`**

Ajouter les imports :

```dart
import '../localization/locale_scope.dart';
import '../widgets/language_toggle_button.dart';
```

Dans `build()`, ajouter le bouton de bascule au `Stack` et passer `context`
à `_buildContent` :

```dart
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final selected = _controller.selected;
        return Scaffold(
          backgroundColor: AppColors.backgroundVision,
          body: Stack(
            children: [
              const Positioned.fill(child: WaveDecor()),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(child: _buildContent(context, selected)),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: LanguageToggleButton(
                  controller: LocaleScope.controllerOf(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
```

Puis, dans `_buildContent`, remplacer les littéraux :

```dart
  Widget _buildContent(BuildContext context, ColorVisionType? selected) {
    final strings = LocaleScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 36),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: _BackButton(label: strings.back),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 27),
          child: Text(
            strings.visionProblemTitle,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 27,
              fontWeight: FontWeight.w700,
              height: 1.33,
              color: AppColors.title,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 27),
          child: Column(
            children: [
              for (final type in ColorVisionType.values) ...[
                _VisionOption(
                  type: type,
                  selected: selected == type,
                  onTap: () => _controller.select(type),
                ),
                if (type != ColorVisionType.values.last)
                  const SizedBox(height: 12.6),
              ],
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 27),
          child: NextButton(
            showLabel: false,
            onPressed: selected == null
                ? null
                : () => widget.onContinue?.call(selected),
          ),
        ),
        const SizedBox(height: 93),
      ],
    );
  }
```

`_BackButton` prend maintenant un `label` :

```dart
class _BackButton extends StatelessWidget {
  final String label;

  const _BackButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () => Navigator.maybePop(context),
        behavior: HitTestBehavior.opaque,
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: CustomPaint(
              size: Size(8.9, 16.1),
              painter: _ChevronPainter(),
            ),
          ),
        ),
      ),
    );
  }
}
```

Dans `_VisionOption.build()`, remplacer `type.label` par
`type.label(LocaleScope.of(context))` aux deux emplacements.

- [ ] **Step 8: Run test to verify it passes**

Run: `flutter test test/role_selection_screen_test.dart test/vision_problem_screen_test.dart test/widget_test.dart test/e2e_flow_test.dart`
Expected: PASS (les tests existants de ces 4 fichiers passent inchangés
grâce au repli français ; le nouveau test de bascule et le test « démarre
en malagasy » de Task 5 passent aussi).

- [ ] **Step 9: Commit**

```bash
git add app/lib/models/user_role.dart app/lib/models/color_vision_type.dart app/lib/widgets/next_button.dart app/lib/screens/role_selection_screen.dart app/lib/screens/vision_problem_screen.dart app/test/role_selection_screen_test.dart
git commit -m "feat: translate onboarding screens (role and vision selection)"
```

---

## Task 7 : `SoundLabels`, `SettingsCategories`, `VibrationEntries`

**Files:**
- Modify: `app/lib/config/sound_labels.dart`
- Modify: `app/lib/config/settings_categories.dart`
- Modify: `app/lib/config/vibration_entries.dart`
- Test: `app/test/config/sound_labels_test.dart`

**Interfaces:**
- Consumes: `AppStrings` (Task 1).
- Produces: `SoundLabels.of(AppStrings, String)`, `SoundLabels.priorityTitle(AppStrings, int)` ; `SettingsCategories.build(AppStrings)` (remplace le champ statique `all`) ; `VibrationEntries.build(AppStrings)` (remplace le champ statique `all`).

- [ ] **Step 1: Write the failing test**

`app/test/config/sound_labels_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/config/sound_labels.dart';
import 'package:izahay/localization/app_strings.dart';

void main() {
  test('of() traduit une catégorie connue', () {
    expect(SoundLabels.of(AppStrings.fr, 'dog_bark'), 'Aboiement');
    expect(SoundLabels.of(AppStrings.mg, 'dog_bark'), 'Fikaikain\'alika');
  });

  test('of() replie sur l\'identifiant pour une catégorie inconnue', () {
    expect(SoundLabels.of(AppStrings.fr, 'inconnu'), 'inconnu');
  });

  test('priorityTitle() traduit une priorité connue', () {
    expect(SoundLabels.priorityTitle(AppStrings.fr, 5), 'Danger immédiat');
    expect(SoundLabels.priorityTitle(AppStrings.mg, 5), 'Loza eo no eo');
  });

  test('priorityTitle() replie sur un préfixe générique pour une priorité inconnue', () {
    expect(SoundLabels.priorityTitle(AppStrings.fr, 42), 'Priorité 42');
    expect(SoundLabels.priorityTitle(AppStrings.mg, 42), 'Laharana 42');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/config/sound_labels_test.dart`
Expected: FAIL — `SoundLabels.of`/`priorityTitle` ont encore l'ancienne signature à un seul paramètre.

- [ ] **Step 3: Modify `sound_labels.dart`**

```dart
import '../localization/app_strings.dart';

/// Libellés des catégories de sons (identifiants de `SoundPriorityConfig`)
/// et des niveaux de priorité, dans la langue de [strings].
class SoundLabels {
  SoundLabels._();

  /// Libellé de [category] dans la langue de [strings] ; l'identifiant
  /// lui-même si elle est inconnue.
  static String of(AppStrings strings, String category) =>
      strings.soundCategoryLabels[category] ?? category;

  static String priorityTitle(AppStrings strings, int priority) =>
      strings.priorityTitles[priority] ??
      '${strings.priorityFallbackPrefix} $priority';
}
```

- [ ] **Step 4: Modify `settings_categories.dart`**

```dart
import '../localization/app_strings.dart';
import '../models/settings_category.dart';
import 'sound_labels.dart';
import 'sound_priority_config.dart';

/// Réglages affichés par [SettingsScreen] : un interrupteur par catégorie de
/// son (activer ou non sa détection), regroupées par niveau de priorité.
class SettingsCategories {
  SettingsCategories._();

  static List<SettingsCategory> build(AppStrings strings) {
    final byPriority = <int, List<SoundRule>>{};
    for (final rule in SoundPriorityConfig.rules) {
      byPriority.putIfAbsent(rule.vibrationPriority, () => []).add(rule);
    }
    final priorities = byPriority.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final priority in priorities)
        SettingsCategory(
          title: SoundLabels.priorityTitle(strings, priority),
          options: [
            for (final rule in byPriority[priority]!)
              SettingsOption(
                id: rule.category,
                label: SoundLabels.of(strings, rule.category),
                initialValue: true,
              ),
          ],
        ),
    ];
  }
}
```

- [ ] **Step 5: Modify `vibration_entries.dart`**

```dart
import '../localization/app_strings.dart';
import '../models/vibration_entry.dart';
import 'sound_labels.dart';
import 'sound_priority_config.dart';

/// Sons affichés par [VibrationsScreen] : toutes les catégories reconnues
/// par l'IA, de la plus prioritaire à la moins prioritaire.
class VibrationEntries {
  VibrationEntries._();

  static List<VibrationEntry> build(AppStrings strings) => [
    for (final rule in SoundPriorityConfig.rules)
      VibrationEntry(id: rule.category, label: SoundLabels.of(strings, rule.category)),
  ];
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/config/sound_labels_test.dart`
Expected: PASS

Note : ce changement rend `SettingsCategories`/`VibrationEntries` non
compilables tant que leurs deux appelants (`settings_screen.dart`,
`vibrations_screen.dart`) ne sont pas mis à jour — fait dans les Tasks 8 et 10.
Vérifier avec `flutter analyze` que les seules erreurs restantes concernent
ces deux fichiers, pas d'autres.

- [ ] **Step 7: Commit**

```bash
git add app/lib/config/sound_labels.dart app/lib/config/settings_categories.dart app/lib/config/vibration_entries.dart app/test/config/sound_labels_test.dart
git commit -m "feat: make SoundLabels, SettingsCategories and VibrationEntries language-aware"
```

---

## Task 8 : `SettingsScreen`

**Files:**
- Modify: `app/lib/screens/settings_screen.dart`

**Interfaces:**
- Consumes: `AppStrings`, `LocaleScope`, `LanguageToggleButton` (Tasks 1, 3, 4), `SettingsCategories.build` (Task 7).

- [ ] **Step 1: Write the failing test**

Ajouter à `app/test/settings_screen_test.dart` (imports :
`locale_controller.dart`, `locale_scope.dart`, `language_storage.dart`) :

```dart
  testWidgets('affiche le titre et les catégories réelles en malagasy', (
    tester,
  ) async {
    final controller = LocaleController(storage: MemoryLanguageStorage());
    await tester.pumpWidget(
      MaterialApp(
        home: LocaleScope(
          controller: controller,
          child: const SettingsScreen(),
        ),
      ),
    );

    expect(find.text('Fandrindrana ny feo'), findsOneWidget);
    expect(find.text('Jereo indray ny fampianarana'), findsNothing);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/settings_screen_test.dart`
Expected: FAIL (compile error : `SettingsCategories.all` n'existe plus).

- [ ] **Step 3: Modify `settings_screen.dart`**

Ajouter les imports :

```dart
import '../localization/locale_scope.dart';
import '../widgets/language_toggle_button.dart';
```

Remplacer le champ `_categories` calculé une fois par un getter recalculé
à chaque `build` (les catégories injectées par un test, via
`widget.categories`, restent prioritaires et inchangées) :

```dart
class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsController _controller;

  List<SettingsCategory> _categories(BuildContext context) =>
      widget.categories ?? SettingsCategories.build(LocaleScope.of(context));

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        SettingsController(
          widget.categories ?? SettingsCategories.build(AppStrings.fr),
          initialValues: widget.initialValues,
        );
  }
```

Ajouter l'import `import '../localization/app_strings.dart';` pour
`AppStrings.fr` ci-dessus : `SettingsController` ne sert qu'à retenir les
valeurs bool par identifiant d'option (`option.id`, stable, indépendant de
la langue) — la langue utilisée pour construire cette liste initiale n'a
donc aucun effet sur son comportement ; `AppStrings.fr` est un choix
arbitraire mais stable pour cette construction unique.

Dans `build()`, utiliser `_categories(context)` à la place de
`_categories`, ajouter `final strings = LocaleScope.of(context);`, et
remplacer les littéraux :

```dart
  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: WaveDecor()),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) => ListView(
                      padding: const EdgeInsets.fromLTRB(20, 89, 20, 16),
                      children: [
                        Text(
                          strings.settingsTitle,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 27,
                            fontWeight: FontWeight.w700,
                            color: AppColors.title,
                          ),
                        ),
                        const SizedBox(height: 21),
                        for (final category in _categories(context)) ...[
                          _CategoryHeader(title: category.title),
                          for (final option in category.options) ...[
                            const SizedBox(height: 4),
                            _OptionRow(
                              label: option.label,
                              value: _controller.valueOf(option.id),
                              onTap: () => _toggle(option.id),
                            ),
                          ],
                          const SizedBox(height: 20),
                        ],
                        if (widget.onReplayTutorial != null)
                          _ReplayTutorialRow(
                            label: strings.replayTutorial,
                            onTap: widget.onReplayTutorial!,
                          ),
                      ],
                    ),
                  ),
                ),
                HomeButton(
                  onPressed:
                      widget.onHome ?? () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 55),
              ],
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: LanguageToggleButton(
              controller: LocaleScope.controllerOf(context),
            ),
          ),
        ],
      ),
    );
  }
```

`_ReplayTutorialRow` prend maintenant un `label` :

```dart
class _ReplayTutorialRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ReplayTutorialRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.settingRow,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
              const Icon(Icons.play_circle_outline, size: 24, color: Colors.black),
            ],
          ),
        ),
      ),
    );
  }
}
```

(le `Row` const précédent devient non-const puisque `label` n'est plus un
littéral)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/settings_screen_test.dart`
Expected: PASS (le nouveau test passe ; les tests existants, qui
fournissent leurs propres `categories`/`controller` de test, restent
inchangés et passent grâce au repli français pour `strings.settingsTitle`/
`strings.replayTutorial`).

- [ ] **Step 5: Commit**

```bash
git add app/lib/screens/settings_screen.dart app/test/settings_screen_test.dart
git commit -m "feat: translate SettingsScreen"
```

---

## Task 9 : `BackupScreen`

**Files:**
- Modify: `app/lib/screens/backup_screen.dart`
- Modify: `app/test/backup_screen_test.dart`

**Interfaces:**
- Consumes: `AppStrings`, `LocaleScope`, `LanguageToggleButton` (Tasks 1, 3, 4).

- [ ] **Step 1: Write the failing test**

Dans `app/test/backup_screen_test.dart`, corriger l'assertion déjà
incohérente avec le code source actuel (voir Task 1, note sur
`backupUnavailable`) :

```dart
    expect(find.text('Sauvegarde indisponible (pas de Firebase).'), findsOneWidget);
```

(remplace l'ancien `expect(find.text('Sauvegarde indisponible.'), ...)`)

Ajouter aussi un test de bascule (imports :
`locale_controller.dart`, `locale_scope.dart`, `language_storage.dart`) :

```dart
  testWidgets('affiche le titre en malagasy par défaut', (tester) async {
    final controller = LocaleController(storage: MemoryLanguageStorage());
    await tester.pumpWidget(
      MaterialApp(
        home: LocaleScope(
          controller: controller,
          child: BackupScreen(store: ProfileStore()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tehirizo ny angon-drakitrao ary alefaso'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/backup_screen_test.dart`
Expected: FAIL — le texte est encore en dur en français.

- [ ] **Step 3: Modify `backup_screen.dart`**

Ajouter les imports :

```dart
import '../localization/app_strings.dart';
import '../localization/locale_scope.dart';
import '../widgets/language_toggle_button.dart';
```

Remplacer `_message` (méthode statique → méthode d'instance ou fonction
prenant `AppStrings`) :

```dart
  static String _message(AppStrings strings, ProfileSyncResult result) => switch (result) {
    ProfileSyncResult.saved => strings.backupSaved,
    ProfileSyncResult.restored => strings.backupRestored,
    ProfileSyncResult.nothingToRestore => strings.backupNothingToRestore,
    ProfileSyncResult.unavailable => strings.backupUnavailable,
    ProfileSyncResult.authFailed => strings.backupAuthFailed,
    ProfileSyncResult.permissionDenied => strings.backupPermissionDenied,
    ProfileSyncResult.failed => strings.backupFailed,
  };

  Future<void> _run(
    Future<ProfileSyncResult> Function() action,
    AppStrings strings,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await action();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_message(strings, result))));
  }
```

Dans `build()` :

```dart
  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: WaveDecor()),
          SafeArea(
            child: ListenableBuilder(
              listenable: widget.store,
              builder: (context, _) {
                final busy = widget.store.busy;
                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 84, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: Text(
                                strings.backupTitle,
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 27,
                                  fontWeight: FontWeight.w700,
                                  height: 1.37,
                                  color: AppColors.title,
                                ),
                              ),
                            ),
                            const SizedBox(height: 71),
                            _BackupButton(
                              label: strings.backupSaveButton,
                              icon: Icons.favorite_border,
                              onTap: busy
                                  ? null
                                  : () => _run(widget.store.save, strings),
                            ),
                            const SizedBox(height: 22),
                            _BackupButton(
                              label: strings.backupRestoreButton,
                              icon: Icons.download_outlined,
                              onTap: busy
                                  ? null
                                  : () => _run(widget.store.restore, strings),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: FutureBuilder<String?>(
                                future: _userId,
                                builder: (context, snapshot) {
                                  final text =
                                      snapshot.connectionState !=
                                          ConnectionState.done
                                      ? '…'
                                      : snapshot.data ?? strings.backupIdUnavailableValue;
                                  return Text(
                                    'ID: $text',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      color: Colors.black,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    HomeButton(
                      onPressed:
                          widget.onHome ??
                          () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(height: 55),
                  ],
                );
              },
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: LanguageToggleButton(
              controller: LocaleScope.controllerOf(context),
            ),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/backup_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/lib/screens/backup_screen.dart app/test/backup_screen_test.dart
git commit -m "feat: translate BackupScreen"
```

---

## Task 10 : `VibrationsScreen`

**Files:**
- Modify: `app/lib/screens/vibrations_screen.dart`

**Interfaces:**
- Consumes: `AppStrings`, `LocaleScope`, `LanguageToggleButton` (Tasks 1, 3, 4), `VibrationEntries.build` (Task 7).

- [ ] **Step 1: Write the failing test**

Ajouter à `app/test/vibrations_screen_test.dart` (imports :
`locale_controller.dart`, `locale_scope.dart`, `language_storage.dart`) :

```dart
  testWidgets('affiche le titre en malagasy par défaut', (tester) async {
    final controller = LocaleController(storage: MemoryLanguageStorage());
    await tester.pumpWidget(
      MaterialApp(
        home: LocaleScope(controller: controller, child: const VibrationsScreen()),
      ),
    );

    expect(find.text('Lisitry ny fihozongozonana'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/vibrations_screen_test.dart`
Expected: FAIL (compile error : `VibrationEntries.all` n'existe plus).

- [ ] **Step 3: Modify `vibrations_screen.dart`**

Ajouter les imports :

```dart
import '../localization/locale_scope.dart';
import '../widgets/language_toggle_button.dart';
```

Dans `build()` :

```dart
  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: WaveDecor()),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 80, 20, 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 1),
                        child: Text(
                          strings.vibrationsListTitle,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 27,
                            fontWeight: FontWeight.w700,
                            color: AppColors.title,
                          ),
                        ),
                      ),
                      const SizedBox(height: 29),
                      GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 48,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (final entry in entries ?? VibrationEntries.build(strings))
                            _VibrationCard(
                              entry: entry,
                              strings: strings,
                              onPattern: () => onPattern?.call(entry),
                              onSettings: () => onSettings?.call(entry),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                HomeButton(
                  onPressed: onHome ?? () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 55),
              ],
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: LanguageToggleButton(
              controller: LocaleScope.controllerOf(context),
            ),
          ),
        ],
      ),
    );
  }
```

`_VibrationCard` prend maintenant `strings` et l'utilise pour les deux
`_RoundAction` :

```dart
class _VibrationCard extends StatelessWidget {
  final VibrationEntry entry;
  final AppStrings strings;
  final VoidCallback onPattern;
  final VoidCallback onSettings;

  const _VibrationCard({
    required this.entry,
    required this.strings,
    required this.onPattern,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.hover,
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: AppColors.primary, offset: Offset(2, 2)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 60,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  entry.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundAction(
                    icon: Icons.waves,
                    label: strings.vibrationPatternAction(entry.label),
                    onTap: onPattern,
                  ),
                  _RoundAction(
                    icon: Icons.settings_outlined,
                    label: strings.vibrationSettingsAction(entry.label),
                    onTap: onSettings,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

Ajouter l'import `import '../localization/app_strings.dart';` pour le
type `AppStrings` utilisé ci-dessus.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/vibrations_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/lib/screens/vibrations_screen.dart app/test/vibrations_screen_test.dart
git commit -m "feat: translate VibrationsScreen"
```

---

## Task 11 : `VibrationConfigScreen`

**Files:**
- Modify: `app/lib/screens/vibration_config_screen.dart`

**Interfaces:**
- Consumes: `AppStrings`, `LocaleScope`, `LanguageToggleButton` (Tasks 1, 3, 4).

- [ ] **Step 1: Write the failing test**

Ajouter à `app/test/vibration_config_screen_test.dart` (imports :
`locale_controller.dart`, `locale_scope.dart`, `language_storage.dart`,
`models/vibration_entry.dart`) :

```dart
  testWidgets('affiche les actions en malagasy par défaut', (tester) async {
    final controller = LocaleController(storage: MemoryLanguageStorage());
    await tester.pumpWidget(
      MaterialApp(
        home: LocaleScope(
          controller: controller,
          child: VibrationConfigScreen(entry: const VibrationEntry(id: 'x', label: 'X')),
        ),
      ),
    );

    expect(find.text('Ampio feo lava'), findsOneWidget);
    expect(find.text('Ekeo'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/vibration_config_screen_test.dart`
Expected: FAIL — textes encore en dur en français.

- [ ] **Step 3: Modify `vibration_config_screen.dart`**

Ajouter les imports :

```dart
import '../localization/locale_scope.dart';
import '../widgets/language_toggle_button.dart';
```

Remplacer les deux messages de `_play()` :

```dart
  Future<void> _play() async {
    final pattern = _controller.toPattern(widget.entry.id);
    if (pattern == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final strings = LocaleScope.of(context);
    try {
      await _hapticEngine.playPattern(pattern);
    } on HapticUnsupportedException {
      messenger.showSnackBar(
        SnackBar(content: Text(strings.vibrationUnsupportedMessage)),
      );
    } on InvalidVibrationPatternException {
      messenger.showSnackBar(
        SnackBar(content: Text(strings.vibrationInvalidPatternMessage)),
      );
    }
  }
```

Dans `build()` :

```dart
  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: WaveDecor()),
          SafeArea(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                final empty = _controller.isEmpty;
                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 148, 20, 16),
                        child: Column(
                          children: [
                            _PatternPanel(segments: _controller.segments),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _SegmentButton(
                                  label: strings.addLongSegment,
                                  segment: VibrationSegment.long,
                                  onTap: () =>
                                      _controller.add(VibrationSegment.long),
                                ),
                                const SizedBox(width: 48),
                                _SegmentButton(
                                  label: strings.addShortSegment,
                                  segment: VibrationSegment.short,
                                  onTap: () =>
                                      _controller.add(VibrationSegment.short),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _ActionButton(
                                  icon: Icons.replay,
                                  label: strings.clearPattern,
                                  onTap: empty ? null : _controller.reset,
                                ),
                                const SizedBox(width: 20),
                                _ActionButton(
                                  icon: Icons.play_arrow_outlined,
                                  label: strings.tryVibration,
                                  onTap: empty ? null : _play,
                                ),
                                const SizedBox(width: 20),
                                _ActionButton(
                                  icon: Icons.check,
                                  label: strings.validate,
                                  onTap: empty ? null : _validate,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    HomeButton(
                      onPressed:
                          widget.onHome ??
                          () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(height: 55),
                  ],
                );
              },
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: LanguageToggleButton(
              controller: LocaleScope.controllerOf(context),
            ),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/vibration_config_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/lib/screens/vibration_config_screen.dart app/test/vibration_config_screen_test.dart
git commit -m "feat: translate VibrationConfigScreen"
```

---

## Task 12 : `AssociationsScreen`

**Files:**
- Modify: `app/lib/screens/associations_screen.dart`

**Interfaces:**
- Consumes: `AppStrings`, `LocaleScope`, `LanguageToggleButton` (Tasks 1, 3, 4).

- [ ] **Step 1: Write the failing test**

Ajouter à `app/test/associations_screen_test.dart` (imports :
`locale_controller.dart`, `locale_scope.dart`, `language_storage.dart`) :

```dart
  testWidgets('affiche le titre en malagasy par défaut', (tester) async {
    final controller = LocaleController(storage: MemoryLanguageStorage());
    await tester.pumpWidget(
      MaterialApp(
        home: LocaleScope(controller: controller, child: const AssociationsScreen()),
      ),
    );

    expect(find.text('Mitadiava\nvondrona afaka\nmanampy anao.'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/associations_screen_test.dart`
Expected: FAIL — texte encore en dur en français.

- [ ] **Step 3: Modify `associations_screen.dart`**

Ajouter les imports :

```dart
import '../localization/locale_scope.dart';
import '../widgets/language_toggle_button.dart';
```

Dans `build()` :

```dart
  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: WaveDecor()),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 17, 20, 16),
                    children: [
                      Text(
                        strings.associationsTitle,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 27,
                          fontWeight: FontWeight.w700,
                          height: 1.33,
                          color: AppColors.title,
                        ),
                      ),
                      const SizedBox(height: 23),
                      for (var i = 0; i < associations.length; i++) ...[
                        if (i > 0) const SizedBox(height: 21),
                        _AssociationCard(
                          association: associations[i],
                          strings: strings,
                          onContact: () => onContact?.call(associations[i]),
                        ),
                      ],
                    ],
                  ),
                ),
                HomeButton(
                  onPressed: onHome ?? () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 55),
              ],
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: LanguageToggleButton(
              controller: LocaleScope.controllerOf(context),
            ),
          ),
        ],
      ),
    );
  }
```

`_AssociationCard` prend `strings` et l'utilise pour le `Semantics.label` :

```dart
class _AssociationCard extends StatelessWidget {
  final Association association;
  final AppStrings strings;
  final VoidCallback onContact;

  const _AssociationCard({
    required this.association,
    required this.strings,
    required this.onContact,
  });
```

et dans son `build()`, remplacer `label: 'Contacter ${association.name}'`
par `label: strings.contactAssociation(association.name)`.

Ajouter l'import `import '../localization/app_strings.dart';`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/associations_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/lib/screens/associations_screen.dart app/test/associations_screen_test.dart
git commit -m "feat: translate AssociationsScreen"
```

---

## Task 13 : `ListeningScreen` et `HomeMenu`

**Files:**
- Modify: `app/lib/screens/listening_screen.dart`
- Modify: `app/lib/widgets/home_menu.dart`

**Interfaces:**
- Consumes: `AppStrings`, `LocaleScope`, `LanguageToggleButton` (Tasks 1, 3, 4).

- [ ] **Step 1: Write the failing test**

Ajouter à `app/test/listening_screen_test.dart` (imports :
`locale_controller.dart`, `locale_scope.dart`, `language_storage.dart`) :

```dart
  testWidgets('affiche les libellés en malagasy par défaut, bascule au tap', (
    tester,
  ) async {
    final controller = LocaleController(storage: MemoryLanguageStorage());
    await tester.pumpWidget(
      MaterialApp(
        home: LocaleScope(
          controller: controller,
          child: ListeningScreen(pipeline: _FakePipeline()),
        ),
      ),
    );

    expect(find.text('Tsy misy feo'), findsOneWidget);

    await tester.tap(find.text('FR'));
    await tester.pump();

    expect(find.text('Aucun son'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/listening_screen_test.dart`
Expected: FAIL — textes encore en dur en français, pas de bouton de bascule.

- [ ] **Step 3: Modify `listening_screen.dart`**

Ajouter les imports :

```dart
import '../localization/app_strings.dart';
import '../localization/locale_scope.dart';
import '../widgets/language_toggle_button.dart';
```

Dans `build()`, ajouter le bouton de bascule au `Stack` existant :

```dart
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              const Positioned.fill(child: WaveDecor()),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(child: _buildContent(context)),
                    ),
                  ),
                ),
              ),
              if (widget.tutorial != null)
                Positioned.fill(
                  child: TutorialScope(controller: widget.tutorial!),
                ),
              Positioned(
                top: 12,
                right: 12,
                child: LanguageToggleButton(
                  controller: LocaleScope.controllerOf(context),
                ),
              ),
            ],
          ),
        );
```

Dans `_PlayButton`, remplacer le littéral de `Semantics.label` :

```dart
class _PlayButton extends StatelessWidget {
  final bool listening;
  final bool loading;
  final VoidCallback? onPressed;

  const _PlayButton({
    required this.listening,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context);
    return Semantics(
      button: true,
      label: listening ? strings.stopListening : strings.startListening,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.hover),
            boxShadow: const [
              BoxShadow(color: AppColors.hover, offset: Offset(4, 4)),
            ],
          ),
          child: Center(
            child: loading
                ? const CircularProgressIndicator(color: AppColors.background)
                : Icon(
                    listening ? Icons.stop_rounded : Icons.play_arrow_outlined,
                    size: 60,
                    color: onPressed == null
                        ? AppColors.disabled
                        : AppColors.background,
                  ),
          ),
        ),
      ),
    );
  }
}
```

Supprimer les tables statiques `_categoryLabels` (garder `_categoryIcons`,
non concernée) et mettre à jour `_SoundCard` :

```dart
/// Carte du dernier son détecté.
class _SoundCard extends StatelessWidget {
  final SoundEventResult? result;

  const _SoundCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context);
    final category = result?.event.category;
    final icon = category == null
        ? null
        : _categoryIcons[category] ?? Icons.volume_up;
    final label = category == null
        ? strings.noSound
        : strings.listeningCategoryLabels[category] ?? category;
    return Container(
      width: 150,
      height: 70,
      decoration: BoxDecoration(
        color: AppColors.hover,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.primary),
        boxShadow: const [
          BoxShadow(color: AppColors.primary, offset: Offset(4, 4)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 6,
            top: 10,
            width: 144,
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: icon == null
                      ? null
                      : Icon(icon, size: 24, color: Colors.black),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Modify `home_menu.dart`**

Ajouter l'import `import '../localization/locale_scope.dart';`. Dans
`_HomeMenuState.build()`, lire `strings` une fois via `LocaleScope.of(context)`
puis l'utiliser dans les 4 appels `pill(...)` et dans `_CenterButton` :

```dart
  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context);
    return SizedBox(
      height: HomeMenu.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final centerLeft = (width - _centerSize) / 2;
          final centerTop = (HomeMenu.height - _centerSize) / 2;

          // Position d'une pastille : dans son coin quand le menu est ouvert,
          // repliée derrière le bouton central sinon.
          Widget pill(
            String id,
            String label,
            IconData icon,
            VoidCallback? onTap, {
            required bool left,
            required bool top,
          }) {
            final openLeft = left ? 0.0 : width - _pillWidth;
            final openTop = top ? 0.0 : HomeMenu.height - _pillHeight;
            return AnimatedPositioned(
              duration: _duration,
              curve: Curves.easeOutCubic,
              left: _open
                  ? openLeft
                  : centerLeft - (_pillWidth - _centerSize) / 2,
              top: _open ? openTop : centerTop,
              width: _pillWidth,
              height: _pillHeight,
              child: AnimatedOpacity(
                duration: _duration,
                opacity: _open ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !_open,
                  child: _target(
                    id,
                    _Pill(
                      label: label,
                      icon: icon,
                      onTap: () => _select(onTap),
                    ),
                  ),
                ),
              ),
            );
          }

          return Stack(
            children: [
              pill(
                'association',
                strings.pillAssociation,
                Icons.groups_outlined,
                widget.onAssociation,
                left: true,
                top: true,
              ),
              pill(
                'help',
                strings.pillHelp,
                Icons.checklist,
                widget.onHelp,
                left: false,
                top: true,
              ),
              pill(
                'settings',
                strings.pillSettings,
                Icons.settings_voice_outlined,
                widget.onSettings,
                left: true,
                top: false,
              ),
              pill(
                'backup',
                strings.pillBackup,
                Icons.person_outline,
                widget.onBackup,
                left: false,
                top: false,
              ),
              Positioned(
                left: centerLeft,
                top: centerTop,
                width: _centerSize,
                height: _centerSize,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    final p = (_pulse.value / _pulseWindow).clamp(0.0, 1.0);
                    final pulsing = _pulse.isAnimating && p < 1;
                    return Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        if (pulsing)
                          IgnorePointer(
                            child: Transform.scale(
                              scale: 1 + 0.6 * p,
                              child: Container(
                                width: _centerSize,
                                height: _centerSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary.withValues(
                                    alpha: 0.3 * (1 - p),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Transform.scale(
                          scale: pulsing ? 1 + 0.08 * math.sin(math.pi * p) : 1,
                          child: child,
                        ),
                      ],
                    );
                  },
                  child: _target(
                    'menu',
                    _CenterButton(open: _open, onTap: _toggle, strings: strings),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
```

`_CenterButton` prend `strings` :

```dart
class _CenterButton extends StatelessWidget {
  final bool open;
  final VoidCallback onTap;
  final AppStrings strings;

  const _CenterButton({required this.open, required this.onTap, required this.strings});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: open ? strings.centerFermerMenu : strings.centerAccueil,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: open ? AppColors.onPrimary : AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(
              color: open ? AppColors.primary : AppColors.background,
            ),
          ),
          child: Icon(
            open ? Icons.close : Icons.home_outlined,
            size: open ? 30 : 24,
            color: open ? AppColors.text : AppColors.onPrimary,
          ),
        ),
      ),
    );
  }
}
```

Ajouter l'import `import '../localization/app_strings.dart';` dans
`home_menu.dart`.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/listening_screen_test.dart`
Expected: PASS (les autres tests du fichier, sans `LocaleScope`, gardent
les labels français `'Association'`/`'Help'`/`'Settings'`/`'Sauvegarde'`
grâce au repli — ils continuent de trouver
`find.bySemanticsLabel('Association')` etc. sans changement).

- [ ] **Step 6: Commit**

```bash
git add app/lib/screens/listening_screen.dart app/lib/widgets/home_menu.dart app/test/listening_screen_test.dart
git commit -m "feat: translate ListeningScreen and HomeMenu"
```

---

## Task 14 : `CoachMark`, `TutorialController.updateSteps`, `listeningTutorialSteps`

**Files:**
- Modify: `app/lib/tutorial/coach_mark.dart`
- Modify: `app/lib/tutorial/tutorial_controller.dart`
- Modify: `app/lib/config/listening_tutorial_steps.dart`
- Modify: `app/lib/main.dart`
- Modify: `app/test/listening_screen_test.dart` (le test tutoriel existant)
- Test: `app/test/tutorial/tutorial_controller_test.dart` (nouveau cas)

**Interfaces:**
- Consumes: `AppStrings`, `LocaleScope` (Tasks 1, 3).
- Produces: `TutorialController.updateSteps(List<TutorialStep>)` ; `listeningTutorialSteps(ValueNotifier<bool>, AppStrings)` (signature à deux paramètres).

- [ ] **Step 1: Write the failing test**

Ajouter à `app/test/tutorial/tutorial_controller_test.dart` :

```dart
  test('updateSteps remplace les étapes si le tutoriel n\'est pas actif', () async {
    final c = _controller(MemoryTutorialStorage());
    c.updateSteps(const [
      TutorialStep(order: 1, targetId: 'z', title: 'Z', description: 'z'),
    ]);
    expect(c.steps.single.targetId, 'z');
  });

  test('updateSteps est ignoré si le tutoriel est déjà actif', () async {
    final c = _controller(MemoryTutorialStorage());
    await c.startIfNeeded();
    c.updateSteps(const [
      TutorialStep(order: 1, targetId: 'z', title: 'Z', description: 'z'),
    ]);
    expect(c.steps.first.targetId, 'a'); // inchangé
  });
```

Corriger dans `app/test/listening_screen_test.dart` l'appel existant
(le test `'le tutoriel guide pas à pas...'`) :

```dart
    final tutorial = TutorialController(
      steps: listeningTutorialSteps(menuOpen, AppStrings.fr),
      storage: MemoryTutorialStorage(),
    );
```

Ajouter l'import `package:izahay/localization/app_strings.dart` en tête de
`listening_screen_test.dart`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/tutorial/tutorial_controller_test.dart test/listening_screen_test.dart`
Expected: FAIL — `updateSteps` n'existe pas encore ; `listeningTutorialSteps` a encore un seul paramètre.

- [ ] **Step 3: Modify `tutorial_controller.dart`**

```dart
class TutorialController extends ChangeNotifier {
  static const maxAutoShows = 2;

  List<TutorialStep> _steps;
  final TutorialStorage _storage;
  final Map<String, GlobalKey> _keys = {};

  TutorialProgress _progress = const TutorialProgress();
  Future<void>? _loading;
  bool _active = false;
  bool _busy = false;
  int _index = 0;

  TutorialController({
    required List<TutorialStep> steps,
    TutorialStorage? storage,
  }) : _steps = _sorted(steps),
       _storage = storage ?? MemoryTutorialStorage();

  static List<TutorialStep> _sorted(List<TutorialStep> steps) =>
      List.unmodifiable([...steps]..sort((a, b) => a.order.compareTo(b.order)));

  List<TutorialStep> get steps => _steps;

  /// Remplace les étapes (ex. après un changement de langue). Ignoré si le
  /// tutoriel est déjà affiché : il ne change pas de contenu au milieu
  /// d'une étape en cours.
  void updateSteps(List<TutorialStep> steps) {
    if (_active) return;
    _steps = _sorted(steps);
  }

  bool get isActive => _active;
  int get index => _index;
  TutorialStep? get current => _active ? _steps[_index] : null;
  bool get isFirst => _index == 0;
  bool get isLast => _index == _steps.length - 1;

  bool get completed => _progress.completed;

  Future<void> _ensureLoaded() =>
      _loading ??= _storage.load().then((p) => _progress = p);

  Widget target(String id, Widget child) =>
      KeyedSubtree(key: _keys.putIfAbsent(id, GlobalKey.new), child: child);

  BuildContext? contextFor(String id) => _keys[id]?.currentContext;

  Future<void> startIfNeeded() async {
    await _ensureLoaded();
    if (_active || _steps.isEmpty) return;
    if (_progress.completed || _progress.autoShownCount >= maxAutoShows) return;
    _progress = _progress.copyWith(
      autoShownCount: _progress.autoShownCount + 1,
    );
    await _storage.save(_progress);
    await _begin();
  }

  Future<void> restart() async {
    await _ensureLoaded();
    if (_active || _steps.isEmpty) return;
    await _begin();
  }

  Future<void> _begin() async {
    _index = 0;
    await _steps.first.onEnter?.call();
    _active = true;
    notifyListeners();
  }

  Future<void> next() async {
    if (!_active) return;
    if (isLast) return finish();
    await _go(_index + 1);
  }

  Future<void> previous() async {
    if (!_active || isFirst) return;
    await _go(_index - 1);
  }

  Future<void> skip() => _close(completed: false);

  Future<void> finish() => _close(completed: true);

  Future<void> _go(int target) async {
    if (_busy) return;
    _busy = true;
    try {
      await _steps[target].onEnter?.call();
      _index = target;
      notifyListeners();
    } finally {
      _busy = false;
    }
  }

  Future<void> _close({required bool completed}) async {
    if (!_active) return;
    _active = false;
    if (completed) {
      _progress = _progress.copyWith(completed: true);
      await _storage.save(_progress);
    }
    notifyListeners();
  }
}
```

- [ ] **Step 4: Modify `listening_tutorial_steps.dart`**

```dart
import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../tutorial/tutorial_step.dart';

/// Étapes du tutoriel de l'écran principal, dans la langue de [strings].
List<TutorialStep> listeningTutorialSteps(
  ValueNotifier<bool> menuOpen,
  AppStrings strings,
) {
  Future<void> setMenu(bool open) async {
    if (menuOpen.value == open) return;
    menuOpen.value = open;
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  return [
    TutorialStep(
      order: 1,
      targetId: 'play',
      title: strings.tutorialStepStartTitle,
      description: strings.tutorialStepStartDescription,
      icon: Icons.play_arrow_outlined,
      action: TutorialAction.tapTarget,
      onEnter: () => setMenu(false),
    ),
    TutorialStep(
      order: 2,
      targetId: 'lastSound',
      title: strings.tutorialStepLastSoundTitle,
      description: strings.tutorialStepLastSoundDescription,
      icon: Icons.hearing,
      onEnter: () => setMenu(false),
    ),
    TutorialStep(
      order: 3,
      targetId: 'menu',
      title: strings.tutorialStepMenuTitle,
      description: strings.tutorialStepMenuDescription,
      icon: Icons.home_outlined,
      action: TutorialAction.tapTarget,
      onEnter: () => setMenu(false),
    ),
    TutorialStep(
      order: 4,
      targetId: 'help',
      title: strings.tutorialStepYourSoundsTitle,
      description: strings.tutorialStepYourSoundsDescription,
      icon: Icons.checklist,
      onEnter: () => setMenu(true),
    ),
    TutorialStep(
      order: 5,
      targetId: 'settings',
      title: strings.tutorialStepVibrationsTitle,
      description: strings.tutorialStepVibrationsDescription,
      icon: Icons.vibration,
      onEnter: () => setMenu(true),
    ),
    TutorialStep(
      order: 6,
      targetId: 'association',
      title: strings.tutorialStepAssociationsTitle,
      description: strings.tutorialStepAssociationsDescription,
      icon: Icons.groups_outlined,
      onEnter: () => setMenu(true),
    ),
    TutorialStep(
      order: 7,
      targetId: 'backup',
      title: strings.tutorialStepBackupTitle,
      description: strings.tutorialStepBackupDescription,
      icon: Icons.person_outline,
      onEnter: () => setMenu(true),
    ),
  ];
}
```

- [ ] **Step 5: Modify `coach_mark.dart`**

Ajouter l'import `import '../localization/locale_scope.dart';`. Dans
`build()` :

```dart
  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: strings.stepAnnouncement(
        title: step.title,
        description: step.description,
        number: number,
        total: total,
      ),
      child: Material(
        color: AppColors.background,
        elevation: 6,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary, width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (step.icon != null) ...[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.hover,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(step.icon, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      step.title,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.title,
                      ),
                    ),
                  ),
                  Text(
                    '$number / $total',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.title,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                step.description,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 16,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (onPrevious != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onPrevious,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          textStyle: _buttonStyle,
                        ),
                        child: Text(strings.tutorialPrevious),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: onNext,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        textStyle: _buttonStyle,
                      ),
                      child: Text(_isLast ? strings.tutorialFinish : strings.tutorialNext),
                    ),
                  ),
                ],
              ),
              if (!_isLast)
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: AppColors.title,
                    textStyle: _buttonStyle,
                  ),
                  child: Text(strings.tutorialSkip),
                ),
            ],
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 6: Modify `main.dart`**

Dans `initState`, finaliser l'appel (remplace le provisoire de Task 5) :

```dart
    _tutorial = TutorialController(
      steps: listeningTutorialSteps(_menuOpen, _locale.strings),
      storage: widget.tutorialStorage ?? SharedPreferencesTutorialStorage(),
    );
```

Et, juste après `unawaited(_locale.load());`, rafraîchir les étapes une
fois la langue persistée relue (limite documentée dans la spec : sans
effet si le tutoriel est déjà actif à ce moment-là) :

```dart
    _locale = LocaleController(storage: widget.languageStorage);
    unawaited(
      _locale.load().then((_) {
        if (!mounted) return;
        _tutorial.updateSteps(listeningTutorialSteps(_menuOpen, _locale.strings));
      }),
    );
```

(Ce `.then` doit être ajouté après la construction de `_tutorial`, donc
après la ligne `_tutorial = TutorialController(...)` — réordonner les deux
blocs dans `initState` en conséquence : `_locale` sans son `.load()`
d'abord, puis `_tutorial`, puis le `unawaited(_locale.load().then(...))`.)

- [ ] **Step 7: Run test to verify it passes**

Run: `flutter test test/tutorial/tutorial_controller_test.dart test/tutorial/tutorial_scope_test.dart test/listening_screen_test.dart test/widget_test.dart test/e2e_flow_test.dart`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add app/lib/tutorial/coach_mark.dart app/lib/tutorial/tutorial_controller.dart app/lib/config/listening_tutorial_steps.dart app/lib/main.dart app/test/listening_screen_test.dart app/test/tutorial/tutorial_controller_test.dart
git commit -m "feat: translate tutorial content and coach mark"
```

---

## Task 15 : Vérification finale

**Files:** aucun (tâche de vérification uniquement).

- [ ] **Step 1: Analyse statique complète**

Run (depuis `app/`, dans le conteneur Docker) : `flutter analyze`
Expected: aucune erreur (des avertissements préexistants, non liés à cette
tâche, peuvent subsister — vérifier qu'aucun nouveau n'apparaît dans les
fichiers modifiés par ce plan).

- [ ] **Step 2: Suite de tests complète**

Run: `flutter test`
Expected: PASS, y compris les 5 points de la section **Review Focus** :
- écrans pompés seuls → toujours en français (fallback) ;
- `IzahayApp` sans réglage de langue explicite → jamais de plugin réel
  `shared_preferences` touché en test (grep `SharedPreferences` dans
  `test/` ne doit renvoyer aucun résultat en dehors de
  `test/localization/locale_controller_test.dart`) ;
- persistance round-trip (`LocaleController` Task 2) ;
- catégorie de son inconnue (`sound_labels_test.dart` Task 7) ;
- tutoriel actif pendant une bascule (`tutorial_controller_test.dart` Task 14).

- [ ] **Step 3: Vérification manuelle rapide (optionnelle mais recommandée)**

Lancer l'app dans un simulateur/émulateur via Docker (`make run` ou
équivalent du projet), vérifier à l'œil :
1. L'app démarre bien en malagasy (« Ianao ve dia... »).
2. L'icône « FR » est visible en haut à droite de l'écran de sélection du
   rôle, du trouble de vision, et de l'écran principal.
3. Un tap bascule instantanément tout le texte visible en français, et
   l'icône devient « MG ».
4. Fermer et rouvrir l'app : la langue choisie (français) est toujours
   active au redémarrage.

- [ ] **Step 4: Commit final si des ajustements ont été faits**

```bash
git add -A
git commit -m "chore: final regression pass for Malagasy translation"
```

(Ne committer que s'il y a eu des changements à cette étape ; sinon, rien
à faire.)
