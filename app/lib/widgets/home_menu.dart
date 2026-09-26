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

class _HomeMenuState extends State<HomeMenu> {
  static const _duration = Duration(milliseconds: 250);
  static const _pillWidth = 116.0;
  static const _pillHeight = 60.0;
  static const _centerSize = 60.0;

  bool _open = false;

  void _toggle() => setState(() => _open = !_open);

  void _select(VoidCallback? callback) {
    callback?.call();
    setState(() => _open = false);
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
                  child: _Pill(label: label, onTap: () => _select(onTap)),
                ),
              ),
            );
          }

          return Stack(
            children: [
              pill('Association', widget.onAssociation, left: true, top: true),
              pill('Help', widget.onHelp, left: false, top: true),
              pill('Settings', widget.onSettings, left: true, top: false),
              pill('Sauvegarde', widget.onBackup, left: false, top: false),
              Positioned(
                left: centerLeft,
                top: centerTop,
                child: _CenterButton(open: _open, onTap: _toggle),
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
  final VoidCallback onTap;

  const _Pill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.fingerprint,
                size: 30,
                color: AppColors.onPrimary,
              ),
            ],
          ),
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
