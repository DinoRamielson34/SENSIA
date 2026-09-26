import 'package:flutter/material.dart';

import '../config/associations.dart';
import '../models/association.dart';
import '../theme/app_theme.dart';
import '../widgets/home_button.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 96, 20, 16),
                itemCount: associations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 20),
                itemBuilder: (context, index) {
                  final association = associations[index];
                  return _AssociationCard(
                    association: association,
                    onContact: () => onContact?.call(association),
                  );
                },
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

class _AssociationCard extends StatelessWidget {
  final Association association;
  final VoidCallback onContact;

  const _AssociationCard({required this.association, required this.onContact});

  static const _placeholderGrey = Color(0xFFC4C4C4);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 135,
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _framed(height: 110, asset: association.bannerAsset),
                SizedBox(
                  height: 25,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 10,
                        top: -25,
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: _framed(asset: association.logoAsset),
                        ),
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
                decoration: const BoxDecoration(
                  color: Color(0xFFBCBCBC),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sms_outlined,
                  size: 30,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _framed({double? height, String? asset}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: asset == null ? _placeholderGrey : null,
        border: Border.all(color: AppColors.primary),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: asset == null
          ? null
          : SizedBox.expand(child: Image.asset(asset, fit: BoxFit.cover)),
    );
  }
}
