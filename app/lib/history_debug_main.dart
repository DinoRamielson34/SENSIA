import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'history/firestore_history_repository.dart';
import 'history/history_repository.dart';
import 'history/models/sound_event_record.dart';
import 'sound_events/sound_event.dart';

/// Point d'entrée séparé pour tester manuellement le module historique
/// (enregistrement, lecture, effacement), sans dépendre du reste de
/// l'application.
///
/// Lancer avec : flutter run -t lib/history_debug_main.dart
/// Se connecte au vrai projet Firebase "izahay-703fd" (voir
/// lib/firebase_options.dart et android/app/google-services.json) —
/// pas l'émulateur local. Écrit de vraies données dans ce projet.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(HistoryDebugApp(repository: FirestoreHistoryRepository()));
}

class HistoryDebugApp extends StatelessWidget {
  final HistoryRepository repository;

  const HistoryDebugApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IZAHAY — Test historique',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: HistoryDebugScreen(repository: repository),
    );
  }
}

class HistoryDebugScreen extends StatefulWidget {
  final HistoryRepository repository;

  const HistoryDebugScreen({super.key, required this.repository});

  @override
  State<HistoryDebugScreen> createState() => _HistoryDebugScreenState();
}

class _HistoryDebugScreenState extends State<HistoryDebugScreen> {
  List<SoundEventRecord> _events = [];
  String _status = '';

  Future<void> _addTestEvent() async {
    final id = widget.repository.newEventId();
    await widget.repository.saveEvent(
      SoundEventRecord(
        id: id,
        event: SoundEvent(
          category: 'sonnette',
          score: 0.9,
          timestamp: DateTime.now(),
          source: 'simulation',
          isSimulation: true,
        ),
      ),
    );
    setState(() => _status = 'Événement ajouté ($id)');
    await _refresh();
  }

  Future<void> _refresh() async {
    final events = await widget.repository.fetchEvents();
    setState(() => _events = events);
  }

  Future<void> _clear() async {
    await widget.repository.clearHistory();
    setState(() => _status = 'Historique effacé');
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test historique')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: _addTestEvent,
                  child: const Text('Ajouter un événement de test'),
                ),
                OutlinedButton(
                  onPressed: _refresh,
                  child: const Text('Rafraîchir'),
                ),
                OutlinedButton(onPressed: _clear, child: const Text('Effacer')),
              ],
            ),
          ),
          Text(_status),
          Expanded(
            child: ListView.builder(
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final record = _events[index];
                return ListTile(
                  title: Text(record.event.category),
                  subtitle: Text('${record.event.timestamp} — ${record.id}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
