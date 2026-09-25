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
