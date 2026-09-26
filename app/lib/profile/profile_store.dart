import 'package:flutter/foundation.dart';

import '../models/color_vision_type.dart';
import '../models/user_profile.dart';
import '../models/user_role.dart';
import '../models/vibration_segment.dart';
import 'profile_repository.dart';

enum ProfileSyncResult {
  saved,
  restored,
  nothingToRestore,

  /// Firebase n'a pas pu être initialisé : pas de dépôt disponible.
  unavailable,
  failed,
}

/// Profil courant, partagé entre les écrans, avec sauvegarde / restauration
/// via un [ProfileRepository].
class ProfileStore extends ChangeNotifier {
  final ProfileRepository? _repository;
  UserProfile _profile;
  bool _busy = false;

  ProfileStore({this._repository, UserProfile? profile})
    : _profile = profile ?? UserProfile();

  UserProfile get profile => _profile;

  /// true pendant une sauvegarde ou une restauration.
  bool get busy => _busy;

  void setRole(UserRole role) => _profile.role = role;

  void setColorVision(ColorVisionType type) => _profile.colorVision = type;

  void setSetting(String id, bool value) => _profile.settings[id] = value;

  void setVibrationPattern(String id, List<VibrationSegment> segments) =>
      _profile.vibrationPatterns[id] = List.of(segments);

  /// Identifiant de l'utilisateur, ou null si Firebase est indisponible.
  Future<String?> userId() => _repository?.currentUserId() ?? Future.value();

  Future<ProfileSyncResult> save() async {
    final repository = _repository;
    if (repository == null) return ProfileSyncResult.unavailable;
    _setBusy(true);
    try {
      await repository.saveProfile(_profile);
      return ProfileSyncResult.saved;
    } on Exception {
      return ProfileSyncResult.failed;
    } finally {
      _setBusy(false);
    }
  }

  Future<ProfileSyncResult> restore() async {
    final repository = _repository;
    if (repository == null) return ProfileSyncResult.unavailable;
    _setBusy(true);
    try {
      final fetched = await repository.fetchProfile();
      if (fetched == null) return ProfileSyncResult.nothingToRestore;
      _profile = fetched;
      return ProfileSyncResult.restored;
    } on Exception {
      return ProfileSyncResult.failed;
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }
}
