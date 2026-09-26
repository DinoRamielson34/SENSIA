import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Bouton « home » qui se déplie en quatre raccourcis autour d'un bouton fermer.
class HomeMenu extends StatefulWidget {
  final VoidCallback? onAssociation;
  final VoidCallback? onHelp;
  final VoidCallback? onSettings;
  final VoidCallback? onBackup;

  const HomeMenu({
    super.key,
    this.onAssociation,
    this.onHelp,
    this.onSettings,
    this.onBackup,
  });

  /// Hauteur occupée par le menu déplié ; le bouton fermé reste centré dedans.
  static const height = 136.0;

  @override
  State<HomeMenu> createState() => _HomeMenuState();
}

class _HomeMenuState extends State<HomeMenu>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 250);
  static const _pillWidth = 116.0;
  static const _pillHeight = 60.0;
  static const _centerSize = 60.0;

  // Une pulsation (début du cycle) puis un temps de repos.
  static const _pulseCycle = Duration(milliseconds: 2400);
  static const _pulseWindow = 0.4;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: _pulseCycle,
  );

  bool _open = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Le bouton pulse tant que le menu est fermé, pour inviter à appuyer ;
  /// pas de pulsation si l'utilisateur a demandé de réduire les animations.
  void _syncPulse() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_open || reduceMotion) {
      _pulse
        ..stop()
        ..value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  void _setOpen(bool open) {
    setState(() => _open = open);
    _syncPulse();
  }

  void _toggle() => _setOpen(!_open);

  void _select(VoidCallback? callback) {
    callback?.call();
    _setOpen(false);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: HomeMenu.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final centerLeft = (width - _centerSize) / 2;
          final centerTop = (HomeMenu.height - _centerSize) / 2;

          // Position d'une pastille : dans son coin quand le menu est ouvert,
          // repliée derrière le bouton central sinon.
          Widget pill(
            String label,
            IconData icon,
            VoidCallback? onTap, {
            required bool left,
            required bool top,
          }) {
            final openLeft = left ? 0.0 : width - _pillWidth;
            final openTop = top ? 0.0 : HomeMenu.height - _pillHeight;
            return AnimatedPositioned(
              duration: _duration,
              curve: Curves.easeOutCubic,
              left: _open
                  ? openLeft
                  : centerLeft - (_pillWidth - _centerSize) / 2,
              top: _open ? openTop : centerTop,
              width: _pillWidth,
              height: _pillHeight,
              child: AnimatedOpacity(
                duration: _duration,
                opacity: _open ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !_open,
                  child: _Pill(
                    label: label,
                    icon: icon,
                    onTap: () => _select(onTap),
                  ),
                ),
              ),
            );
          }

          return Stack(
            children: [
              pill('Association', Icons.groups_outlined, widget.onAssociation, left: true, top: true),
              pill('Help', Icons.checklist, widget.onHelp, left: false, top: true),
              pill('Settings', Icons.settings_voice_outlined, widget.onSettings, left: true, top: false),
              pill('Sauvegarde', Icons.person_outline, widget.onBackup, left: false, top: false),
              Positioned(
                left: centerLeft,
                top: centerTop,
                width: _centerSize,
                height: _centerSize,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    // p va de 0 à 1 pendant la pulsation, puis reste à 1 (repos).
                    final p = (_pulse.value / _pulseWindow).clamp(0.0, 1.0);
                    final pulsing = _pulse.isAnimating && p < 1;
                    return Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        if (pulsing)
                          IgnorePointer(
                            child: Transform.scale(
                              scale: 1 + 0.6 * p,
                              child: Container(
                                width: _centerSize,
                                height: _centerSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary.withValues(
                                    alpha: 0.3 * (1 - p),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Transform.scale(
                          scale: pulsing ? 1 + 0.08 * math.sin(math.pi * p) : 1,
                          child: child,
                        ),
                      ],
                    );
                  },
                  child: _CenterButton(open: _open, onTap: _toggle),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _Pill({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 24, color: AppColors.onPrimary),
        ),
      ),
    );
  }
}

class _CenterButton extends StatelessWidget {
  final bool open;
  final VoidCallback onTap;

  const _CenterButton({required this.open, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: open ? 'Fermer le menu' : 'Accueil',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: open ? AppColors.onPrimary : AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(
              color: open ? AppColors.primary : AppColors.background,
            ),
          ),
          child: Icon(
            open ? Icons.close : Icons.home_outlined,
            size: open ? 30 : 24,
            color: open ? AppColors.text : AppColors.onPrimary,
          ),
        ),
      ),
    );
  }
}
