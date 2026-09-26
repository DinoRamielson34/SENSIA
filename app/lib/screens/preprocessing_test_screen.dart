import 'package:flutter/material.dart';
import '../models/audio_frame.dart';
import '../services/audio_preprocessing_service.dart';

class PreprocessingTestScreen extends StatefulWidget {
  const PreprocessingTestScreen({super.key});

  @override
  State<PreprocessingTestScreen> createState() =>
      _PreprocessingTestScreenState();
}

class _PreprocessingTestScreenState extends State<PreprocessingTestScreen> {
  final AudioPreprocessingService _service = AudioPreprocessingService();
  AudioPreprocessingStats _stats = const AudioPreprocessingStats();
  bool _isActive = false;
  String _statusMessage = 'Microphone arrêté';
  AudioFrame? _lastFrame;

  Future<void> _start() async {
    final granted = await _service.requestPermission();
    if (!granted) {
      setState(() => _statusMessage = 'Permission microphone refusée');
      return;
    }

    final started = await _service.start(
      onFrame: (frame) {
        if (mounted) {
          setState(() => _lastFrame = frame);
        }
      },
      onStats: (stats) {
        if (mounted) {
          setState(() => _stats = stats);
        }
      },
    );

    if (started) {
      setState(() {
        _isActive = true;
        _statusMessage = 'Microphone actif';
      });
    }
  }

  Future<void> _stop() async {
    await _service.stop();
    setState(() {
      _isActive = false;
      _statusMessage = 'Microphone arrêté';
      _stats = const AudioPreprocessingStats();
      _lastFrame = null;
    });
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('SENSIA')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.graphic_eq,
              size: 64,
              color: _isActive ? Colors.green : null,
            ),
            const SizedBox(height: 12),
            const Text(
              'AUDIO PREPROCESSING TEST',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _isActive ? null : _start,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('DÉMARRER'),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _isActive ? _stop : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('ARRÊTER'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRow('État microphone',
                        _isActive ? 'ACTIF' : 'ARRÊTÉ', _isActive),
                    const Divider(),
                    _buildRow('Format', 'PCM 16-bit', _isActive),
                    const Divider(),
                    _buildRow('Canaux', '1 (Mono)', _isActive),
                    const Divider(),
                    _buildRow('Sample rate',
                        '${AudioPreprocessingService.targetSampleRate} Hz', _isActive),
                    const Divider(),
                    _buildRow('Samples reçus',
                        '${_stats.totalSamplesReceived}', _isActive),
                    const Divider(),
                    _buildRow('Buffer',
                        '${_stats.bufferSampleCount} / ${AudioPreprocessingService.samplesPerFrame}',
                        _isActive),
                    const Divider(),
                    _buildRow(
                      'Buffer status',
                      _stats.bufferReady ? 'READY' : 'FILLING...',
                      _isActive,
                      valueColor: _stats.bufferReady
                          ? Colors.green
                          : Colors.orange,
                    ),
                    const Divider(),
                    _buildRow('Frames produits',
                        '${_stats.framesProduced}', _isActive),
                  ],
                ),
              ),
            ),
            if (_lastFrame != null) ...[
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dernier frame',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                          'Samples : ${_lastFrame!.sampleCount}'),
                      Text(
                          'Durée : ${_lastFrame!.durationSeconds.toStringAsFixed(2)} s'),
                      Text(
                          'Sample rate : ${_lastFrame!.sampleRate} Hz'),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, bool active,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor ?? (active ? Colors.green : Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
