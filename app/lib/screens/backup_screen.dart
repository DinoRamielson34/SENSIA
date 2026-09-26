import 'package:flutter/material.dart';

import '../profile/profile_store.dart';
import '../theme/app_theme.dart';
import '../widgets/home_button.dart';
import '../widgets/wave_decor.dart';

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
    ProfileSyncResult.unavailable => 'Sauvegarde indisponible (pas de Firebase).',
    ProfileSyncResult.authFailed =>
      'Authentification échouée. Activez l\'auth anonyme dans Firebase Console.',
    ProfileSyncResult.permissionDenied =>
      'Accès refusé. Vérifiez les règles Firestore.',
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
      body: Stack(
        children: [
          const Positioned.fill(child: WaveDecor()),
          SafeArea(
            child: ListenableBuilder(
              listenable: widget.store,
              builder: (context, _) {
                final busy = widget.store.busy;
                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 84, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(left: 16),
                              child: Text(
                                'Sauvegardez vos donnees et exportez les',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 27,
                                  fontWeight: FontWeight.w700,
                                  height: 1.37,
                                  color: AppColors.title,
                                ),
                              ),
                            ),
                            const SizedBox(height: 71),
                            _BackupButton(
                              label: 'Sauvegarder mes donnees',
                              icon: Icons.favorite_border,
                              onTap: busy ? null : () => _run(widget.store.save),
                            ),
                            const SizedBox(height: 22),
                            _BackupButton(
                              label: 'Restaurer les donnees',
                              icon: Icons.download_outlined,
                              onTap: busy
                                  ? null
                                  : () => _run(widget.store.restore),
                            ),
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
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      color: Colors.black,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    HomeButton(
                      onPressed:
                          widget.onHome ??
                          () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(height: 55),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _BackupButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = enabled ? Colors.black : AppColors.disabled;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 136,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: enabled
                ? AppColors.hover
                : AppColors.hover.withValues(alpha: 0.4),
            border: Border.all(color: AppColors.primary),
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(color: AppColors.primary, offset: Offset(2, 2)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: color),
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
