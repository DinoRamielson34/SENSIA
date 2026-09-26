import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'haptics/haptic_engine.dart';
import 'haptics/vibration_executor.dart';
import 'history/firestore_history_repository.dart';
import 'history/history_result_sink.dart';
import 'simulation/event_simulator.dart';
import 'sound_events/sound_event.dart';
import 'sound_events/sound_event_processor.dart';

/// Point d'entrée séparé pour tester manuellement le pipeline complet
/// (traitement + vibrations + historique Firebase réel), sans
/// microphone ni IA.
///
/// Lancer avec : flutter run -t lib/simulation_debug_main.dart
///
/// Se connecte au vrai projet Firebase (voir lib/firebase_options.dart) :
/// un événement envoyé depuis cet écran écrit réellement dans Firestore
/// s'il déclenche une vibration (voir `HistoryResultSink`, qui
/// n'enregistre que les événements `triggered`).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final hapticEngine = HapticEngine(
    executor: const MethodChannelVibrationExecutor(),
  );
  final historyRepository = FirestoreHistoryRepository();
  final processor = SoundEventProcessor(
    hapticEngine: hapticEngine,
    historySink: HistoryResultSink(repository: historyRepository),
  );

  runApp(SimulationDebugApp(processor: processor));
}

/// Racine de l'écran de debug du simulateur.
///
/// Ne connaît que le [processor] réel du module de traitement des
/// événements : la liste des catégories affichées et le simulateur
/// utilisé pour les envoyer sont dérivés de ce même [processor] par
/// [SimulationDebugScreen], jamais fournis séparément — ça évite qu'une
/// liste codée en dur diverge un jour de la configuration réelle.
class SimulationDebugApp extends StatelessWidget {
  /// Le moteur de traitement à utiliser. Ses réglages
  /// (`processor.settings`) déterminent les catégories proposées dans
  /// l'écran.
  final SoundEventProcessor processor;

  const SimulationDebugApp({super.key, required this.processor});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IZAHAY — Test simulation',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: SimulationDebugScreen(processor: processor),
    );
  }
}

/// Écran technique minimal : choisir une catégorie parmi celles
/// réellement configurées sur [processor], définir un score, envoyer un
/// événement simulé, voir le résultat du traitement (déclenché ou non,
/// et pourquoi).
class SimulationDebugScreen extends StatefulWidget {
  final SoundEventProcessor processor;

  const SimulationDebugScreen({super.key, required this.processor});

  @override
  State<SimulationDebugScreen> createState() => _SimulationDebugScreenState();
}

class _SimulationDebugScreenState extends State<SimulationDebugScreen> {
  /// Construit une seule fois, sur le `processor` de ce widget : c'est
  /// cette même instance qui reçoit chaque événement envoyé, jamais un
  /// second circuit de traitement.
  late final EventSimulator _simulator = EventSimulator(
    processor: widget.processor,
  );

  /// Catégories réellement configurées sur `processor` au moment de
  /// l'affichage — jamais une liste figée : si une catégorie est
  /// ajoutée à `processor.settings` après coup (voir le test dédié),
  /// elle apparaît ici dès le prochain rebuild.
  List<String> get _knownCategories =>
      widget.processor.settings.all.keys.toList();

  late String _category = _knownCategories.isNotEmpty
      ? _knownCategories.first
      : 'sonnette';
  double _score = 0.9;
  String _status = '';

  /// Construit un événement simulé pour la catégorie/score actuellement
  /// sélectionnés et l'envoie via [_simulator]. Effets de bord : peut
  /// déclencher une vraie vibration et une vraie écriture Firestore
  /// (fire-and-forget, voir `SoundEventProcessor`/`HistorySink`) — ni
  /// l'une ni l'autre n'est visible directement dans `_status`, qui ne
  /// reflète que le résultat du TRAITEMENT (déclenché ou non). Toute
  /// exception inattendue (hors des exceptions métier typées, que
  /// `process()` ne lève jamais) est affichée plutôt que propagée, pour
  /// que l'écran reste utilisable même en cas de panne.
  Future<void> _send() async {
    try {
      final result = await _simulator.send(
        SoundEvent(
          category: _category,
          score: _score,
          timestamp: DateTime.now(),
          source: 'simulation',
          isSimulation: true,
        ),
      );
      setState(() {
        _status = result.reason != null
            ? '${result.status.name} — ${result.reason}'
            : result.status.name;
      });
    } catch (e) {
      setState(() => _status = 'Erreur : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _knownCategories;
    return Scaffold(
      appBar: AppBar(title: const Text('Test simulation')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButton<String>(
              value: categories.contains(_category)
                  ? _category
                  : (categories.isNotEmpty ? categories.first : null),
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            Slider(
              value: _score,
              onChanged: (value) => setState(() => _score = value),
              label: _score.toStringAsFixed(2),
            ),
            Text('Score : ${_score.toStringAsFixed(2)}'),
            FilledButton(onPressed: _send, child: const Text('Envoyer')),
            const SizedBox(height: 16),
            Text('Résultat : $_status'),
          ],
        ),
      ),
    );
  }
}
