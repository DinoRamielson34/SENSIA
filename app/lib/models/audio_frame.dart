import 'dart:typed_data';

class AudioFrame {
  final Float32List samples;
  final int sampleRate;
  final int numChannels;

  const AudioFrame({
    required this.samples,
    required this.sampleRate,
    required this.numChannels,
  });

  int get sampleCount => samples.length;
  double get durationSeconds => sampleCount / sampleRate;
}
