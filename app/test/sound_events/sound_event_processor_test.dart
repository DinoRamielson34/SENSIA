import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/haptics/haptic_engine.dart';
import 'package:izahay/haptics/haptic_exceptions.dart';
import 'package:izahay/sound_events/category_settings.dart';
import 'package:izahay/sound_events/history_sink.dart';
import 'package:izahay/sound_events/sound_event.dart';
import 'package:izahay/sound_events/sound_event_processor.dart';
import 'package:izahay/sound_events/sound_event_result.dart';

import '../haptics/fake_vibration_executor.dart';

void main() {
  late FakeVibrationExecutor executor;
  late HapticEngine hapticEngine;
  late SoundEventProcessor processor;
  late DateTime t0;

  setUp(() {
    executor = FakeVibrationExecutor();
    hapticEngine = HapticEngine(executor: executor);
    processor = SoundEventProcessor(hapticEngine: hapticEngine);
    t0 = DateTime.utc(2026, 9, 25, 12);
  });

  SoundEvent event({
    required String category,
    required double score,
    DateTime? timestamp,
    String source = 'microphone',
    bool isSimulation = false,
  }) {
    return SoundEvent(
      category: category,
      score: score,
      timestamp: timestamp ?? t0,
      source: source,
      isSimulation: isSimulation,
    );
  }

  test('TEST 1 — catégorie activée, score au-dessus du seuil, confirmation '
      'valide déclenche la vibration', () async {
    final result = await processor.process(
      event(category: 'sonnette', score: 0.9),
    );

    expect(result.status, SoundEventStatus.triggered);
    expect(executor.vibrateCalls, isNotEmpty);
  });

  test(
    'TEST 2 — une catégorie désactivée ne déclenche aucune vibration',
    () async {
      processor.settings.updateCategory(
        'sonnette',
        const CategorySettings(
          enabled: false,
          threshold: 0.75,
          requiredConfirmations: 1,
          cooldown: Duration(seconds: 5),
        ),
      );

      final result = await processor.process(
        event(category: 'sonnette', score: 0.99),
      );

      expect(result.status, SoundEventStatus.categoryDisabled);
      expect(executor.vibrateCalls, isEmpty);
    },
  );

  test(
    'TEST 3 — un score inférieur au seuil ne déclenche aucune vibration',
    () async {
      final result = await processor.process(
        event(category: 'sonnette', score: 0.5),
      );

      expect(result.status, SoundEventStatus.belowThreshold);
      expect(executor.vibrateCalls, isEmpty);
    },
  );

  test('TEST 5 — une catégorie inconnue est ignorée proprement', () async {
    final result = await processor.process(
      event(category: 'inconnue', score: 0.99),
    );

    expect(result.status, SoundEventStatus.unknownCategory);
    expect(executor.vibrateCalls, isEmpty);
  });

  test('TEST 6 — un événement simulé suit les mêmes règles et conserve son '
      'statut simulé', () async {
    final resultDeclenche = await processor.process(
      event(category: 'sonnette', score: 0.9, isSimulation: true),
    );
    expect(resultDeclenche.status, SoundEventStatus.triggered);
    expect(resultDeclenche.isSimulation, isTrue);

    final resultSousSeuil = await processor.process(
      event(category: 'aboiement', score: 0.1, isSimulation: true),
    );
    expect(resultSousSeuil.status, SoundEventStatus.belowThreshold);
    expect(resultSousSeuil.isSimulation, isTrue);
  });

  test('TEST 7 — l\'arrêt de l\'écoute bloque les événements microphone, '
      'mais pas les événements simulés', () async {
    processor.stopListening();

    final resultMicro = await processor.process(
      event(category: 'sonnette', score: 0.9),
    );
    expect(resultMicro.status, SoundEventStatus.listeningStopped);
    expect(executor.vibrateCalls, isEmpty);

    // Un événement simulé qui se déclare pourtant source: "microphone"
    // doit tout de même passer : la simulation ignore l'état d'écoute.
    final resultSimule = await processor.process(
      event(category: 'sonnette', score: 0.9, isSimulation: true),
    );
    expect(resultSimule.status, SoundEventStatus.triggered);
  });

  test('confirmation multi-fenêtres : ne déclenche qu\'après N détections '
      'consécutives qualifiantes', () async {
    processor.settings.updateCategory(
      'sonnette',
      const CategorySettings(
        enabled: true,
        threshold: 0.75,
        requiredConfirmations: 2,
        cooldown: Duration(seconds: 5),
      ),
    );

    final first = await processor.process(
      event(category: 'sonnette', score: 0.9),
    );
    expect(first.status, SoundEventStatus.awaitingConfirmation);
    expect(executor.vibrateCalls, isEmpty);

    final second = await processor.process(
      event(category: 'sonnette', score: 0.9, timestamp: t0),
    );
    expect(second.status, SoundEventStatus.triggered);
    expect(executor.vibrateCalls, isNotEmpty);
  });

  test('une détection sous le seuil remet le compteur de confirmation à '
      'zéro', () async {
    processor.settings.updateCategory(
      'sonnette',
      const CategorySettings(
        enabled: true,
        threshold: 0.75,
        requiredConfirmations: 2,
        cooldown: Duration(seconds: 5),
      ),
    );

    await processor.process(event(category: 'sonnette', score: 0.9));
    await processor.process(event(category: 'sonnette', score: 0.1));
    final third = await processor.process(
      event(category: 'sonnette', score: 0.9),
    );

    // Le compteur ayant été remis à zéro, cette 3e détection n'est que la
    // 1re d'une nouvelle série : encore en attente, pas déclenché.
    expect(third.status, SoundEventStatus.awaitingConfirmation);
    expect(executor.vibrateCalls, isEmpty);
  });

  test('TEST 4 — deux détections trop rapprochées ne produisent pas deux '
      'vibrations (anti-répétition)', () async {
    final first = await processor.process(
      event(category: 'sonnette', score: 0.9, timestamp: t0),
    );
    expect(first.status, SoundEventStatus.triggered);

    final second = await processor.process(
      event(
        category: 'sonnette',
        score: 0.9,
        timestamp: t0.add(const Duration(seconds: 1)),
      ),
    );
    expect(second.status, SoundEventStatus.inCooldown);
    expect(executor.vibrateCalls, hasLength(1));

    final third = await processor.process(
      event(
        category: 'sonnette',
        score: 0.9,
        timestamp: t0.add(const Duration(seconds: 6)),
      ),
    );
    expect(third.status, SoundEventStatus.triggered);
    expect(executor.vibrateCalls, hasLength(2));
  });

  test(
    'un échec du moteur haptique (catégorie non enregistrée côté '
    'HapticEngine) est retourné proprement, jamais levé comme exception',
    () async {
      processor.settings.updateCategory(
        'connue-du-processor-seulement',
        const CategorySettings(
          enabled: true,
          threshold: 0.5,
          requiredConfirmations: 1,
          cooldown: Duration(seconds: 5),
        ),
      );

      final result = await processor.process(
        event(category: 'connue-du-processor-seulement', score: 0.9),
      );

      expect(result.status, SoundEventStatus.hapticFailure);
      expect(result.reason, isNotNull);
      expect(executor.vibrateCalls, isEmpty);
    },
  );

  test('TEST 8 — deux catégories quasi simultanées ne provoquent pas de '
      'vibrations concurrentes incohérentes', () async {
    final first = processor.process(
      event(category: 'sonnette', score: 0.9, timestamp: t0),
    );
    final second = processor.process(
      event(category: 'aboiement', score: 0.9, timestamp: t0),
    );

    final results = await Future.wait([first, second]);

    // Un seul motif net a réellement vibré : celui du second appel, la
    // politique "dernier gagne" de HapticEngine ayant annulé le premier
    // avant qu'il ne vibre (comportement hérité, pas réimplémenté ici).
    // Le motif natif exact confirme que c'est bien celui d'aboiement qui a
    // joué, pas un mélange, et les statuts distinguent le supplanté du
    // réellement déclenché.
    expect(executor.vibrateCalls, [
      [0, 400, 200, 400, 200, 400, 0],
    ]);
    expect(results[0].status, SoundEventStatus.superseded);
    expect(results[1].status, SoundEventStatus.triggered);
  });

  test('un déclenchement supplanté par une autre catégorie ne démarre pas '
      'de fausse anti-répétition : un vrai événement juste après peut '
      'encore déclencher', () async {
    final first = processor.process(
      event(category: 'sonnette', score: 0.9, timestamp: t0),
    );
    final second = processor.process(
      event(category: 'aboiement', score: 0.9, timestamp: t0),
    );
    await Future.wait([first, second]);
    executor.vibrateCalls.clear();

    final retry = await processor.process(
      event(
        category: 'sonnette',
        score: 0.9,
        timestamp: t0.add(const Duration(milliseconds: 1)),
      ),
    );

    expect(retry.status, SoundEventStatus.triggered);
    expect(executor.vibrateCalls, isNotEmpty);
  });

  test('une HapticPlatformException native est retournée proprement, '
      'jamais levée comme exception', () async {
    executor.hasVibratorError = const HapticPlatformException(
      'panne native simulée',
    );

    final result = await processor.process(
      event(category: 'sonnette', score: 0.9),
    );

    expect(result.status, SoundEventStatus.hapticFailure);
    expect(result.reason, isNotNull);
  });

  test('un appareil sans vibreur (HapticUnsupportedException) est retourné '
      'proprement, jamais levé comme exception', () async {
    executor.hasVibratorResult = false;

    final result = await processor.process(
      event(category: 'sonnette', score: 0.9),
    );

    expect(result.status, SoundEventStatus.hapticFailure);
    expect(result.reason, isNotNull);
  });

  test('la limite exacte de l\'anti-répétition est stricte : bloqué juste '
      'avant, autorisé exactement à la limite', () async {
    const cooldown = Duration(seconds: 5);
    await processor.process(
      event(category: 'sonnette', score: 0.9, timestamp: t0),
    );

    final justBefore = await processor.process(
      event(
        category: 'sonnette',
        score: 0.9,
        timestamp: t0.add(cooldown).subtract(const Duration(microseconds: 1)),
      ),
    );
    expect(justBefore.status, SoundEventStatus.inCooldown);

    final exactlyAt = await processor.process(
      event(category: 'sonnette', score: 0.9, timestamp: t0.add(cooldown)),
    );
    expect(exactlyAt.status, SoundEventStatus.triggered);
  });

  test('un historySink qui ne répond jamais ne bloque pas process()', () async {
    final sink = _RecordingHistorySink(neverCompletes: true);
    final withSink = SoundEventProcessor(
      hapticEngine: hapticEngine,
      historySink: sink,
    );

    final result = await withSink
        .process(event(category: 'sonnette', score: 0.9))
        .timeout(const Duration(seconds: 2));

    expect(result.status, SoundEventStatus.triggered);
    expect(sink.received, hasLength(1));
  });

  test('une erreur du historySink n\'empêche pas process() de retourner '
      'normalement', () async {
    final sink = _RecordingHistorySink(throwsOnRecord: true);
    final withSink = SoundEventProcessor(
      hapticEngine: hapticEngine,
      historySink: sink,
    );

    final result = await withSink
        .process(event(category: 'sonnette', score: 0.9))
        .timeout(const Duration(seconds: 2));

    expect(result.status, SoundEventStatus.triggered);
  });

  test(
    'historySink n\'est jamais appelé pour un résultat non déclenché',
    () async {
      final sink = _RecordingHistorySink();
      final withSink = SoundEventProcessor(
        hapticEngine: hapticEngine,
        historySink: sink,
      );

      await withSink.process(event(category: 'sonnette', score: 0.1));
      // Laisse une chance à un éventuel appel fire-and-forget de s'exécuter
      // avant de vérifier qu'il n'a jamais eu lieu.
      await Future<void>.delayed(Duration.zero);

      expect(sink.received, isEmpty);
    },
  );

  test('un historySink qui lève une exception de façon synchrone '
      '(record() non-async) n\'échappe pas de process()', () async {
    final sink = _RecordingHistorySink(throwsSynchronously: true);
    final withSink = SoundEventProcessor(
      hapticEngine: hapticEngine,
      historySink: sink,
    );

    final result = await withSink
        .process(event(category: 'sonnette', score: 0.9))
        .timeout(const Duration(seconds: 2));

    expect(result.status, SoundEventStatus.triggered);
    expect(sink.received, hasLength(1));
  });
}

/// Double de test pour [HistorySink], utilisé uniquement dans ce fichier.
class _RecordingHistorySink implements HistorySink {
  _RecordingHistorySink({
    this.neverCompletes = false,
    this.throwsOnRecord = false,
    this.throwsSynchronously = false,
  });

  final bool neverCompletes;
  final bool throwsOnRecord;
  final bool throwsSynchronously;
  final List<SoundEventResult> received = [];

  @override
  Future<void> record(SoundEventResult result) {
    received.add(result);
    if (throwsSynchronously) {
      // Volontairement PAS une méthode async : lève avant même de
      // retourner un Future, pour reproduire une implémentation de
      // HistorySink mal écrite (voir le test correspondant).
      throw StateError('panne synchrone simulée du sink');
    }
    if (throwsOnRecord) {
      return Future<void>.error(StateError('panne simulée du sink'));
    }
    if (neverCompletes) {
      return Completer<void>().future;
    }
    return Future<void>.value();
  }
}
