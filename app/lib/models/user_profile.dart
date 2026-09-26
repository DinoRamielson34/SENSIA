import 'user_role.dart';
import 'color_vision_type.dart';
import 'vibration_segment.dart';

/// Données de l'utilisateur sauvegardées / restaurées via Firebase.
class UserProfile {
  UserRole? role;
  ColorVisionType? colorVision;

  /// Réglages de l'écran de réglages, par identifiant d'option.
  final Map<String, bool> settings;

  /// Motifs de vibration construits par l'utilisateur, par identifiant de son.
  final Map<String, List<VibrationSegment>> vibrationPatterns;

  UserProfile({
    this.role,
    this.colorVision,
    Map<String, bool>? settings,
    Map<String, List<VibrationSegment>>? vibrationPatterns,
  }) : settings = settings ?? {},
       vibrationPatterns = vibrationPatterns ?? {};

  Map<String, dynamic> toMap() => {
    'role': role?.name,
    'colorVision': colorVision?.name,
    'settings': Map<String, bool>.of(settings),
    'vibrationPatterns': {
      for (final entry in vibrationPatterns.entries)
        entry.key: [for (final segment in entry.value) segment.name],
    },
  };

  /// Relit un profil sérialisé par [toMap]. Les valeurs inconnues (par
  /// exemple un rôle ajouté par une version plus récente) sont ignorées
  /// plutôt que de faire échouer toute la restauration.
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final settings = Map<String, dynamic>.from(
      (map['settings'] as Map?) ?? const {},
    );
    final patterns = Map<String, dynamic>.from(
      (map['vibrationPatterns'] as Map?) ?? const {},
    );
    return UserProfile(
      role: UserRole.values.asNameMap()[map['role']],
      colorVision: ColorVisionType.values.asNameMap()[map['colorVision']],
      settings: {
        for (final entry in settings.entries) entry.key: entry.value as bool,
      },
      vibrationPatterns: {
        for (final entry in patterns.entries)
          entry.key: [
            for (final name in entry.value as List)
              if (VibrationSegment.values.asNameMap()[name] != null)
                VibrationSegment.values.asNameMap()[name]!,
          ],
      },
    );
  }
}
