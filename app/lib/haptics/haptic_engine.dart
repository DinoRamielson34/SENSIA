import 'haptic_exceptions.dart';
import 'models/vibration_pattern.dart';
import 'pattern_registry.dart';
import 'pattern_validator.dart';
import 'vibration_executor.dart';

/// Point d'entrée public du moteur de vibrations. C'est la seule classe que
/// les autres modules (IA, interface utilisateur) doivent utiliser.
class HapticEngine {
  final VibrationExecutor _executor;
  final PatternRegistry _registry;
  final PatternValidator _validator;
  int _requestToken = 0;

  HapticEngine({
    required VibrationExecutor executor,
    PatternRegistry? registry,
    PatternValidator? validator,
  })  : _executor = executor,
        _registry = registry ?? PatternRegistry(),
        _validator = validator ?? const PatternValidator();

  /// Enregistre ou remplace le motif associé à [category]. Valide le motif
  /// avant de l'enregistrer.
  ///
  /// Lève [InvalidVibrationPatternException] si [pattern] n'est pas valide.
  void registerPattern(String category, VibrationPattern pattern) {
    _registry.register(category, pattern);
  }

  /// Indique si l'appareil dispose d'un vibreur matériel.
  Future<bool> isDeviceCompatible() => _executor.hasVibrator();

  /// Joue le motif enregistré pour [category].
  ///
  /// Lève [InvalidVibrationPatternException] si aucun motif n'est enregistré
  /// pour cette catégorie. Lève [HapticUnsupportedException] si l'appareil
  /// n'a pas de vibreur.
  Future<void> playForCategory(String category) async {
    final pattern = _registry.lookup(category);
    if (pattern == null) {
      throw InvalidVibrationPatternException(
        'Aucun motif enregistré pour la catégorie "$category"',
      );
    }
    await playPattern(pattern);
  }

  /// Joue [pattern] immédiatement, en annulant toute vibration en cours.
  ///
  /// Si un appel plus récent à [playPattern]/[playForCategory]/[stop] est
  /// déclenché avant que celui-ci n'ait fini de vibrer, ce dernier abandonne
  /// silencieusement pour laisser la place au plus récent ("la dernière
  /// demande gagne").
  ///
  /// Lève [InvalidVibrationPatternException] si [pattern] n'est pas valide,
  /// [HapticUnsupportedException] si l'appareil n'a pas de vibreur.
  Future<void> playPattern(VibrationPattern pattern) async {
    _validator.validate(pattern);

    // Le jeton est pris de façon synchrone, avant tout `await` : Dart étant
    // mono-thread, deux appels concurrents prennent donc leurs jetons dans
    // l'ordre strict de leurs appels, sans zone de course possible. Chaque
    // `await` qui suit revérifie le jeton : un appel plus récent invalide
    // ainsi l'appel précédent dès que possible, même s'il est encore en
    // train de vérifier la compatibilité de l'appareil — pas seulement au
    // moment d'annuler.
    final myToken = ++_requestToken;

    final hasVibrator = await _executor.hasVibrator();
    if (myToken != _requestToken) return;
    if (!hasVibrator) {
      throw HapticUnsupportedException(
        'Cet appareil ne dispose d\'aucun vibreur',
      );
    }

    await _executor.cancel();
    if (myToken != _requestToken) return;

    await _executor.vibrate(_toNativeTimings(pattern));
  }

  /// Arrête toute vibration en cours, y compris une demande [playPattern]
  /// encore en cours de démarrage (par exemple en attente de vérification de
  /// compatibilité) : elle sera invalidée par son propre jeton et ne
  /// vibrera jamais.
  Future<void> stop() {
    _requestToken++;
    return _executor.cancel();
  }

  /// Convertit un [VibrationPattern] vers le format attendu par Android :
  /// un tableau alterné [délai_initial, vibre, pause, vibre, pause, ...].
  /// IZAHAY ne différant jamais la première impulsion, le délai initial est
  /// toujours 0. Chaque impulsion ajoute systématiquement ses deux valeurs
  /// (même une pause de 0ms) pour que l'alternance vibre/pause reste
  /// correcte : omettre une pause nulle décalerait la parité du tableau et
  /// ferait interpréter la vibration suivante comme une pause.
  List<int> _toNativeTimings(VibrationPattern pattern) {
    final timings = <int>[0];
    for (final pulse in pattern.pulses) {
      timings.add(pulse.vibrate.inMilliseconds);
      timings.add(pulse.pauseAfter.inMilliseconds);
    }
    return timings;
  }
}
