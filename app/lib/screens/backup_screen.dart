import 'package:flutter/material.dart';

import '../profile/profile_store.dart';
import '../theme/app_theme.dart';
import '../widgets/home_button.dart';

/// Sauvegarde et restauration des données de l'utilisateur.
class BackupScreen extends StatefulWidget {
  final ProfileStore store;

  /// Appelé au tap sur « home » ; par défaut, revient en arrière.
  final VoidCallback? onHome;

  const BackupScreen({super.key, required this.store, this.onHome});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  late final Future<String?> _userId;

  @override
  void initState() {
    super.initState();
    _userId = widget.store.userId();
  }

  static String _message(ProfileSyncResult result) => switch (result) {
    ProfileSyncResult.saved => 'Données sauvegardées.',
    ProfileSyncResult.restored => 'Données restaurées.',
    ProfileSyncResult.nothingToRestore => 'Aucune sauvegarde trouvée.',
    ProfileSyncResult.unavailable => 'Sauvegarde indisponible.',
    ProfileSyncResult.failed => 'Échec, réessayez plus tard.',
  };

  Future<void> _run(Future<ProfileSyncResult> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await action();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_message(result))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final busy = widget.store.busy;
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 96, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // TODO: avatar réel quand le profil en aura un.
                        Center(
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: FutureBuilder<String?>(
                            future: _userId,
                            builder: (context, snapshot) {
                              final text =
                                  snapshot.connectionState !=
                                      ConnectionState.done
                                  ? '…'
                                  : snapshot.data ?? 'indisponible';
                              return Text(
                                'ID: $text',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 132),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _BackupButton(
                              width: 138,
                              label: 'Sauvegarder mes donnees',
                              icon: Icons.favorite_border,
                              onTap: busy
                                  ? null
                                  : () => _run(widget.store.save),
                            ),
                            _BackupButton(
                              width: 136,
                              label: 'Restaurer les donnees',
                              icon: Icons.download_outlined,
                              onTap: busy
                                  ? null
                                  : () => _run(widget.store.restore),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                HomeButton(
                  onPressed:
                      widget.onHome ?? () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 40),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BackupButton extends StatelessWidget {
  final double width;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _BackupButton({
    required this.width,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? AppColors.disabled : Colors.black;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          height: 136,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: color),
              ),
              const SizedBox(height: 10),
              Icon(icon, size: 24, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
