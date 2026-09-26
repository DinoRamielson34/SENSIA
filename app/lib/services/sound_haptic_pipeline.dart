import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../config/haptic_pattern_config.dart';
import '../haptics/haptic_engine.dart';
import '../haptics/haptic_exceptions.dart';
import '../haptics/models/vibration_pattern.dart';
import '../models/audio_frame.dart';
import '../models/sound_detection_result.dart';
import '../sound_events/category_settings.dart';
import '../sound_events/sound_event.dart';
import '../sound_events/sound_event_processor.dart';
import '../sound_events/history_sink.dart';
import '../sound_events/sound_event_result.dart';
import 'audio_preprocessing_service.dart';
import 'sound_filter_service.dart';
import 'yamnet_service.dart';

/// Chaîne complète : microphone → YAMNet → filtre → [SoundEventProcessor]
/// → [HapticEngine] → vibration.
///
/// Ne réimplémente rien : elle orchestre les modules existants
/// ([AudioPreprocessingService], [YamnetService], [SoundFilterService],
/// [SoundEventProcessor], [HapticEngine]) et expose leur état à l'interface
/// via [ChangeNotifier].
class SoundHapticPipeline extends ChangeNotifier {
  final HapticEngine _hapticEngine;
  final SoundEventProcessor _processor;
  final AudioPreprocessingService _audioService;
  final YamnetService _yamnetService;
  final SoundFilterService _filterService;

  bool _isListening = false;
  bool _modelLoading = true;
  String? _error;
  SoundEventResult? _lastResult;
  SoundEventResult? _lastTriggered;

