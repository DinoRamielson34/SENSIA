import 'package:flutter/widgets.dart';

import 'tutorial_step.dart';
import 'tutorial_storage.dart';

/// Pilote un tutoriel : liste d'étapes, étape courante, mémorisation.
///
/// Les écrans marquent leurs éléments avec [target] ; `TutorialScope` affiche
/// le spotlight et la bulle par-dessus.
class TutorialController extends ChangeNotifier {
  /// Nombre maximal d'affichages automatiques si le tutoriel n'est pas terminé.
  static const maxAutoShows = 2;

  List<TutorialStep> _steps;
  final TutorialStorage _storage;
  final Map<String, GlobalKey> _keys = {};

  TutorialProgress _progress = const TutorialProgress();
  Future<void>? _loading;
  bool _active = false;
  bool _busy = false;
  int _index = 0;

  TutorialController({
    required List<TutorialStep> steps,
    TutorialStorage? storage,
  }) : _steps = _sorted(steps),
       _storage = storage ?? MemoryTutorialStorage();

  static List<TutorialStep> _sorted(List<TutorialStep> steps) =>
      List.unmodifiable([...steps]..sort((a, b) => a.order.compareTo(b.order)));

  /// Étapes triées par `order`.
  List<TutorialStep> get steps => _steps;

  /// Remplace les étapes (ex. après un changement de langue). Ignoré si le
  /// tutoriel est déjà affiché : il ne change pas de contenu au milieu
  /// d'une étape en cours.
  void updateSteps(List<TutorialStep> steps) {
    if (_active) return;
    _steps = _sorted(steps);
  }

  bool get isActive => _active;
  int get index => _index;
  TutorialStep? get current => _active ? _steps[_index] : null;
  bool get isFirst => _index == 0;
  bool get isLast => _index == _steps.length - 1;

  /// Vrai si l'utilisateur est déjà allé au bout du tutoriel.
  bool get completed => _progress.completed;

  Future<void> _ensureLoaded() =>
      _loading ??= _storage.load().then((p) => _progress = p);

  /// Marque un élément de l'écran comme cible d'étapes (`targetId`).
  Widget target(String id, Widget child) =>
      KeyedSubtree(key: _keys.putIfAbsent(id, GlobalKey.new), child: child);

  /// Contexte de l'élément ciblé, ou null s'il n'est pas à l'écran.
  BuildContext? contextFor(String id) => _keys[id]?.currentContext;

  /// Lancement automatique : seulement si le tutoriel n'est pas terminé et
  /// s'il ne s'est pas déjà affiché [maxAutoShows] fois.
  Future<void> startIfNeeded() async {
    await _ensureLoaded();
    if (_active || _steps.isEmpty) return;
    if (_progress.completed || _progress.autoShownCount >= maxAutoShows) return;
    _progress = _progress.copyWith(
      autoShownCount: _progress.autoShownCount + 1,
    );
    await _storage.save(_progress);
    await _begin();
  }

  /// Relance manuelle (ex. depuis les paramètres) ; ne compte pas comme
  /// affichage automatique.
  Future<void> restart() async {
    await _ensureLoaded();
    if (_active || _steps.isEmpty) return;
    await _begin();
  }

  Future<void> _begin() async {
    _index = 0;
    await _steps.first.onEnter?.call();
    _active = true;
    notifyListeners();
  }

  Future<void> next() async {
    if (!_active) return;
    if (isLast) return finish();
    await _go(_index + 1);
  }

  Future<void> previous() async {
    if (!_active || isFirst) return;
    await _go(_index - 1);
  }

  /// Ferme sans marquer comme terminé : il pourra se relancer tout seul
  /// tant que la limite d'affichages n'est pas atteinte.
  Future<void> skip() => _close(completed: false);

  /// Ferme et mémorise que le tutoriel est terminé.
  Future<void> finish() => _close(completed: true);

  /// Change d'étape après sa préparation (`onEnter`) ; ignore les appuis
  /// répétés pendant ce temps.
  Future<void> _go(int target) async {
    if (_busy) return;
    _busy = true;
    try {
      await _steps[target].onEnter?.call();
      _index = target;
      notifyListeners();
    } finally {
      _busy = false;
    }
  }

  Future<void> _close({required bool completed}) async {
    if (!_active) return;
    _active = false;
    if (completed) {
      _progress = _progress.copyWith(completed: true);
      await _storage.save(_progress);
    }
    notifyListeners();
  }
}
