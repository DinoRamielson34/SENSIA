// Généré manuellement à partir de google-services.json (équivalent au
// fichier que produirait `flutterfire configure`, non disponible ici car
// cette commande nécessite une connexion interactive au compte Firebase
// via navigateur). Seule la plateforme Android est configurée : c'est la
// seule pour laquelle un vrai projet Firebase a été fourni.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Options Firebase par défaut pour ce projet (voir google-services.json).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions n\'est pas configuré pour le web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions n\'est configuré que pour Android.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAfR6rctW7u9rwwR35pTzLF_KIefpvM9U4',
    appId: '1:756921566861:android:391e6ec6564b52503184c4',
    messagingSenderId: '756921566861',
    projectId: 'izahay-703fd',
    storageBucket: 'izahay-703fd.firebasestorage.app',
  );
}
