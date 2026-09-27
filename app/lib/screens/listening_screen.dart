import 'package:flutter/material.dart';

import '../haptics/haptic_engine.dart';
import '../haptics/vibration_executor.dart';
import '../services/sound_haptic_pipeline.dart';
import '../sound_events/sound_event_result.dart';
import '../theme/app_theme.dart';
import '../tutorial/tutorial_controller.dart';
import '../tutorial/tutorial_scope.dart';
import '../widgets/home_menu.dart';
import '../widgets/wave_decor.dart';

/// Écran principal : démarre / arrête l'écoute du pipeline son → haptique.
class ListeningScreen extends StatefulWidget {
  final SoundHapticPipeline? pipeline;

  /// Raccourcis du menu déplié par le bouton « home ».
  // TODO: brancher les destinations (maquette 125:220).
  final VoidCallback? onAssociation;
  final VoidCallback? onHelp;
  final VoidCallback? onSettings;
  final VoidCallback? onBackup;

  /// Tutoriel de l'écran (spotlight + bulles) ; null = pas de tutoriel.
  final TutorialController? tutorial;

  /// Ouverture du menu « home », pilotée par le tutoriel.
  final ValueNotifier<bool>? menuOpen;

  const ListeningScreen({
    super.key,
    this.pipeline,
    this.onAssociation,
    this.onHelp,
    this.onSettings,
    this.onBackup,
    this.tutorial,
    this.menuOpen,
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
    widget.tutorial?.addListener(_closeMenuWhenTutorialEnds);
    // Premier(s) lancement(s) : le tutoriel se propose une fois l'écran dessiné.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.tutorial?.startIfNeeded(),
    );
  }

  /// Referme le menu que le tutoriel a ouvert quand il se termine.
  void _closeMenuWhenTutorialEnds() {
    if (widget.tutorial?.isActive == false) widget.menuOpen?.value = false;
  }

  Widget _target(String id, Widget child) =>
      widget.tutorial?.target(id, child) ?? child;

  @override
  void dispose() {
    widget.tutorial?.removeListener(_closeMenuWhenTutorialEnds);
    if (widget.pipeline == null) _pipeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _pipeline,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              const Positioned.fill(child: WaveDecor()),
              SafeArea(
                child: LayoutBuilder(
                  // Défilement de secours : le contenu (≈780 px) dépasse les petits écrans.
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(child: _buildContent(context)),
                    ),
                  ),
                ),
              ),
              if (widget.tutorial != null)
                Positioned.fill(
                  child: TutorialScope(controller: widget.tutorial!),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    final error = _pipeline.error;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 78),
          const _ToolBar(),
          const SizedBox(height: 23),
          _target(
            'play',
            _PlayButton(
              listening: _pipeline.isListening,
              loading: _pipeline.modelLoading,
              onPressed: !_pipeline.modelReady
                  ? null
                  : _pipeline.isListening
                  ? _pipeline.stop
                  : _pipeline.start,
            ),
          ),
          const SizedBox(height: 66),
          _target('lastSound', _SoundCard(result: _pipeline.lastTriggered)),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          const Spacer(),
          HomeMenu(
            onAssociation: widget.onAssociation,
            onHelp: widget.onHelp,
            onSettings: widget.onSettings,
            onBackup: widget.onBackup,
            openNotifier: widget.menuOpen,
            targetBuilder: widget.tutorial?.target,
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

/// Barre de raccourcis horizontale (wifi, synchro, son, bluetooth).
class _ToolBar extends StatelessWidget {
  const _ToolBar();

  @override
  Widget build(BuildContext context) {
    // TODO: relier chaque raccourci à son réglage quand il existera.
    const icons = [
      (Icons.wifi, 48.0),
      (Icons.sync, 50.0),
      (Icons.graphic_eq, 50.0),
      (Icons.bluetooth, 48.0),
    ];
    return Container(
      width: 320,
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final (icon, width) in icons)
            SizedBox(
              width: width,
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
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.hover),
            boxShadow: const [
              BoxShadow(color: AppColors.hover, offset: Offset(4, 4)),
            ],
          ),
          child: Center(
            child: loading
                ? const CircularProgressIndicator(color: AppColors.background)
                : Icon(
                    listening ? Icons.stop_rounded : Icons.play_arrow_outlined,
                    size: 60,
                    color: onPressed == null
                        ? AppColors.disabled
                        : AppColors.background,
                  ),
          ),
        ),
      ),
    );
  }
}

const _categoryIcons = <String, IconData>{
  'train': Icons.train,
  'fire_alarm': Icons.local_fire_department,
  'smoke_alarm': Icons.warning_amber,
  'car_horn': Icons.directions_car,
  'emergency_siren': Icons.emergency,
  'car_alarm': Icons.car_crash,
  'baby_cry': Icons.child_care,
  'alarm': Icons.notification_important,
  'doorbell': Icons.doorbell,
  'door_knock': Icons.door_front_door,
  'telephone': Icons.phone_in_talk,
  'alarm_clock': Icons.alarm,
  'dog_bark': Icons.pets,
};

const _categoryLabels = <String, String>{
  'train': 'Train',
  'fire_alarm': 'Alarme incendie',
  'smoke_alarm': 'Détecteur de fumée',
  'car_horn': 'Klaxon',
  'emergency_siren': 'Sirène d\'urgence',
  'car_alarm': 'Alarme voiture',
  'baby_cry': 'Pleurs de bébé',
  'alarm': 'Alarme',
  'doorbell': 'Sonnette',
  'door_knock': 'Frappe à la porte',
  'telephone': 'Téléphone',
  'alarm_clock': 'Réveil',
  'dog_bark': 'Aboiement',
};

/// Carte du dernier son détecté.
class _SoundCard extends StatelessWidget {
  final SoundEventResult? result;

  const _SoundCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final category = result?.event.category;
    final icon = category == null
        ? null
        : _categoryIcons[category] ?? Icons.volume_up;
    final label = category == null
        ? 'Aucun son'
        : _categoryLabels[category] ?? category;
    return Container(
      width: 150,
      height: 70,
      decoration: BoxDecoration(
        color: AppColors.hover,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.primary),
        boxShadow: const [
          BoxShadow(color: AppColors.primary, offset: Offset(4, 4)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 6,
            top: 10,
            width: 144,
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: icon == null
                      ? null
                      : Icon(icon, size: 24, color: Colors.black),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
