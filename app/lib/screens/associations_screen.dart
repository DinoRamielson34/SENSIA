import 'package:flutter/material.dart';

import '../config/associations.dart';
import '../models/association.dart';
import '../theme/app_theme.dart';
import '../widgets/home_button.dart';
import '../widgets/wave_decor.dart';

class AssociationsScreen extends StatelessWidget {
  final List<Association> associations;

  /// Appelé au tap sur le bouton message d'une association.
  // TODO: brancher le contact quand le flux de messagerie existera.
  final void Function(Association association)? onContact;

  /// Appelé au tap sur « home » ; par défaut, revient en arrière.
  final VoidCallback? onHome;

  const AssociationsScreen({
    super.key,
    this.associations = Associations.placeholder,
    this.onContact,
    this.onHome,
  });

  static const _defaultBanner = 'assets/images/association_banner_placeholder.png';

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
                    padding: const EdgeInsets.fromLTRB(20, 17, 20, 16),
                    children: [
                      const Text(
                        'Trouvez\nquelles entités pour\nvous aider.',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 27,
                          fontWeight: FontWeight.w700,
                          height: 1.33,
                          color: AppColors.title,
                        ),
                      ),
                      const SizedBox(height: 23),
                      for (var i = 0; i < associations.length; i++) ...[
                        if (i > 0) const SizedBox(height: 21),
                        _AssociationCard(
                          association: associations[i],
                          onContact: () => onContact?.call(associations[i]),
                        ),
                      ],
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

class _AssociationCard extends StatelessWidget {
  final Association association;
  final VoidCallback onContact;

  const _AssociationCard({required this.association, required this.onContact});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 135,
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _framed(
                  height: 110,
                  asset:
                      association.bannerAsset ?? AssociationsScreen._defaultBanner,
                ),
                SizedBox(
                  height: 25,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 10,
                        top: -25,
                        child: _Logo(asset: association.logoAsset),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 70),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            association.name,
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
              ],
            ),
          ),
          const SizedBox(width: 20),
          Semantics(
            button: true,
            label: 'Contacter ${association.name}',
            child: GestureDetector(
              onTap: onContact,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary),
                  boxShadow: const [
                    BoxShadow(color: AppColors.hover, offset: Offset(2, 2)),
                  ],
                ),
                child: const Icon(
                  Icons.sms_outlined,
                  size: 30,
                  color: AppColors.hover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _framed({required double height, required String asset}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox.expand(child: Image.asset(asset, fit: BoxFit.cover)),
    );
  }
}

/// Pastille ronde du logo ; sans logo, pictogramme par défaut de la maquette.
class _Logo extends StatelessWidget {
  final String? asset;

  const _Logo({required this.asset});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.logoBackground,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary),
      ),
      clipBehavior: Clip.antiAlias,
      child: asset == null
          ? const Icon(
              Icons.local_fire_department_outlined,
              size: 24,
              color: Colors.black,
            )
          : Image.asset(asset!, fit: BoxFit.cover),
    );
  }
}
