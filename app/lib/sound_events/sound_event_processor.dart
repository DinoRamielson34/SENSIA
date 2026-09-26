import 'dart:async';
import 'dart:developer' as developer;

import '../haptics/haptic_engine.dart';
import '../haptics/haptic_exceptions.dart';
import 'category_settings.dart';
import 'history_sink.dart';
import 'sound_event.dart';
import 'sound_event_result.dart';

/// Pipeline qui décide, pour chaque [SoundEvent] reçu, s'il doit déclencher
/// une vibration via [HapticEngine], en appliquant les règles métier
/// (catégorie connue, activée, seuil, confirmation, anti-répétition).
///
/// Fonctionne indépendamment du modèle IA et de Firebase : testable avec
/// des [SoundEvent] fictifs, sans microphone (voir le mode simulation via
/// `SoundEvent.isSimulation`).
class SoundEventProcessor {
  final HapticEngine _hapticEngine;
  final HistorySink? _historySink;

  /// Réglages par catégorie (seuil, activation, confirmations,
  /// anti-répétition), modifiables à l'exécution.
  final SoundEventSettings settings;

  bool _isListening = true;

  // Compteur de détections qualifiantes consécutives, par catégorie.
  final Map<String, int> _confirmationCounts = {};

  // Horodatage du dernier déclenchement réussi, par catégorie — utilisé
  // pour l'anti-répétition.
  final Map<String, DateTime> _lastTriggeredAt = {};

  // Jeton global (toutes catégories confondues), incrémenté juste avant
  // chaque appel à HapticEngine. Miroir du jeton interne de HapticEngine
  // (voir haptic_engine.dart) : comme aucune étape du pipeline avant cet
  // appel n'est asynchrone, l'ordre de prise de ces deux jetons est
  // strictement identique. Permet de détecter, après coup, qu'un autre
  // process() a supplanté celui-ci chez HapticEngine ("dernier gagne")
  // avant qu'il n'ait réellement vibré — HapticEngine ne le signale pas
  // lui-même (`playPattern` termine normalement, sans exception, même
  // quand la vibration a été silencieusement abandonnée).
  int _playToken = 0;

  SoundEventProcessor({
    required HapticEngine hapticEngine,
    SoundEventSettings? settings,
    HistorySink? historySink,
  }) : _hapticEngine = hapticEngine,
       _historySink = historySink,
       settings = settings ?? SoundEventSettings();

  /// Autorise à nouveau le traitement des événements en provenance du
  /// microphone (état par défaut à la création).
  void startListening() => _isListening = true;

  /// Bloque tout nouvel événement en provenance du microphone. Les
  /// événements simulés (`SoundEvent.isSimulation == true`) continuent
  /// d'être traités normalement : le mode simulation sert justement à
  /// tester le moteur sans microphone, l'arrêt de l'écoute réelle ne doit
  /// pas l'en empêcher.
  void stopListening() => _isListening = false;

