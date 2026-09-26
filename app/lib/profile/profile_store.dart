import 'dart:async';

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
///
/// Chaque modification est sauvegardée automatiquement, avec un court délai
/// pour regrouper les changements rapprochés en une seule écriture.
class ProfileStore extends ChangeNotifier {
  final ProfileRepository? _repository;

  /// Appelé après une restauration réussie, pour réappliquer les données
  /// restaurées à l'application (pipeline, réglages).
  final VoidCallback? onRestored;

  /// Délai entre la dernière modification et la sauvegarde automatique.
  final Duration autosaveDelay;

  UserProfile _profile;
  bool _busy = false;
  bool _disposed = false;

  // La sauvegarde automatique ne démarre qu'une fois l'état distant connu
  // (restauré, ou confirmé vide) ou explicitement écrasé par l'utilisateur :
  // sinon des valeurs par défaut écraseraient une vraie sauvegarde, par
  // exemple après un échec de lecture au démarrage.
  bool _autosaveReady = false;
  Timer? _autosaveTimer;

  ProfileStore({
    this._repository,
    this.onRestored,
    this.autosaveDelay = const Duration(seconds: 1),
    UserProfile? profile,
  }) : _profile = profile ?? UserProfile();

  UserProfile get profile => _profile;

  /// true pendant une sauvegarde ou une restauration.
  bool get busy => _busy;

  void setRole(UserRole role) {
    _profile.role = role;
    _scheduleAutosave();
  }

  void setColorVision(ColorVisionType type) {
    _profile.colorVision = type;
    _scheduleAutosave();
  }

  void setSetting(String id, bool value) {
    _profile.settings[id] = value;
    _scheduleAutosave();
  }

  void setVibrationPattern(String id, List<VibrationSegment> segments) {
    _profile.vibrationPatterns[id] = List.of(segments);
    _scheduleAutosave();
  }

  /// Identifiant de l'utilisateur, ou null si Firebase est indisponible.
  Future<String?> userId() => _repository?.currentUserId() ?? Future.value();

  /// Sauvegarde immédiatement le profil (bouton « Sauvegarder »). Le
  /// résultat écrase la sauvegarde distante : la sauvegarde automatique est
  /// donc activée ensuite.
  Future<ProfileSyncResult> save() async {
    final repository = _repository;
    if (repository == null) return ProfileSyncResult.unavailable;
    _autosaveTimer?.cancel();
    _setBusy(true);
    try {
      await repository.saveProfile(_profile);
      _autosaveReady = true;
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
    _autosaveTimer?.cancel();
    _setBusy(true);
    try {
      final fetched = await repository.fetchProfile();
      _autosaveReady = true;
      if (fetched == null) return ProfileSyncResult.nothingToRestore;
      _profile = fetched;
      onRestored?.call();
      return ProfileSyncResult.restored;
    } on Exception {
      return ProfileSyncResult.failed;
    } finally {
      _setBusy(false);
    }
  }

  /// Sauvegarde tout de suite une modification en attente (par exemple quand
  /// l'app passe en arrière-plan), sans attendre la fin du délai.
  Future<void> flushPending() async {
    final timer = _autosaveTimer;
    if (timer == null || !timer.isActive) return;
    timer.cancel();
    await _autosave();
  }

  void _scheduleAutosave() {
    if (_repository == null || !_autosaveReady || _disposed) return;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(autosaveDelay, () => unawaited(_autosave()));
  }

  Future<void> _autosave() async {
    final repository = _repository;
    if (repository == null || _disposed) return;
    try {
      await repository.saveProfile(_profile);
    } on Exception {
      // Silencieux : la prochaine modification réessaie, et le bouton
      // « Sauvegarder » affiche les échecs.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _autosaveTimer?.cancel();
    super.dispose();
  }

  void _setBusy(bool value) {
    if (_disposed) return;
    _busy = value;
    notifyListeners();
  }
}
