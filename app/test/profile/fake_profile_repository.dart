import 'package:izahay/models/user_profile.dart';
import 'package:izahay/profile/profile_exceptions.dart';
import 'package:izahay/profile/profile_repository.dart';

/// Dépôt en mémoire : simule Firestore sans réseau.
class FakeProfileRepository implements ProfileRepository {
  UserProfile? stored;
  bool failing = false;
  int saves = 0;

  @override
  Future<String> currentUserId() async => 'uid-test-123';

  @override
  Future<void> saveProfile(UserProfile profile) async {
    if (failing) throw const ProfileException('échec simulé');
    saves++;
    // Copie via la sérialisation, comme le ferait un vrai aller-retour.
    stored = UserProfile.fromMap(profile.toMap());
  }

  @override
  Future<UserProfile?> fetchProfile() async {
    if (failing) throw const ProfileException('échec simulé');
    return stored;
  }
}
