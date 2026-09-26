import 'package:cloud_firestore/cloud_firestore.dart';

import '../history/current_user.dart';
import '../models/user_profile.dart';
import 'profile_exceptions.dart';
import 'profile_repository.dart';

/// Implémentation Firestore de [ProfileRepository] : un seul document
/// `users/{uid}/profile/main`, isolé par utilisateur comme l'historique
/// (voir `firestore.rules`).
class FirestoreProfileRepository implements ProfileRepository {
  final FirebaseFirestore _firestore;
  final CurrentUser _currentUser;

  FirestoreProfileRepository({
    FirebaseFirestore? firestore,
    CurrentUser? currentUser,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _currentUser = currentUser ?? CurrentUser();

  Future<DocumentReference<Map<String, dynamic>>> _doc() async {
    final uid = await _currentUser.ensureSignedIn();
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('profile')
        .doc('main');
  }

  @override
  Future<String> currentUserId() => _currentUser.ensureSignedIn();

  @override
  Future<void> saveProfile(UserProfile profile) async {
    try {
      final doc = await _doc();
      await doc.set({
        ...profile.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ProfileException(
        'Impossible de sauvegarder le profil (${e.code})',
        cause: e,
      );
    }
  }

  @override
  Future<UserProfile?> fetchProfile() async {
    late final DocumentSnapshot<Map<String, dynamic>> snapshot;
    try {
      final doc = await _doc();
      snapshot = await doc.get();
    } on FirebaseException catch (e) {
      throw ProfileException(
        'Impossible de lire le profil (${e.code})',
        cause: e,
      );
    }
    final data = snapshot.data();
    if (data == null) return null;
    try {
      return UserProfile.fromMap(data);
    } on TypeError catch (e) {
      throw ProfileException('Sauvegarde mal formée', cause: e);
    }
  }
}
