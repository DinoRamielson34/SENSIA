import '../haptics/haptic_engine.dart';
import '../haptics/models/vibration_pattern.dart';
import '../sound_events/category_settings.dart';
import 'sound_priority_config.dart';

/// Pont de configuration entre le module IA ([SoundPriorityConfig], qui
/// nomme les catégories reconnues) et le moteur de vibrations
/// ([HapticEngine] / [SoundEventProcessor], qui doivent connaître ces mêmes
/// noms). Sans lui, une catégorie comme "dog_bark" serait rejetée par le
/// processor comme `unknownCategory` : les deux modules ne parleraient pas
/// le même vocabulaire.
class HapticPatternConfig {
  HapticPatternConfig._();

  // Durées de référence : assez différentes pour se distinguer au toucher.
  static const _tick = Duration(milliseconds: 80);
  static const _short = Duration(milliseconds: 150);
  static const _medium = Duration(milliseconds: 280);
  static const _long = Duration(milliseconds: 500);
  static const _xLong = Duration(milliseconds: 900);
  static const _gap = Duration(milliseconds: 150);

  /// Construit un motif à partir d'une liste de durées de vibration, avec
  /// une pause fixe entre deux impulsions (et aucune après la dernière).
  ///
  /// Paramètres : [id] identifiant du motif ; [durations] durées de chaque
  /// impulsion, dans l'ordre. Retourne le [VibrationPattern] correspondant.
  /// Sans effet de bord. Une liste vide donnerait un motif invalide, rejeté
  /// plus tard par `PatternValidator` lors de l'enregistrement.
  static VibrationPattern _pattern(String id, List<Duration> durations) {
    final pulses = <VibrationPulse>[];
    for (var i = 0; i < durations.length; i++) {
      final isLast = i == durations.length - 1;
      pulses.add(
        VibrationPulse(
          vibrate: durations[i],
          pauseAfter: isLast ? Duration.zero : _gap,
        ),
      );
    }
    return VibrationPattern(id: id, pulses: pulses);
  }

  /// Motif de vibration de chaque catégorie de [SoundPriorityConfig].
  /// Chaque motif est unique (nombre et durée des impulsions) pour qu'on
  /// puisse reconnaître le son au toucher, sans regarder l'écran.
  static final Map<String, VibrationPattern> patterns = {
    // Sons du quotidien
    'doorbell': _pattern('doorbell', [_short, _short]), // 2 courtes
    'door_knock': _pattern('door_knock', [_tick, _tick, _tick]), // 3 légères
    'telephone': _pattern('telephone', [_short, _short, _short, _short]),
    'alarm_clock': _pattern('alarm_clock', [_medium, _medium]),
    'dog_bark': _pattern('dog_bark', [_long, _long, _long]), // 3 longues
    'baby_cry': _pattern('baby_cry', [_long, _short, _long]),
    // Alertes (alternance courte / longue)
    'alarm': _pattern('alarm', [_short, _long, _short, _long]),
    'emergency_siren': _pattern('emergency_siren', [
      _short,
      _long,
      _short,
      _long,
      _short,
      _long,
    ]),
    'car_alarm': _pattern('car_alarm', [_long, _long]),
    'car_horn': _pattern('car_horn', [_xLong]), // 1 très longue
    // Dangers : vibrations les plus marquées
    'smoke_alarm': _pattern('smoke_alarm', [_medium, _medium, _medium]),
    'fire_alarm': _pattern('fire_alarm', [
      _short,
      _short,
      _short,
      _short,
      _short,
      _short,
    ]),
    'train': _pattern('train', [_xLong, _short, _short]),
  };

  /// Enregistre dans [engine] le motif de chaque catégorie de
  /// [SoundPriorityConfig].
  ///
  /// Paramètre : [engine] le moteur à configurer. Effet de bord : remplace
  /// les motifs déjà enregistrés pour ces catégories. Lève
  /// `InvalidVibrationPatternException` si un motif de [patterns] est
  /// invalide (erreur de programmation, jamais liée à l'utilisateur).
  static void registerAll(HapticEngine engine) {
    for (final entry in patterns.entries) {
      engine.registerPattern(entry.key, entry.value);
    }
  }

  /// Crée les réglages du processor pour toutes les catégories de
  /// [SoundPriorityConfig] : mêmes noms que l'IA, et seuil identique à
  /// celui de la règle IA (le seuil par défaut du processor, 0.75, serait
  /// rarement atteint par les scores bruts de YAMNet).
  ///
  /// Retourne un nouveau [SoundEventSettings] (qui contient aussi les
  /// catégories d'exemple historiques "sonnette"/"aboiement"). Sans effet
  /// de bord, aucune erreur attendue.
  static SoundEventSettings buildSettings() {
    final settings = SoundEventSettings();
    for (final rule in SoundPriorityConfig.rules) {
      settings.updateCategory(
        rule.category,
        CategorySettings(
          enabled: true,
          threshold: rule.threshold,
          requiredConfirmations: 1, // l'IA lisse déjà les scores (EMA)
          cooldown: const Duration(seconds: 5),
        ),
      );
    }
    return settings;
  }

  /// Décrit [pattern] en français pour l'interface, par exemple
  /// "2 courtes" ou "courte, longue, courte, longue".
  ///
  /// Paramètre : [pattern] le motif à décrire. Retourne un texte lisible.
  /// Sans effet de bord ni erreur.
  static String describe(VibrationPattern pattern) {
    final labels = pattern.pulses.map((p) {
      final ms = p.vibrate.inMilliseconds;
      if (ms <= 100) return 'légère';
      if (ms <= 200) return 'courte';
      if (ms <= 350) return 'moyenne';
      if (ms <= 600) return 'longue';
      return 'très longue';
    }).toList();

    // Si toutes les impulsions sont identiques : "3 longues" plutôt que
    // "longue, longue, longue".
    if (labels.toSet().length == 1) {
      final label = labels.first;
      final plural = label.endsWith('e') ? '${label}s' : label;
      return labels.length == 1 ? '1 $label' : '${labels.length} $plural';
    }
    return labels.join(', ');
  }
}
