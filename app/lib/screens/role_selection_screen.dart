import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../theme/app_theme.dart';

class RoleSelectionController extends ChangeNotifier {
  UserRole? _selected;

  UserRole? get selected => _selected;

  void select(UserRole role) {
    if (_selected == role) return;
    _selected = role;
    notifyListeners();
  }
}

class RoleSelectionScreen extends StatefulWidget {
  final RoleSelectionController? controller;

  /// Appelé au tap sur « Suivants » avec le rôle choisi.
  // TODO: brancher la navigation vers l'écran suivant quand il existera.
  final void Function(UserRole role)? onContinue;

  const RoleSelectionScreen({super.key, this.controller, this.onContinue});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  late final RoleSelectionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? RoleSelectionController();
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final selected = _controller.selected;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 96),
                  const Text(
                    'Êtes-vous...',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _RoleCard(
                          role: UserRole.accompagnateur,
                          image: 'assets/images/role_accompagnateur.png',
                          selected: selected == UserRole.accompagnateur,
                          onTap: () =>
                              _controller.select(UserRole.accompagnateur),
                        ),
                      ),
                      const SizedBox(width: 17),
                      Expanded(
                        child: _RoleCard(
                          role: UserRole.client,
                          image: 'assets/images/role_client.png',
                          selected: selected == UserRole.client,
                          onTap: () => _controller.select(UserRole.client),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _NextButton(
                    onPressed: selected == null
                        ? null
                        : () => widget.onContinue?.call(selected),
                  ),
                  const SizedBox(height: 96),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoleCard extends StatelessWidget {
  final UserRole role;
  final String image;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.image,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: role.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFFD9D9D9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary,
                  width: selected ? 3 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: SizedBox.expand(
                child: Image.asset(image, fit: BoxFit.cover),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                role.label,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 60,
              width: double.infinity,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary),
              ),
              child: Icon(
                Icons.fingerprint,
                size: 30,
                color: selected ? AppColors.onPrimary : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _NextButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.disabled,
          disabledForegroundColor: AppColors.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Suivants',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: 10),
            Icon(Icons.skip_next_outlined, size: 24),
          ],
        ),
      ),
    );
  }
}
