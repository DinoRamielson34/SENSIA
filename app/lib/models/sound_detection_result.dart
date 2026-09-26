class SoundDetectionResult {
  final String category;
  final String yamnetClass;
  final double score;
  final bool confirmed;
  final int vibrationPriority;
  final DateTime timestamp;

  const SoundDetectionResult({
    required this.category,
    required this.yamnetClass,
    required this.score,
    required this.confirmed,
    required this.vibrationPriority,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'category': category,
    'yamnetClass': yamnetClass,
    'score': double.parse(score.toStringAsFixed(2)),
    'confirmed': confirmed,
    'vibrationPriority': vibrationPriority,
    'timestamp': timestamp.toIso8601String(),
  };
}
