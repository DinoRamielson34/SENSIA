import 'package:izahay/haptics/vibration_executor.dart';

/// Double de test pour [VibrationExecutor] : n'appelle aucune API Android,
/// enregistre simplement les appels reçus pour que les tests puissent les
/// vérifier.
class FakeVibrationExecutor implements VibrationExecutor {
  bool hasVibratorResult = true;

  /// Délai artificiel appliqué à [cancel], pour simuler une opération native
  /// lente et pouvoir tester les scénarios de concurrence (Task 7).
  Duration cancelDelay = Duration.zero;

  /// Délai artificiel appliqué à [hasVibrator], pour tester qu'un appel plus
  /// récent invalide un appel encore bloqué sur sa propre vérification de
  /// compatibilité, avant même qu'il n'atteigne cancel()/vibrate().
  Duration hasVibratorDelay = Duration.zero;

  /// Si non nul, [hasVibrator] lève cette erreur au lieu de retourner un
  /// booléen — simule une panne native pour vérifier que [HapticEngine] ne
  /// l'avale jamais.
  Object? hasVibratorError;

  final List<List<int>> vibrateCalls = [];
  final List<String> callLog = [];

  @override
  Future<bool> hasVibrator() async {
    if (hasVibratorDelay > Duration.zero) {
      await Future<void>.delayed(hasVibratorDelay);
    }
    callLog.add('hasVibrator');
    final error = hasVibratorError;
    if (error != null) {
      throw error;
    }
    return hasVibratorResult;
  }

  @override
  Future<void> vibrate(List<int> nativeTimingsMs) async {
    callLog.add('vibrate');
    vibrateCalls.add(nativeTimingsMs);
  }

  @override
  Future<void> cancel() async {
    if (cancelDelay > Duration.zero) {
      await Future<void>.delayed(cancelDelay);
    }
    callLog.add('cancel');
  }
}
