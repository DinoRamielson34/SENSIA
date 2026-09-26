import 'package:flutter/material.dart';

import '../config/haptic_pattern_config.dart';
import '../config/sound_priority_config.dart';
import '../haptics/haptic_engine.dart';
import '../haptics/vibration_executor.dart';
import '../services/sound_haptic_pipeline.dart';
import '../sound_events/sound_event_result.dart';

/// Écran principal : démarre/arrête l'écoute, affiche le dernier son
/// reconnu et le motif de vibration associé, et permet d'activer, tester
/// ou simuler chaque catégorie. Toute la logique est dans
/// [SoundHapticPipeline] ; cet écran ne fait qu'afficher son état.
class ListeningScreen extends StatefulWidget {
  /// Pipeline à utiliser. Créé par défaut (vibrations réelles) ; injecté
  /// uniquement dans les tests.
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
    // On ne détruit que le pipeline créé ici ; un pipeline injecté reste
    // sous la responsabilité de son propriétaire.
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
            _lastSoundCard(context),
            const SizedBox(height: 16),
            Text('Catégories',
                style: Theme.of(context).textTheme.titleMedium),
            for (final rule in SoundPriorityConfig.rules)
              _categoryTile(rule.category),
          ],
        ),
      ),
    );
  }

  /// Carte du haut : écoute active/inactive, boutons démarrer/arrêter et
  /// message d'erreur éventuel.
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
              label: Text(listening ? 'Arrêter l\'écoute' : 'Démarrer l\'écoute'),
            ),
            if (_pipeline.error != null) ...[
              const SizedBox(height: 8),
              Text(_pipeline.error!, style: TextStyle(color: scheme.error)),
            ],
          ],
        ),
      ),
    );
  }

  /// Carte « dernier son détecté » : catégorie, score, heure, motif de
  /// vibration, réel/simulé, et ce que le moteur en a fait.
  Widget _lastSoundCard(BuildContext context) {
    final result = _pipeline.lastResult;
    if (result == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Aucun son détecté pour le moment.'),
        ),
      );
    }
    final event = result.event;
    final pattern = _pipeline.patternFor(event.category);
    final t = event.timestamp;
    final time = '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dernier son : ${event.category}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Score : ${event.score.toStringAsFixed(2)}'),
            Text('Heure : $time'),
            Text('Vibration : '
                '${pattern == null ? '—' : HapticPatternConfig.describe(pattern)}'),
            Text('Origine : ${result.isSimulation ? 'SIMULÉ' : 'RÉEL'}'
                ' (${event.source})'),
            Text('Résultat : ${_statusLabel(result.status)}'),
          ],
        ),
      ),
    );
  }

  /// Ligne d'une catégorie : interrupteur d'activation, motif, et boutons
  /// « tester la vibration » et « simuler ce son ».
  Widget _categoryTile(String category) {
    final pattern = _pipeline.patternFor(category);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(category),
      subtitle: Text(
          pattern == null ? '—' : HapticPatternConfig.describe(pattern)),
      leading: Switch(
        value: _pipeline.isCategoryEnabled(category),
        onChanged: (v) => _pipeline.setCategoryEnabled(category, v),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Tester la vibration',
            icon: const Icon(Icons.vibration),
            onPressed: () => _pipeline.testVibration(category),
          ),
          IconButton(
            tooltip: 'Simuler ce son',
            icon: const Icon(Icons.science_outlined),
            onPressed: () => _pipeline.simulate(category, 0.95),
          ),
        ],
      ),
    );
  }

  /// Libellé français d'un statut de traitement. [status] : issue du
  /// processor. Retourne le texte affiché.
  String _statusLabel(SoundEventStatus status) => switch (status) {
        SoundEventStatus.triggered => 'vibration déclenchée',
        SoundEventStatus.unknownCategory => 'catégorie inconnue',
        SoundEventStatus.categoryDisabled => 'catégorie désactivée',
        SoundEventStatus.belowThreshold => 'score sous le seuil',
        SoundEventStatus.awaitingConfirmation => 'en attente de confirmation',
        SoundEventStatus.inCooldown => 'anti-répétition (trop récent)',
        SoundEventStatus.listeningStopped => 'écoute arrêtée',
        SoundEventStatus.hapticFailure => 'échec de la vibration',
        SoundEventStatus.superseded => 'remplacée par une autre vibration',
      };

  String _two(int n) => n.toString().padLeft(2, '0');
}
