import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'models/vibration_entry.dart';
import 'models/vibration_segment.dart';
import 'profile/firestore_profile_repository.dart';
import 'profile/profile_repository.dart';
import 'profile/profile_store.dart';
import 'screens/associations_screen.dart';
import 'screens/backup_screen.dart';
import 'screens/listening_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/vibration_config_screen.dart';
import 'screens/vibrations_screen.dart';
import 'screens/vision_problem_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ProfileRepository? profileRepository;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    profileRepository = FirestoreProfileRepository();
  } on Exception {
    // Sans Firebase l'app reste utilisable : la sauvegarde signale seulement
    // qu'elle est indisponible.
  }
  runApp(IzahayApp(profileRepository: profileRepository));
}

class IzahayApp extends StatefulWidget {
  /// Dépôt du profil ; null quand Firebase n'est pas disponible (et en test).
  final ProfileRepository? profileRepository;

  const IzahayApp({super.key, this.profileRepository});

  @override
  State<IzahayApp> createState() => _IzahayAppState();
}

class _IzahayAppState extends State<IzahayApp> {
  late final ProfileStore _profile;

  @override
  void initState() {
    super.initState();
    _profile = ProfileStore(repository: widget.profileRepository);
  }

  @override
  void dispose() {
    _profile.dispose();
    super.dispose();
  }

  void _open(BuildContext context, WidgetBuilder builder) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
  }

  Widget _listening(BuildContext context) => ListeningScreen(
    onAssociation: () => _open(context, (_) => const AssociationsScreen()),
    onHelp: () => _open(
      context,
      (_) => SettingsScreen(
        initialValues: _profile.profile.settings,
        onChanged: _profile.setSetting,
      ),
    ),
    onSettings: () => _open(context, _vibrations),
    onBackup: () => _open(context, (_) => BackupScreen(store: _profile)),
  );

  Widget _vibrations(BuildContext context) => VibrationsScreen(
    onSettings: (entry) => _open(context, (_) => _vibrationConfig(entry)),
  );

  Widget _vibrationConfig(VibrationEntry entry) => VibrationConfigScreen(
    entry: entry,
    initialSegments:
        _profile.profile.vibrationPatterns[entry.id] ??
        const <VibrationSegment>[],
    onValidate: (entry, segments) =>
        _profile.setVibrationPattern(entry.id, segments),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SENSIA',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: Builder(
        builder: (context) => RoleSelectionScreen(
          onContinue: (role) {
            _profile.setRole(role);
            _open(
              context,
              (context) => VisionProblemScreen(
                // TODO: remplacer par la suite du parcours quand elle existera.
                onContinue: (type) {
                  _profile.setColorVision(type);
                  _open(context, _listening);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Écran placeholder (compteur de taps), conservé pour le test widget.
class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IZAHAY')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone_android, size: 72),
            const SizedBox(height: 16),
            const Text(
              'Application de test IZAHAY',
              style: TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 12),
            Text('Bouton pressé : $_taps fois'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => setState(() => _taps++),
              child: const Text('Tester'),
            ),
          ],
        ),
      ),
    );
  }
}
