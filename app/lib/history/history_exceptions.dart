/// Exception levée quand une écriture Firestore échoue (réseau, quota...).
/// Enveloppe la cause d'origine pour le débogage.
class HistoryWriteException implements Exception {
  final String message;
  final Object? cause;
  const HistoryWriteException(this.message, {this.cause});

  @override
  String toString() =>
      'HistoryWriteException: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// Exception levée quand une lecture Firestore échoue.
class HistoryReadException implements Exception {
  final String message;
  final Object? cause;
  const HistoryReadException(this.message, {this.cause});

  @override
  String toString() =>
      'HistoryReadException: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// Exception levée quand une opération est refusée par les règles de
/// sécurité Firestore (accès aux données d'un autre utilisateur).
class HistoryPermissionException implements Exception {
  final String message;
  final Object? cause;
  const HistoryPermissionException(this.message, {this.cause});

  @override
  String toString() =>
      'HistoryPermissionException: $message${cause != null ? ' (cause: $cause)' : ''}';
}
