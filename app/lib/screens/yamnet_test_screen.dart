import 'package:flutter/material.dart';
import '../models/audio_frame.dart';
import '../services/audio_preprocessing_service.dart';
import '../services/yamnet_service.dart';

class YamnetTestScreen extends StatefulWidget {
  const YamnetTestScreen({super.key});

  @override
  State<YamnetTestScreen> createState() => _YamnetTestScreenState();
}

class _YamnetTestScreenState extends State<YamnetTestScreen> {
  final AudioPreprocessingService _audioService = AudioPreprocessingService();
  final YamnetService _yamnetService = YamnetService();

  bool _isActive = false;
  bool _modelLoading = true;
  List<YamnetResult> _topResults = [];
  int _inferenceCount = 0;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    await _yamnetService.loadModel();
    if (mounted) {
      setState(() {
        _modelLoading = false;
        _lastError = _yamnetService.error;
      });
    }
  }

  Future<void> _start() async {
    if (!_yamnetService.isLoaded) {
      setState(() => _lastError = 'Modèle non chargé');
      return;
    }

    final granted = await _audioService.requestPermission();
    if (!granted) {
      setState(() => _lastError = 'Permission microphone refusée');
      return;
    }

    final started = await _audioService.start(
      onFrame: _onAudioFrame,
    );

    if (started) {
      setState(() {
        _isActive = true;
        _lastError = null;
        _inferenceCount = 0;
        _topResults = [];
      });
    }
  }

  void _onAudioFrame(AudioFrame frame) {
    final results = _yamnetService.classify(frame);
    if (mounted) {
      setState(() {
        if (results.isNotEmpty) {
          _topResults = results.take(5).toList();
          _inferenceCount++;
          _lastError = null;
        } else {
          _lastError = _yamnetService.error;
        }
      });
    }
  }

  Future<void> _stop() async {
    await _audioService.stop();
    setState(() {
      _isActive = false;
    });
  }

  @override
  void dispose() {
    _audioService.dispose();
    _yamnetService.dispose();
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.hearing,
              size: 56,
              color: _isActive ? Colors.green : null,
            ),
            const SizedBox(height: 8),
            const Text(
              'YAMNET TEST',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Model status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _statusRow(
                      'Model loaded',
                      _modelLoading
                          ? 'LOADING...'
                          : _yamnetService.isLoaded
                              ? 'YES'
                              : 'NO',
                      _yamnetService.isLoaded
                          ? Colors.green
                          : _modelLoading
                              ? Colors.orange
                              : Colors.red,
                    ),
                    if (_yamnetService.isLoaded) ...[
                      const Divider(),
                      _statusRow('Labels', '${_yamnetService.labelCount}', null),
                      const Divider(),
                      _statusRow('Input shape',
                          '${_yamnetService.inputShape}', null),
                      const Divider(),
                      _statusRow('Output shape',
                          '${_yamnetService.outputShape}', null),
                    ],
                    if (_isActive) ...[
                      const Divider(),
                      _statusRow('Inferences', '$_inferenceCount', null),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed:
                      _isActive || !_yamnetService.isLoaded ? null : _start,
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
            const SizedBox(height: 20),

            // Error display
            if (_lastError != null)
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    _lastError!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ),

            // Results
            if (_topResults.isNotEmpty) ...[
              Text(
                'Top results :',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: _topResults.map((r) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                r.label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 4,
                              child: LinearProgressIndicator(
                                value: r.score.clamp(0.0, 1.0),
                                minHeight: 14,
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 48,
                              child: Text(
                                r.score.toStringAsFixed(2),
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusRow(String label, String value, Color? valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
