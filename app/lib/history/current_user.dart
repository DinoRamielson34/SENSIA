import 'package:firebase_auth/firebase_auth.dart';

/// Enveloppe fine autour de Firebase Authentication : garantit qu'un
/// utilisateur est connecté avant d'accéder à ses données, sans jamais
/// inventer ni coder en dur d'identifiant. Connexion anonyme uniquement
/// (voir la spec, décision n°2) : aucun écran de connexion requis.
class CurrentUser {
  final FirebaseAuth _auth;

  CurrentUser({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  // Partagé entre TOUTES les instances de CurrentUser (chaque
  // FirestoreHistoryRepository crée la sienne) : si deux appels à
  // ensureSignedIn() arrivent avant que le tout premier signInAnonymously()
  // n'ait résolu, sans ce verrou chacun verrait `_auth.currentUser == null`
  // et déclencherait sa propre connexion anonyme — créant deux comptes
  // distincts. Le second à résoudre "gagnerait" côté SDK, et l'appelant
  // qui a reçu le premier uid écrirait ensuite sous un uid non authentifié
  // pour la session active, rejeté par les règles de sécurité. En gardant
  // ce Future en attente partagé, tous les appels concurrents attendent
  // et reçoivent le même (unique) uid.
  static Future<String>? _pendingSignIn;

  /// Retourne l'uid de l'utilisateur courant, en le connectant anonymement
  /// s'il ne l'est pas déjà. Effectue un appel réseau (ou utilise la
  /// session Firebase déjà en cache) si aucune session n'existe encore.
  /// Sûr face à des appels concurrents (voir [_pendingSignIn]).
  ///
  /// Lève toute exception de `firebase_auth` sans l'envelopper : cette
  /// classe ne fait que garantir la connexion, pas la gestion d'erreur
  /// métier. Note : `FirebaseAuthException` hérite de `FirebaseException`,
  /// donc si cette méthode est appelée depuis [FirestoreHistoryRepository]
  /// (qui attrape `FirebaseException` autour de ses propres opérations
  /// Firestore), une erreur d'authentification y sera actuellement
  /// enveloppée avec un message Firestore trompeur — limitation connue.
  Future<String> ensureSignedIn() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing.uid;

    final pending = _pendingSignIn;
    if (pending != null) return pending;

    final signInFuture = _signInAnonymously();
    _pendingSignIn = signInFuture;
    try {
      return await signInFuture;
    } finally {
      _pendingSignIn = null;
    }
  }

  Future<String> _signInAnonymously() async {
    final credential = await _auth.signInAnonymously();
    final user = credential.user;
    if (user == null) {
      throw StateError(
        'Firebase Auth n\'a retourné aucun utilisateur après signInAnonymously()',
      );
    }
    return user.uid;
  }
}
