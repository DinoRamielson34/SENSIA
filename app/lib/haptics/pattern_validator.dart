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
