/// Une impulsion de vibration : une durée de vibration suivie d'une pause
/// optionnelle.
class VibrationPulse {
  /// Durée pendant laquelle le téléphone vibre. Doit être strictement
  /// positive (validé par [PatternValidator], pas ici).
  final Duration vibrate;

  /// Durée de la pause après cette impulsion. `Duration.zero` si aucune
  /// pause n'est nécessaire (par exemple la dernière impulsion d'un motif).
  final Duration pauseAfter;

  const VibrationPulse({
    required this.vibrate,
    this.pauseAfter = Duration.zero,
  });
}

/// Un motif de vibration complet : une suite ordonnée d'impulsions.
///
/// [id] identifie le motif dans les messages d'erreur et les logs, par
/// exemple "sonnette" ou "alarme".
class VibrationPattern {
  final String id;
  final List<VibrationPulse> pulses;

  const VibrationPattern({
    required this.id,
    required this.pulses,
  });
}
