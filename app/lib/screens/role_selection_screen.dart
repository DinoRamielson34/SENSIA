import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../theme/app_theme.dart';
import '../widgets/next_button.dart';
import '../widgets/wave_decor.dart';

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
          body: Stack(
            children: [
              const Positioned.fill(child: WaveDecor()),
              SafeArea(
                // Défilement de secours : le contenu (≈685 px) dépasse les petits écrans.
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(child: _buildContent(selected)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(UserRole? selected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 100),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              'Êtes-vous...',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 27,
                fontWeight: FontWeight.w700,
                height: 1.33,
                color: AppColors.title,
              ),
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
                  onTap: () => _controller.select(UserRole.accompagnateur),
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
          NextButton(
            showLabel: false,
            onPressed: selected == null
                ? null
                : () => widget.onContinue?.call(selected),
          ),
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
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
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  // Sélectionné, survolé ou appuyé : fond orange du bouton (état « hover » de la maquette).
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    final image = widget.image;
    final selected = widget.selected;
    final onTap = widget.onTap;
    final highlighted = selected || _hover || _pressed;
    return Semantics(
      button: true,
      selected: selected,
      label: role.label,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.surface,
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
                  color: highlighted ? AppColors.hover : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Icon(
                  Icons.fingerprint,
                  size: 30,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
