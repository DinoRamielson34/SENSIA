import 'package:flutter/services.dart';

import 'haptic_exceptions.dart';

/// Contrat d'exécution des vibrations, indépendant de toute plateforme.
///
/// Permet à `HapticEngine` de rester testable sans dépendre d'un canal
/// Android réel (voir la fausse implémentation utilisée dans les tests).
abstract class VibrationExecutor {
  /// Indique si l'appareil dispose d'un vibreur matériel.
  Future<bool> hasVibrator();

  /// Déclenche une vibration décrite par [nativeTimingsMs] : un tableau
  /// alterné `[délai_initial, vibre, pause, vibre, pause, ...]` en
  /// millisecondes, au format attendu par l'API Android.
  Future<void> vibrate(List<int> nativeTimingsMs);

  /// Annule toute vibration en cours. Ne fait rien si aucune vibration
  /// n'est en cours.
  Future<void> cancel();
}

/// Implémentation réelle de [VibrationExecutor], qui délègue au code natif
/// Android via un [MethodChannel].
class MethodChannelVibrationExecutor implements VibrationExecutor {
  static const _channel = MethodChannel('mg.izahay.izahay/haptics');

  const MethodChannelVibrationExecutor();

  @override
  Future<bool> hasVibrator() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasVibrator');
      return result ?? false;
    } on PlatformException catch (e) {
      throw HapticPlatformException(
        'Échec de la vérification du vibreur',
        cause: e,
      );
    } on MissingPluginException catch (e) {
      throw HapticPlatformException(
        'Le pont natif haptique n\'est pas enregistré',
        cause: e,
      );
    }
  }

  @override
  Future<void> vibrate(List<int> nativeTimingsMs) async {
    try {
      await _channel.invokeMethod<void>('vibrate', {
        'timings': nativeTimingsMs,
      });
    } on PlatformException catch (e) {
      throw HapticPlatformException(
        'Échec du déclenchement de la vibration',
        cause: e,
      );
    } on MissingPluginException catch (e) {
      throw HapticPlatformException(
        'Le pont natif haptique n\'est pas enregistré',
        cause: e,
      );
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } on PlatformException catch (e) {
      throw HapticPlatformException(
        'Échec de l\'annulation de la vibration',
        cause: e,
      );
    } on MissingPluginException catch (e) {
      throw HapticPlatformException(
        'Le pont natif haptique n\'est pas enregistré',
        cause: e,
      );
    }
  }
}
