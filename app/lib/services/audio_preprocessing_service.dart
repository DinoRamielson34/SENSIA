import 'dart:async';
import 'dart:typed_data';
import '../models/audio_frame.dart';
import 'audio_capture_service.dart';

class AudioPreprocessingStats {
  final bool isActive;
  final int totalSamplesReceived;
  final int bufferSampleCount;
  final int framesProduced;
  final bool bufferReady;

  const AudioPreprocessingStats({
    this.isActive = false,
    this.totalSamplesReceived = 0,
    this.bufferSampleCount = 0,
    this.framesProduced = 0,
    this.bufferReady = false,
  });
}

class AudioPreprocessingService {
  final AudioCaptureService _captureService = AudioCaptureService();

  static const int targetSampleRate = 16000;
  static const int targetChannels = 1;
  static const int samplesPerFrame = 15600;
  static const int hopSize = 4000;
  static const int maxBufferSamples = samplesPerFrame * 2;

  final List<double> _buffer = [];
  int _totalSamplesReceived = 0;
  int _framesProduced = 0;

  void Function(AudioFrame frame)? _onFrame;
  void Function(AudioPreprocessingStats stats)? _onStats;

  AudioPreprocessingStats get stats => AudioPreprocessingStats(
    isActive: _captureService.isRecording,
    totalSamplesReceived: _totalSamplesReceived,
    bufferSampleCount: _buffer.length,
    framesProduced: _framesProduced,
    bufferReady: _buffer.length >= samplesPerFrame,
  );

  Future<bool> requestPermission() => _captureService.requestPermission();

  Future<bool> start({
    required void Function(AudioFrame frame) onFrame,
    void Function(AudioPreprocessingStats stats)? onStats,
  }) async {
    _onFrame = onFrame;
    _onStats = onStats;
    _buffer.clear();
    _totalSamplesReceived = 0;
    _framesProduced = 0;

    final started = await _captureService.startCapture(
      onRawData: _processRawData,
    );

    if (started) {
      _notifyStats();
    }
    return started;
  }

  void _processRawData(Uint8List rawBytes) {
    final samples = _pcm16BytesToSamples(rawBytes);
    _totalSamplesReceived += samples.length;

    _buffer.addAll(samples);

    if (_buffer.length > maxBufferSamples) {
      _buffer.removeRange(0, _buffer.length - maxBufferSamples);
    }

    while (_buffer.length >= samplesPerFrame) {
      final frameSamples = Float32List(samplesPerFrame);
      for (int i = 0; i < samplesPerFrame; i++) {
        frameSamples[i] = _buffer[i];
      }
      _buffer.removeRange(0, hopSize);

      _framesProduced++;
      _onFrame?.call(
        AudioFrame(
          samples: frameSamples,
          sampleRate: targetSampleRate,
          numChannels: targetChannels,
        ),
      );
    }

    _notifyStats();
  }

  List<double> _pcm16BytesToSamples(Uint8List bytes) {
    final byteData = ByteData.sublistView(bytes);
    final sampleCount = bytes.length ~/ 2;
    final samples = List<double>.filled(sampleCount, 0.0);
    for (int i = 0; i < sampleCount; i++) {
      final int16 = byteData.getInt16(i * 2, Endian.little);
      samples[i] = int16 / 32768.0;
    }
    return samples;
  }

  void _notifyStats() {
    _onStats?.call(stats);
  }

  Future<void> stop() async {
    await _captureService.stopCapture();
    _buffer.clear();
    _totalSamplesReceived = 0;
    _framesProduced = 0;
    _onFrame = null;
    _onStats = null;
  }

  Future<void> dispose() async {
    await stop();
    await _captureService.dispose();
  }
}
