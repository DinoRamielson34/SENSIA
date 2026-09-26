import '../models/association.dart';

/// Associations affichées par [AssociationsScreen].
// TODO: remplacer par une vraie source de données (Firestore ?) ; ce sont
// les cartes de la maquette 90:1462.
class Associations {
  Associations._();

  static const List<Association> placeholder = [
    Association(name: 'Association 1'),
    Association(
      name: 'Association FJKM',
      bannerAsset: 'assets/images/association_banner_fjkm.png',
      logoAsset: 'assets/images/association_logo_fjkm.png',
    ),
    Association(
      name: 'Association FJKM',
      bannerAsset: 'assets/images/association_banner_fjkm.png',
      logoAsset: 'assets/images/association_logo_fjkm.png',
    ),
  ];
}
