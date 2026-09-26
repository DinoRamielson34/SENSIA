import 'package:flutter/material.dart';

import '../haptics/haptic_engine.dart';
import '../haptics/vibration_executor.dart';
import '../services/sound_haptic_pipeline.dart';
import '../theme/app_theme.dart';
import '../widgets/home_menu.dart';

/// Écran principal : démarre / arrête l'écoute du pipeline son → haptique.
class ListeningScreen extends StatefulWidget {
  final SoundHapticPipeline? pipeline;

  /// Raccourcis du menu déplié par le bouton « home ».
  // TODO: brancher les destinations (maquette 125:220).
  final VoidCallback? onAssociation;
  final VoidCallback? onHelp;
  final VoidCallback? onSettings;
  final VoidCallback? onBackup;

  const ListeningScreen({
    super.key,
    this.pipeline,
    this.onAssociation,
    this.onHelp,
    this.onSettings,
    this.onBackup,
  });

  @override
  State<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen> {
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
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 28),
                _StatusBar(
                  errorActive: _pipeline.error != null,
                  listening: _pipeline.isListening,
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _ToolBar(),
                    const SizedBox(width: 20),
                    _PlayButton(
                      listening: _pipeline.isListening,
                      loading: _pipeline.modelLoading,
                      onPressed: !_pipeline.modelReady
                          ? null
                          : _pipeline.isListening
                          ? _pipeline.stop
                          : _pipeline.start,
                    ),
                  ],
                ),
                if (_pipeline.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _pipeline.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const Spacer(),
                HomeMenu(
                  onAssociation: widget.onAssociation,
                  onHelp: widget.onHelp,
                  onSettings: widget.onSettings,
                  onBackup: widget.onBackup,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bandeau sombre : quatre indicateurs, éteints tant qu'il n'y a rien à signaler.
class _StatusBar extends StatelessWidget {
  final bool errorActive;
  final bool listening;

  const _StatusBar({required this.errorActive, required this.listening});

  @override
  Widget build(BuildContext context) {
    // TODO: brancher wifi/synchro quand une source de connectivité existera.
    Color color(bool on) =>
        on ? AppColors.statusIconOn : AppColors.statusIconOff;
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.statusBar,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(Icons.wifi_off, size: 30, color: color(false)),
          Icon(Icons.sync_disabled, size: 30, color: color(false)),
          Icon(
            Icons.warning_amber_rounded,
            size: 30,
            color: color(errorActive),
          ),
          Icon(Icons.graphic_eq, size: 30, color: color(listening)),
        ],
      ),
    );
  }
}

/// Colonne de raccourcis (wifi, synchro, son, bluetooth).
class _ToolBar extends StatelessWidget {
  const _ToolBar();

  @override
  Widget build(BuildContext context) {
    // TODO: relier chaque raccourci à son réglage quand il existera.
    const icons = [Icons.wifi, Icons.sync, Icons.graphic_eq, Icons.bluetooth];
    return Container(
      width: 50,
      height: 322,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final icon in icons)
            SizedBox(
              height: 50,
              child: Icon(icon, size: 30, color: Colors.black),
            ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool listening;
  final bool loading;
  final VoidCallback? onPressed;

  const _PlayButton({
    required this.listening,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: listening ? 'Arrêter l\'écoute' : 'Démarrer l\'écoute',
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: loading
                ? const CircularProgressIndicator(color: AppColors.primary)
                : Icon(
                    listening ? Icons.stop_rounded : Icons.play_arrow_outlined,
                    size: 60,
                    color: onPressed == null
                        ? AppColors.disabled
                        : Colors.black,
                  ),
          ),
        ),
      ),
    );
  }
}
