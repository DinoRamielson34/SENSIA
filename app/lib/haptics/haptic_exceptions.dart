/// Exception levée quand un [VibrationPattern] ne respecte pas les règles de
/// validité (voir [PatternValidator]) : par exemple une liste d'impulsions
/// vide, ou une durée de vibration nulle/négative.
class InvalidVibrationPatternException implements Exception {
  final String message;
  const InvalidVibrationPatternException(this.message);

  @override
  String toString() => 'InvalidVibrationPatternException: $message';
}

/// Exception levée quand l'appareil ne dispose d'aucun vibreur matériel.
/// Vérifiable à l'avance via `HapticEngine.isDeviceCompatible`.
class HapticUnsupportedException implements Exception {
  final String message;
  const HapticUnsupportedException(this.message);

  @override
  String toString() => 'HapticUnsupportedException: $message';
}

/// Enveloppe une erreur native inattendue remontée par le canal de
/// communication Flutter <-> Android (ex : PlatformException).
class HapticPlatformException implements Exception {
  final String message;
  final Object? cause;
  const HapticPlatformException(this.message, {this.cause});

  @override
  String toString() => 'HapticPlatformException: $message'
      '${cause != null ? ' (cause: $cause)' : ''}';
}
