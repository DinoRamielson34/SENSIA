import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'config/sound_priority_config.dart';
import 'firebase_options.dart';
import 'haptics/haptic_engine.dart';
import 'haptics/segment_pattern.dart';
import 'haptics/vibration_executor.dart';
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
import 'services/sound_haptic_pipeline.dart';

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

  /// Pipeline partagé par tous les écrans ; créé par l'app s'il est absent.
  final SoundHapticPipeline? pipeline;

  const IzahayApp({super.key, this.profileRepository, this.pipeline});

  @override
  State<IzahayApp> createState() => _IzahayAppState();
}

class _IzahayAppState extends State<IzahayApp> with WidgetsBindingObserver {
  static final _knownCategories = {
    for (final rule in SoundPriorityConfig.rules) rule.category,
  };

  late final ProfileStore _profile;
  late final SoundHapticPipeline _pipeline;

  @override
  void initState() {
    super.initState();
    _pipeline =
        widget.pipeline ??
        SoundHapticPipeline(
          hapticEngine: HapticEngine(
            executor: const MethodChannelVibrationExecutor(),
          ),
        );
    _profile = ProfileStore(
      repository: widget.profileRepository,
      onRestored: _applyProfile,
    );
    // Restauration automatique de la dernière sauvegarde, sans message : sans
    // sauvegarde, sans réseau ou sans Firebase, l'app démarre avec ses
    // réglages par défaut.
    unawaited(_profile.restore());
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Une modification récente n'attend pas la fin du délai si l'app part.
    if (state == AppLifecycleState.paused) unawaited(_profile.flushPending());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _profile.dispose();
    if (widget.pipeline == null) _pipeline.dispose();
    super.dispose();
  }

  /// Réapplique au pipeline (donc à la détection réelle) les réglages et
  /// motifs d'une sauvegarde restaurée.
  void _applyProfile() {
    final profile = _profile.profile;
    for (final entry in profile.vibrationPatterns.entries) {
      if (_knownCategories.contains(entry.key) && entry.value.isNotEmpty) {
        _pipeline.setCategoryPattern(
          entry.key,
          patternFromSegments(entry.key, entry.value),
        );
      }
    }
    for (final entry in profile.settings.entries) {
      if (_knownCategories.contains(entry.key)) {
        _pipeline.setCategoryEnabled(entry.key, entry.value);
      }
    }
  }

  void _open(BuildContext context, WidgetBuilder builder) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
  }

  Widget _listening(BuildContext context) => ListeningScreen(
    pipeline: _pipeline,
    onAssociation: () => _open(context, (_) => const AssociationsScreen()),
    onHelp: () => _open(context, (_) => _settings()),
    onSettings: () => _open(context, _vibrations),
    onBackup: () => _open(context, (_) => BackupScreen(store: _profile)),
  );

  Widget _settings() => SettingsScreen(
    initialValues: {
      for (final category in _knownCategories)
        category: _pipeline.isCategoryEnabled(category),
    },
    onChanged: (id, value) {
      _pipeline.setCategoryEnabled(id, value);
      _profile.setSetting(id, value);
    },
  );

  Widget _vibrations(BuildContext context) => VibrationsScreen(
    onPattern: (entry) => _testVibration(context, entry),
    onSettings: (entry) => _open(context, (_) => _vibrationConfig(entry)),
  );

  Future<void> _testVibration(
    BuildContext context,
    VibrationEntry entry,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await _pipeline.testVibration(entry.id);
    final error = _pipeline.error;
    if (error != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Widget _vibrationConfig(VibrationEntry entry) {
    final saved = _profile.profile.vibrationPatterns[entry.id];
    final current = _pipeline.patternFor(entry.id);
    return VibrationConfigScreen(
      entry: entry,
      initialSegments:
          saved ??
          (current == null
              ? const <VibrationSegment>[]
              : segmentsFromPattern(current)),
      onValidate: (entry, segments) {
        _profile.setVibrationPattern(entry.id, segments);
        _pipeline.setCategoryPattern(
          entry.id,
          patternFromSegments(entry.id, segments),
        );
      },
    );
  }

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
