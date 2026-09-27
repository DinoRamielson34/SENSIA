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
