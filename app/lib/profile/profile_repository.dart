import '../models/user_profile.dart';

/// Persistance du profil utilisateur, indépendante de Firestore pour que
/// les écrans restent testables sans réseau.
abstract class ProfileRepository {
  /// Identifiant de l'utilisateur courant (connexion anonyme au besoin).
  Future<String> currentUserId();

  /// Enregistre [profile], en écrasant la sauvegarde précédente.
  Future<void> saveProfile(UserProfile profile);

  /// Retourne la dernière sauvegarde, ou null s'il n'y en a jamais eu.
  Future<UserProfile?> fetchProfile();
}