  /// Crée le pipeline.
  ///
  /// [hapticEngine] est obligatoire (il porte l'exécuteur de vibrations,
  /// réel ou factice en test). Les autres services sont optionnels et
  /// créés par défaut ; on ne les injecte que pour les tests. Les motifs
  /// et réglages de toutes les catégories IA sont enregistrés ici, une
  /// seule fois (voir [HapticPatternConfig]).
  SoundHapticPipeline({
    required HapticEngine hapticEngine,
    SoundEventProcessor? processor,
    HistorySink? historySink,
    AudioPreprocessingService? audioService,
    YamnetService? yamnetService,
    SoundFilterService? filterService,
  }) : _hapticEngine = hapticEngine,
       _processor =
           processor ??
           SoundEventProcessor(
             hapticEngine: hapticEngine,
             settings: HapticPatternConfig.buildSettings(),
             historySink: historySink,
           ),
       _audioService = audioService ?? AudioPreprocessingService(),
       _yamnetService = yamnetService ?? YamnetService(),
       _filterService = filterService ?? SoundFilterService() {
    HapticPatternConfig.registerAll(hapticEngine);
    _processor.stopListening();
    _initForegroundTask();
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'sensia_listening',
        channelName: 'SENSIA Écoute',
        channelDescription: 'Écoute sonore en arrière-plan',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// true pendant que le microphone est écouté.
  bool get isListening => _isListening;

  /// true tant que le modèle YAMNet est en cours de chargement.
  bool get modelLoading => _modelLoading;

  /// true si le modèle est chargé et prêt à analyser.
  bool get modelReady => _yamnetService.isLoaded;

  /// Dernier message d'erreur à afficher, ou null.
  String? get error => _error;

  /// Résultat du traitement du dernier son détecté (déclenché ou non).
  SoundEventResult? get lastResult => _lastResult;

  /// Dernier son ayant réellement fait vibrer le téléphone.
  SoundEventResult? get lastTriggered => _lastTriggered;

  /// Réglages par catégorie (seuil, activation, anti-répétition).
  SoundEventSettings get settings => _processor.settings;

  /// Score EMA lissé pour [category] (0.0 à 1.0).
  double getEma(String category) => _filterService.getEma(category);

  /// Dernières détections (toutes catégories) du dernier frame audio.
  List<SoundDetectionResult> get lastDetections => _lastDetections;
  List<SoundDetectionResult> _lastDetections = [];

  /// Charge le modèle YAMNet.
  ///
  /// Effets de bord : met à jour [modelLoading], [modelReady] et [error],
  /// puis notifie l'interface. Ne lève pas d'exception : un échec de
  /// chargement est rapporté via [error] (message de [YamnetService]).
  Future<void> loadModel() async {
    await _yamnetService.loadModel();
    _modelLoading = false;
    _error = _yamnetService.error;
    notifyListeners();
  }

  /// Démarre l'écoute du microphone.
  ///
  /// Demande la permission micro, remet le filtre à zéro et branche
  /// [_onAudioFrame] sur le flux audio. Ne fait rien si déjà en écoute.
  /// Effets de bord : active le micro, met à jour [isListening] et
  /// [error]. Erreurs possibles (rapportées via [error], jamais levées) :
  /// modèle non chargé, permission refusée, micro indisponible.
  Future<void> start() async {
    if (_isListening) return;
    if (!_yamnetService.isLoaded) {
      _error = 'Modèle non chargé';
      notifyListeners();
      return;
    }
    if (!await _audioService.requestPermission()) {
      _error = 'Permission microphone refusée';
      notifyListeners();
      return;
    }

    _filterService.reset();
    final started = await _audioService.start(onFrame: _onAudioFrame);
    if (!started) {
      _error = 'Impossible de démarrer le microphone';
      notifyListeners();
      return;
    }

    _processor.startListening();
    _isListening = true;
    _error = null;
    notifyListeners();
    FlutterForegroundTask.startService(
      notificationTitle: 'SENSIA',
      notificationText: 'Écoute sonore en cours…',
    );
  }

  /// Arrête l'écoute : plus aucune nouvelle détection n'est traitée.
  ///
  /// Effets de bord : coupe le micro, bloque le processor pour les sons
  /// micro (voir `SoundEventProcessor.stopListening`) et interrompt une
  /// vibration en cours. Ne lève pas d'exception d'écoute.
  Future<void> stop() async {
    // On ferme la porte AVANT de couper le micro : une image audio encore
    // en vol ne pourra plus déclencher de vibration.
    _isListening = false;
    _processor.stopListening();
    await _audioService.stop();
    _filterService.reset();
    await _hapticEngine.stop();
    FlutterForegroundTask.stopService();
    notifyListeners();
  }

  /// Reçoit une seconde d'audio du micro : la fait analyser par YAMNet, la
  /// filtre, puis transmet les détections à [handleDetections].
  ///
  /// Paramètre : [frame] l'image audio (16 kHz, mono). Sans valeur de
  /// retour. Si YAMNet ne renvoie rien, [error] est mis à jour.
  void _onAudioFrame(AudioFrame frame) {
    if (!_isListening) return;
    final yamnetResults = _yamnetService.classify(frame);
    if (yamnetResults.isEmpty) {
      _error = _yamnetService.error;
      notifyListeners();
      return;
    }
    final detections = _filterService.processResults(yamnetResults);
    _lastDetections = detections;
    _error = null;
    notifyListeners();
    final confirmed = detections.where((d) => d.confirmed).toList();
    if (confirmed.isNotEmpty) {
      unawaited(handleDetections(confirmed));
    }
  }

  /// Transmet au processor les détections confirmées d'une image audio.
  ///
  /// [detections] est triée par priorité décroissante (voir
  /// `SoundFilterService.processResults`). On les traite dans cet ordre et
  /// on s'arrête à la première qui fait vibrer : sinon, avec la règle
  /// « la dernière demande gagne » du moteur, un son peu important
  /// écraserait la vibration d'un son plus important. Si la plus
  /// prioritaire est bloquée (anti-répétition, catégorie désactivée...),
  /// la suivante a sa chance.
  ///
  /// Effets de bord : peut faire vibrer, met à jour [lastResult] /
  /// [lastTriggered] et notifie l'interface. Ne fait rien si l'écoute est
  /// arrêtée ou si [detections] est vide. Ne lève pas d'exception métier.
  Future<void> handleDetections(List<SoundDetectionResult> detections) async {
    if (!_isListening || detections.isEmpty) return;

    SoundEventResult? shown;
    for (final detection in detections) {
      final result = await _processor.process(toSoundEvent(detection));
      shown ??= result;
      if (result.status == SoundEventStatus.triggered) {
        shown = result;
        _lastTriggered = result;
        break;
      }
    }
    _lastResult = shown;
    notifyListeners();
  }

  /// Convertit une détection de l'IA en événement standardisé pour le
  /// processor : c'est le contrat entre les deux modules.
  ///
  /// Paramètre : [detection] la détection IA. Retourne un [SoundEvent]
  /// avec `source: 'microphone'` et `isSimulation: false`. Sans effet de
  /// bord ni erreur.
  static SoundEvent toSoundEvent(SoundDetectionResult detection) {
    return SoundEvent(
      category: detection.category,
      score: detection.score,
      timestamp: detection.timestamp,
      source: 'microphone',
      isSimulation: false,
    );
  }

  /// Injecte un son simulé (sans micro) dans le même processor que les sons
  /// réels : mêmes règles (seuil, activation, anti-répétition).
  ///
  /// Paramètres : [category] catégorie simulée ; [score] score simulé.
  /// Retourne le résultat du traitement, aussi stocké dans [lastResult].
  /// Effets de bord : peut faire vibrer, notifie l'interface.
  Future<SoundEventResult> simulate(String category, double score) async {
    final result = await _processor.process(
      SoundEvent(
        category: category,
        score: score,
        timestamp: DateTime.now(),
        source: 'simulation',
        isSimulation: true,
      ),
    );
    _lastResult = result;
    if (result.status == SoundEventStatus.triggered) _lastTriggered = result;
    notifyListeners();
    return result;
  }

  /// Fait vibrer directement le motif de [category], sans passer par les
  /// règles de seuil/anti-répétition (bouton « tester la vibration »).
  ///
  /// Effets de bord : fait vibrer le téléphone et met à jour [error].
  /// Erreurs (rapportées via [error], pas levées) : appareil sans vibreur
  /// ([HapticUnsupportedException]), pont natif absent
  /// ([HapticPlatformException]), motif absent
  /// ([InvalidVibrationPatternException]).
  Future<void> testVibration(String category) async {
    try {
      await _hapticEngine.playForCategory(category);
      _error = null;
    } on HapticUnsupportedException {
      _error = 'Appareil sans vibreur';
    } on HapticPlatformException catch (e) {
      _error = e.message;
    } on InvalidVibrationPatternException catch (e) {
      _error = e.message;
    }
    notifyListeners();
  }

  /// Indique si [category] est activée (false si inconnue).
  bool isCategoryEnabled(String category) =>
      _processor.settings.lookup(category)?.enabled ?? false;

  /// Active ou désactive [category]. Sans effet si la catégorie est
  /// inconnue. Effet de bord : notifie l'interface ; les autres réglages
  /// (seuil, anti-répétition) sont conservés.
  void setCategoryEnabled(String category, bool enabled) {
    final current = _processor.settings.lookup(category);
    if (current == null) return;
    _processor.settings.updateCategory(
      category,
      CategorySettings(
        enabled: enabled,
        threshold: current.threshold,
        requiredConfirmations: current.requiredConfirmations,
        cooldown: current.cooldown,
      ),
    );
    notifyListeners();
  }

  // Motifs choisis par l'utilisateur, prioritaires sur ceux de la config.
  final Map<String, VibrationPattern> _customPatterns = {};

  /// Motif de vibration associé à [category], ou null s'il n'y en a pas.
  VibrationPattern? patternFor(String category) =>
      _customPatterns[category] ?? HapticPatternConfig.patterns[category];

  /// Remplace le motif joué pour [category], à la détection comme au test.
  ///
  /// Lève `InvalidVibrationPatternException` si [pattern] est invalide.
  /// Effet de bord : notifie l'interface.
  void setCategoryPattern(String category, VibrationPattern pattern) {
    _hapticEngine.registerPattern(category, pattern);
    _customPatterns[category] = pattern;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_audioService.dispose());
    _yamnetService.dispose();
    super.dispose();
  }
}