  /// Traite [event] et retourne toujours un [SoundEventResult] — jamais
  /// d'exception pour une issue métier normale (catégorie désactivée,
  /// sous le seuil, etc.). Applique dans l'ordre : porte d'écoute,
  /// catégorie connue, catégorie activée, seuil, confirmation,
  /// anti-répétition, puis déclenchement haptique.
  Future<SoundEventResult> process(SoundEvent event) async {
    if (_blockedByListeningGate(event)) {
      return _result(event, SoundEventStatus.listeningStopped);
    }

    final categorySettings = settings.lookup(event.category);
    if (categorySettings == null) {
      return _result(event, SoundEventStatus.unknownCategory);
    }

    if (!categorySettings.enabled) {
      return _result(event, SoundEventStatus.categoryDisabled);
    }

    if (event.score < categorySettings.threshold) {
      // Une détection sous le seuil casse toute série de confirmation en
      // cours : la prochaine détection qualifiante repart de zéro.
      _confirmationCounts[event.category] = 0;
      return _result(event, SoundEventStatus.belowThreshold);
    }

    final confirmations = (_confirmationCounts[event.category] ?? 0) + 1;
    _confirmationCounts[event.category] = confirmations;
    if (confirmations < categorySettings.requiredConfirmations) {
      return _result(event, SoundEventStatus.awaitingConfirmation);
    }

    final lastTriggeredAt = _lastTriggeredAt[event.category];
    if (lastTriggeredAt != null &&
        event.timestamp.difference(lastTriggeredAt) <
            categorySettings.cooldown) {
      // Anti-répétition : la série de confirmation n'est PAS remise à
      // zéro ici — l'événement était valide, juste trop rapproché du
      // précédent déclenchement.
      return _result(event, SoundEventStatus.inCooldown);
    }

    // L'anti-répétition est réservée AVANT l'appel, pas après : sinon deux
    // événements de la même catégorie arrivant sans attendre l'un l'autre
    // passeraient tous les deux ce contrôle (aucun n'aurait encore mis à
    // jour _lastTriggeredAt), et pourraient tous les deux être rapportés
    // comme déclenchés pour une seule vibration réelle.
    final previousLastTriggeredAt = _lastTriggeredAt[event.category];
    _lastTriggeredAt[event.category] = event.timestamp;
    final myPlay = ++_playToken;

    try {
      await _hapticEngine.playForCategory(event.category);
    } on InvalidVibrationPatternException catch (e) {
      _restoreLastTriggeredAt(event.category, previousLastTriggeredAt);
      return _result(event, SoundEventStatus.hapticFailure, reason: e.message);
    } on HapticUnsupportedException catch (e) {
      _restoreLastTriggeredAt(event.category, previousLastTriggeredAt);
      return _result(event, SoundEventStatus.hapticFailure, reason: e.message);
    } on HapticPlatformException catch (e) {
      _restoreLastTriggeredAt(event.category, previousLastTriggeredAt);
      return _result(event, SoundEventStatus.hapticFailure, reason: e.message);
    }

    if (myPlay != _playToken) {
      // HapticEngine termine `playPattern` normalement même quand une
      // demande plus récente (même catégorie ou non) l'a supplantée entre
      // temps : il n'y a aucune exception à attraper ici pour le détecter,
      // seul ce jeton nous le dit. Sans cette vérification, cet événement
      // serait faussement rapporté "déclenché" alors qu'il n'a jamais
      // vibré, et la réservation ci-dessus démarrerait une anti-répétition
      // fantôme qui bloquerait le prochain vrai événement de la catégorie.
      _restoreLastTriggeredAt(event.category, previousLastTriggeredAt);
      return _result(event, SoundEventStatus.superseded);
    }

    _confirmationCounts[event.category] = 0;
    final result = _result(event, SoundEventStatus.triggered);
    final sink = _historySink;
    if (sink != null) {
      // Fire-and-forget : jamais attendu, pour qu'un historique lent ou
      // hors ligne (Firebase) ne retarde jamais une vibration déjà
      // déclenchée. L'erreur éventuelle du sink est délibérément avalée
      // ici : process() a déjà retourné son résultat, il n'y a plus
      // personne pour la recevoir. `Future.sync()` capture aussi une
      // exception levée de façon SYNCHRONE par une implémentation de
      // HistorySink qui ne serait pas `async` (sink.record(result) seul
      // ne le ferait pas : l'exception s'échapperait avant même de
      // produire un Future à intercepter).
      unawaited(
        Future.sync(() => sink.record(result)).catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          // Avalée pour l'appelant de process() (qui a déjà son résultat),
          // mais journalisée : sans ça, une mauvaise config Firebase
          // (règles non déployées, Auth anonyme désactivée...) fait
          // silencieusement disparaître tout l'historique sans aucune
          // trace nulle part.
          developer.log(
            'HistorySink.record a échoué (avalé, la vibration a déjà eu lieu)',
            name: 'SoundEventProcessor',
            error: error,
            stackTrace: stackTrace,
          );
        }),
      );
    }
    return result;
  }

  // Restaure _lastTriggeredAt à son état d'avant la réservation, quand le
  // déclenchement n'a finalement pas eu lieu (échec ou supplanté) : sinon
  // une réservation annulée laisserait soit une entrée fantôme (si aucun
  // déclenchement précédent n'existait), soit écraserait un vrai
  // déclenchement précédent par une date qui n'a jamais eu lieu.
  void _restoreLastTriggeredAt(String category, DateTime? previous) {
    if (previous == null) {
      _lastTriggeredAt.remove(category);
    } else {
      _lastTriggeredAt[category] = previous;
    }
  }

  // Un événement microphone réel est bloqué si l'écoute est arrêtée. Un
  // événement simulé ignore toujours cette porte, même s'il se déclare
  // source: "microphone".
  bool _blockedByListeningGate(SoundEvent event) {
    return !_isListening && !event.isSimulation && event.source == 'microphone';
  }

  SoundEventResult _result(
    SoundEvent event,
    SoundEventStatus status, {
    String? reason,
  }) {
    return SoundEventResult(
      event: event,
      status: status,
      isSimulation: event.isSimulation,
      reason: reason,
    );
  }
}
