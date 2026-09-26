import 'package:flutter/material.dart';

import '../config/settings_categories.dart';
import '../models/settings_category.dart';
import '../theme/app_theme.dart';
import '../widgets/home_button.dart';
import '../widgets/wave_decor.dart';

class SettingsController extends ChangeNotifier {
  final Map<String, bool> _values;

  SettingsController(
    List<SettingsCategory> categories, {
    Map<String, bool> initialValues = const {},
  }) : _values = {
         for (final category in categories)
           for (final option in category.options)
             option.id: initialValues[option.id] ?? option.initialValue,
       };

  bool valueOf(String id) => _values[id] ?? false;

  void toggle(String id) {
    _values[id] = !valueOf(id);
    notifyListeners();
  }
}

class SettingsScreen extends StatefulWidget {
  /// Réglages à afficher ; par défaut, toutes les catégories de sons.
  final List<SettingsCategory>? categories;
  final SettingsController? controller;

  /// Valeurs à afficher au départ (par exemple celles d'une sauvegarde).
  final Map<String, bool> initialValues;

  /// Appelé à chaque bascule d'un réglage.
  // TODO: relier à SoundHapticPipeline.setCategoryEnabled quand les vrais
  // réglages remplaceront les libellés de la maquette.
  final void Function(String id, bool value)? onChanged;

  /// Appelé au tap sur le bouton « home » ; par défaut, revient en arrière.
  final VoidCallback? onHome;

  const SettingsScreen({
    super.key,
    this.categories,
    this.controller,
    this.initialValues = const {},
    this.onChanged,
    this.onHome,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsController _controller;
  late final List<SettingsCategory> _categories =
      widget.categories ?? SettingsCategories.all;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        SettingsController(_categories, initialValues: widget.initialValues);
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _toggle(String id) {
    _controller.toggle(id);
    widget.onChanged?.call(id, _controller.valueOf(id));
  }

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
                  child: ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) => ListView(
                      padding: const EdgeInsets.fromLTRB(20, 89, 20, 16),
                      children: [
                        const Text(
                          'Parametres des sons',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 27,
                            fontWeight: FontWeight.w700,
                            color: AppColors.title,
                          ),
                        ),
                        const SizedBox(height: 21),
                        for (final category in _categories) ...[
                          _CategoryHeader(title: category.title),
                          for (final option in category.options) ...[
                            const SizedBox(height: 4),
                            _OptionRow(
                              label: option.label,
                              value: _controller.valueOf(option.id),
                              onTap: () => _toggle(option.id),
                            ),
                          ],
                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
                  ),
                ),
                HomeButton(
                  onPressed:
                      widget.onHome ?? () => Navigator.of(context).maybePop(),
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

class _CategoryHeader extends StatelessWidget {
  final String title;

  const _CategoryHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        border: Border.all(color: AppColors.primary),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String label;
  final bool value;
  final VoidCallback onTap;

  const _OptionRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 34,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.settingRow,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  color: Colors.black,
                ),
              ),
              // Actif = pastille pleine (état non fourni par la maquette).
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: value ? AppColors.primary : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
