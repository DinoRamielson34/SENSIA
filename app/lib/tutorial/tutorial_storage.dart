import 'package:shared_preferences/shared_preferences.dart';

/// Ce que l'app retient du tutoriel entre deux lancements.
class TutorialProgress {
  /// Vrai une fois le tutoriel terminé jusqu'au bout.
  final bool completed;

  /// Nombre de fois où il s'est affiché tout seul.
  final int autoShownCount;

  const TutorialProgress({this.completed = false, this.autoShownCount = 0});

  TutorialProgress copyWith({bool? completed, int? autoShownCount}) =>
      TutorialProgress(
        completed: completed ?? this.completed,
        autoShownCount: autoShownCount ?? this.autoShownCount,
      );
}

/// Stockage de la progression ; remplaçable en test.
abstract class TutorialStorage {
  Future<TutorialProgress> load();
  Future<void> save(TutorialProgress progress);
}

/// Stockage en mémoire (tests, ou repli quand rien n'est persisté).
class MemoryTutorialStorage implements TutorialStorage {
  TutorialProgress _progress;

  MemoryTutorialStorage([this._progress = const TutorialProgress()]);

  @override
  Future<TutorialProgress> load() async => _progress;

  @override
  Future<void> save(TutorialProgress progress) async => _progress = progress;
}

/// Stockage local persistant (survit à la fermeture de l'app).
class SharedPreferencesTutorialStorage implements TutorialStorage {
  static const _completedKey = 'tutorial_completed';
  static const _shownKey = 'tutorial_auto_shown_count';

  @override
  Future<TutorialProgress> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return TutorialProgress(
        completed: prefs.getBool(_completedKey) ?? false,
        autoShownCount: prefs.getInt(_shownKey) ?? 0,
      );
    } on Exception {
      // Stockage illisible : mieux vaut ne pas relancer le tutoriel à chaque
      // démarrage que d'importuner l'utilisateur.
      return const TutorialProgress(completed: true);
    }
  }

  @override
  Future<void> save(TutorialProgress progress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_completedKey, progress.completed);
      await prefs.setInt(_shownKey, progress.autoShownCount);
    } on Exception {
      // Sans persistance, le tutoriel reste utilisable pour cette session.
    }
  }
}
