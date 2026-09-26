import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/audio_frame.dart';
import '../models/sound_detection_result.dart';
import '../services/audio_preprocessing_service.dart';
import '../services/yamnet_service.dart';
import '../services/sound_filter_service.dart';

class DetectionTestScreen extends StatefulWidget {
  const DetectionTestScreen({super.key});

  @override
  State<DetectionTestScreen> createState() => _DetectionTestScreenState();
}

class _DetectionTestScreenState extends State<DetectionTestScreen> {
  final AudioPreprocessingService _audioService = AudioPreprocessingService();
  final YamnetService _yamnetService = YamnetService();
  final SoundFilterService _filterService = SoundFilterService();

  bool _isActive = false;
  bool _modelLoading = true;
  List<SoundDetectionResult> _detections = [];
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
      setState(() => _lastError = 'Modele non charge');
      return;
    }

    final granted = await _audioService.requestPermission();
    if (!granted) {
      setState(() => _lastError = 'Permission microphone refusee');
      return;
    }

    _filterService.reset();

    final started = await _audioService.start(onFrame: _onAudioFrame);

    if (started) {
      setState(() {
        _isActive = true;
        _lastError = null;
        _inferenceCount = 0;
        _detections = [];
      });
    }
  }

  void _onAudioFrame(AudioFrame frame) {
    final yamnetResults = _yamnetService.classify(frame);
    if (yamnetResults.isEmpty) {
      if (mounted) setState(() => _lastError = _yamnetService.error);
      return;
    }

    final detections = _filterService.processResults(yamnetResults);
    if (mounted) {
      setState(() {
        _detections = detections;
        _inferenceCount++;
        _lastError = null;
      });
    }
  }

  Future<void> _stop() async {
    await _audioService.stop();
    setState(() => _isActive = false);
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
    final maxPriority =
        _detections.isEmpty ? 0 : _detections.first.vibrationPriority;

    return Scaffold(
      appBar: AppBar(title: const Text('SENSIA')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.hearing,
              size: 48,
              color: _isActive ? Colors.green : null,
            ),
            const SizedBox(height: 4),
            const Text(
              'DETECTION TEST',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  children: [
                    _row('Modele',
                        _modelLoading
                            ? 'CHARGEMENT...'
                            : _yamnetService.isLoaded
                                ? 'OK'
                                : 'ERREUR',
                        _yamnetService.isLoaded
                            ? Colors.green
                            : _modelLoading
                                ? Colors.orange
                                : Colors.red),
                    if (_isActive) ...[
                      const Divider(),
                      _row('Inferences', '$_inferenceCount', null),
                      const Divider(),
                      _row('Detectees', '${_detections.length}', null),
                      if (_detections.isNotEmpty) ...[
                        const Divider(),
                        _row('Priorite max', '$maxPriority',
                            _priorityColor(maxPriority)),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed:
                      _isActive || !_yamnetService.isLoaded ? null : _start,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('DEMARRER'),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _isActive ? _stop : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('ARRETER'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Error
            if (_lastError != null)
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(_lastError!,
                      style:
                          TextStyle(color: theme.colorScheme.onErrorContainer)),
                ),
              ),

            // Detections
            if (_detections.isNotEmpty) ...[
              Text('Detections',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ..._detections.map((d) => _detectionCard(d, theme)),
            ],

            // JSON output
            if (_detections.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Sortie JSON',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ')
                        .convert(
                            _detections.map((d) => d.toJson()).toList()),
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detectionCard(SoundDetectionResult d, ThemeData theme) {
    final icon = _categoryIcon(d.category);
    final color = _priorityColor(d.vibrationPriority);
    final ema = _filterService.getEma(d.category);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.category,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text('YAMNet : ${d.yamnetClass}',
                      style: TextStyle(
                          fontSize: 12, color: theme.colorScheme.outline)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: ema.clamp(0.0, 1.0),
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(5),
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ema.toStringAsFixed(2),
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'score brut : ${d.score.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 11, color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text('P${d.vibrationPriority}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, Color? color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value,
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  static IconData _categoryIcon(String category) {
    return switch (category) {
      'train' => Icons.train,
      'fire_alarm' => Icons.local_fire_department,
      'smoke_alarm' => Icons.warning,
      'car_horn' => Icons.directions_car,
      'emergency_siren' => Icons.emergency,
      'car_alarm' => Icons.car_crash,
      'baby_cry' => Icons.child_care,
      'alarm' => Icons.notification_important,
      'doorbell' => Icons.doorbell,
      'door_knock' => Icons.meeting_room,
      'telephone' => Icons.phone,
      'alarm_clock' => Icons.alarm,
      'dog_bark' => Icons.pets,
      _ => Icons.volume_up,
    };
  }

  static Color _priorityColor(int priority) {
    return switch (priority) {
      5 => Colors.red,
      4 => Colors.deepOrange,
      3 => Colors.orange,
      2 => Colors.amber.shade700,
      1 => Colors.blue,
      _ => Colors.grey,
    };
  }
}
