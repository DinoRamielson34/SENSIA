import '../config/sound_priority_config.dart';
import '../models/sound_detection_result.dart';
import 'yamnet_service.dart';

class SoundFilterService {
  final Map<String, double> _ema = {};
  final Map<String, String> _lastBestClass = {};

  List<SoundDetectionResult> processResults(List<YamnetResult> yamnetResults) {
    final now = DateTime.now();
    final detections = <SoundDetectionResult>[];

    final scoreMap = <String, double>{};
    for (final result in yamnetResults) {
      scoreMap[result.label] = result.score;
    }

    for (final rule in SoundPriorityConfig.rules) {
      double bestScore = 0.0;
      String bestClass = '';

      for (final yamnetClass in rule.yamnetClasses) {
        final score = scoreMap[yamnetClass] ?? 0.0;
        if (score > bestScore) {
          bestScore = score;
          bestClass = yamnetClass;
        }
      }

      if (bestClass.isNotEmpty) {
        _lastBestClass[rule.category] = bestClass;
      }

      final prev = _ema[rule.category] ?? 0.0;
      final smoothed = rule.alpha * bestScore + (1 - rule.alpha) * prev;
      _ema[rule.category] = smoothed;

      final confirmed = smoothed >= rule.threshold;

      // Affiche toutes les catégories (même non confirmées) pour debug
      detections.add(
        SoundDetectionResult(
          category: rule.category,
          yamnetClass: bestClass.isEmpty
              ? (_lastBestClass[rule.category] ?? rule.yamnetClasses.first)
              : bestClass,
          score: bestScore,
          confirmed: confirmed,
          vibrationPriority: rule.vibrationPriority,
          timestamp: now,
        ),
      );
    }

    detections.sort((a, b) {
      final p = b.vibrationPriority.compareTo(a.vibrationPriority);
      if (p != 0) return p;
      return b.score.compareTo(a.score);
    });

    return detections;
  }

  double getEma(String category) => _ema[category] ?? 0.0;

  void reset() {
    _ema.clear();
    _lastBestClass.clear();
  }
}
