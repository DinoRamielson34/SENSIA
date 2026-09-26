import '../models/association.dart';

/// Associations affichées par [AssociationsScreen].
// TODO: remplacer par une vraie source de données (Firestore ?) ; ce sont
// les cartes de la maquette 4:227.
class Associations {
  Associations._();

  static const List<Association> placeholder = [
    Association(name: 'Association 1'),
    Association(name: 'Association 1'),
    Association(name: 'Association 1'),
  ];
}
