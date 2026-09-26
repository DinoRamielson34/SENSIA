import 'package:flutter/material.dart';

import '../config/haptic_pattern_config.dart';
import '../config/sound_priority_config.dart';
import '../haptics/haptic_engine.dart';
import '../haptics/vibration_executor.dart';
import '../services/sound_haptic_pipeline.dart';
import '../sound_events/sound_event_result.dart';

class ListeningScreen extends StatefulWidget {
  final SoundHapticPipeline? pipeline;

  const ListeningScreen({super.key, this.pipeline});

  @override
  State<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen> {
  late final SoundHapticPipeline _pipeline;

  @override
  void initState() {
    super.initState();
    _pipeline = widget.pipeline ??
        SoundHapticPipeline(
          hapticEngine: HapticEngine(
            executor: const MethodChannelVibrationExecutor(),
          ),
        );
    _pipeline.loadModel();
  }

  @override
  void dispose() {
    if (widget.pipeline == null) _pipeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _pipeline,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('SENSIA')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _statusCard(context),
            const SizedBox(height: 12),
            if (_pipeline.error != null) ...[
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_pipeline.error!,
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onErrorContainer,
                          fontSize: 11)),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text('Catégories — scores en direct',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final rule in SoundPriorityConfig.rules)
              _categoryScoreCard(rule, context),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(BuildContext context) {
    final listening = _pipeline.isListening;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.hearing,
                size: 48, color: listening ? Colors.green : scheme.outline),
            const SizedBox(height: 4),
            Text(
              _pipeline.modelLoading
                  ? 'Chargement du modèle…'
                  : listening
                      ? 'Écoute active'
                      : 'Écoute inactive',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: !_pipeline.modelReady
                  ? null
                  : listening
                      ? _pipeline.stop
                      : _pipeline.start,
              icon: Icon(listening ? Icons.stop : Icons.play_arrow),
              label:
                  Text(listening ? 'Arrêter l\'écoute' : 'Démarrer l\'écoute'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryScoreCard(SoundRule rule, BuildContext context) {
    final ema = _pipeline.getEma(rule.category);
    final pct = (ema * 100).clamp(0, 100).toInt();
    final confirmed = ema >= rule.threshold;
    final color = _priorityColor(rule.vibrationPriority);
    final icon = _categoryIcon(rule.category);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: confirmed
            ? BorderSide(color: color, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon,
                size: 28,
                color: confirmed ? color : Colors.grey.shade400),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(rule.category,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: confirmed ? null : Colors.grey,
                          )),
                      const Spacer(),
                      Text('P${rule.vibrationPriority}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: color)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 48,
                        child: Text('$pct%',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: confirmed ? color : Colors.grey,
                            )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: ema.clamp(0.0, 1.0),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                    color: confirmed ? color : Colors.grey.shade300,
                    backgroundColor: Colors.grey.shade200,
                  ),
                ],
              ),
            ),
          ],
        ),
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
