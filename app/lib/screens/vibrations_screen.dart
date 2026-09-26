import 'package:flutter/material.dart';

import '../config/vibration_entries.dart';
import '../models/vibration_entry.dart';
import '../theme/app_theme.dart';
import '../widgets/home_button.dart';

class VibrationsScreen extends StatelessWidget {
  final List<VibrationEntry> entries;

  /// Bouton « ondes » d'une carte.
  // TODO: brancher sur SoundHapticPipeline.testVibration(category).
  final void Function(VibrationEntry entry)? onPattern;

  /// Bouton « engrenage » d'une carte.
  // TODO: ouvrir le réglage détaillé de ce son.
  final void Function(VibrationEntry entry)? onSettings;

  /// Appelé au tap sur « home » ; par défaut, revient en arrière.
  final VoidCallback? onHome;

  const VibrationsScreen({
    super.key,
    this.entries = VibrationEntries.placeholder,
    this.onPattern,
    this.onSettings,
    this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 20,
                crossAxisSpacing: 48,
                padding: const EdgeInsets.fromLTRB(20, 96, 20, 16),
                children: [
                  for (final entry in entries)
                    _VibrationCard(
                      entry: entry,
                      onPattern: () => onPattern?.call(entry),
                      onSettings: () => onSettings?.call(entry),
                    ),
                ],
              ),
            ),
            HomeButton(
              onPressed: onHome ?? () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(height: 40),
          ],
        ),
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
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      entry.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RoundAction(
                  icon: Icons.waves,
                  label: 'Vibration ${entry.label}',
                  onTap: onPattern,
                ),
                const SizedBox(width: 10),
                _RoundAction(
                  icon: Icons.settings_outlined,
                  label: 'Réglages ${entry.label}',
                  onTap: onSettings,
                ),
              ],
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
            color: Color(0xFFBCBCBC),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 30, color: Colors.black),
        ),
      ),
    );
  }
}
