/// Échec de lecture ou d'écriture du profil (réseau, droits, document mal formé).
class ProfileException implements Exception {
  final String message;
  final Object? cause;

  const ProfileException(this.message, {this.cause});

  @override
  String toString() => 'ProfileException: $message';
}
