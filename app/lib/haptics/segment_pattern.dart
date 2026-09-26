import '../models/vibration_segment.dart';
import 'models/vibration_pattern.dart';

/// Durées d'un segment long / court et de la pause entre deux segments ;
/// mêmes valeurs de référence que `HapticPatternConfig`.
class SegmentDurations {
  SegmentDurations._();

  static const long = Duration(milliseconds: 500);
  static const short = Duration(milliseconds: 150);
  static const gap = Duration(milliseconds: 150);
}

/// Motif de vibration correspondant à une suite de [segments].
///
/// Une liste vide donnerait un motif invalide : l'appelant doit s'assurer
/// qu'elle contient au moins un segment.
VibrationPattern patternFromSegments(
  String id,
  List<VibrationSegment> segments,
) {
  return VibrationPattern(
    id: id,
    pulses: [
      for (var i = 0; i < segments.length; i++)
        VibrationPulse(
          vibrate: segments[i] == VibrationSegment.long
              ? SegmentDurations.long
              : SegmentDurations.short,
          pauseAfter: i == segments.length - 1
              ? Duration.zero
              : SegmentDurations.gap,
        ),
    ],
  );
}

/// Approximation d'un motif existant en segments long / court : une
/// impulsion de 400 ms ou plus est « longue », les autres sont « courtes ».
List<VibrationSegment> segmentsFromPattern(VibrationPattern pattern) => [
  for (final pulse in pattern.pulses)
    pulse.vibrate >= const Duration(milliseconds: 400)
        ? VibrationSegment.long
        : VibrationSegment.short,
];
