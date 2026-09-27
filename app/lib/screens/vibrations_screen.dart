import 'package:flutter/material.dart';

import '../config/vibration_entries.dart';
import '../models/vibration_entry.dart';
import '../theme/app_theme.dart';
import '../widgets/home_button.dart';
import '../widgets/wave_decor.dart';

class VibrationsScreen extends StatelessWidget {
  /// Sons à afficher ; par défaut, toutes les catégories reconnues.
  final List<VibrationEntry>? entries;

  /// Bouton « ondes » d'une carte : fait vibrer le motif actuel du son.
  final void Function(VibrationEntry entry)? onPattern;

  /// Bouton « engrenage » d'une carte : réglage détaillé du motif.
  final void Function(VibrationEntry entry)? onSettings;

  /// Appelé au tap sur « home » ; par défaut, revient en arrière.
  final VoidCallback? onHome;

  const VibrationsScreen({
    super.key,
    this.entries,
    this.onPattern,
    this.onSettings,
    this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: WaveDecor()),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 80, 20, 16),
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 1),
                        child: Text(
                          'Liste des vibrations',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 27,
                            fontWeight: FontWeight.w700,
                            color: AppColors.title,
                          ),
                        ),
                      ),
                      const SizedBox(height: 29),
                      GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 48,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (final entry in entries ?? VibrationEntries.all)
                            _VibrationCard(
                              entry: entry,
                              onPattern: () => onPattern?.call(entry),
                              onSettings: () => onSettings?.call(entry),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                HomeButton(
                  onPressed: onHome ?? () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 55),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VibrationCard extends StatelessWidget {
  final VibrationEntry entry;
  final VoidCallback onPattern;
  final VoidCallback onSettings;

  const _VibrationCard({
    required this.entry,
    required this.onPattern,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.hover,
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: AppColors.primary, offset: Offset(2, 2)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 60,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  entry.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundAction(
                    icon: Icons.waves,
                    label: 'Vibration ${entry.label}',
                    onTap: onPattern,
                  ),
                  _RoundAction(
                    icon: Icons.settings_outlined,
                    label: 'Réglages ${entry.label}',
                    onTap: onSettings,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: AppColors.settingRow, offset: Offset(2, 2)),
            ],
          ),
          child: Icon(icon, size: 30, color: AppColors.hover),
        ),
      ),
    );
  }
}
