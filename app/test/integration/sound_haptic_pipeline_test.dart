import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/haptics/haptic_engine.dart';
import 'package:izahay/models/audio_frame.dart';
import 'package:izahay/models/sound_detection_result.dart';
import 'package:izahay/services/audio_preprocessing_service.dart';
import 'package:izahay/services/sound_haptic_pipeline.dart';
import 'package:izahay/services/yamnet_service.dart';
import 'package:izahay/sound_events/sound_event_result.dart';
import 'dart:typed_data';

import '../haptics/fake_vibration_executor.dart';

/// Micro factice : ne capte rien, mais permet au test de pousser à la main
/// une image audio dans le pipeline, comme le ferait le vrai micro.
class FakeAudioService extends AudioPreprocessingService {
  void Function(AudioFrame frame)? onFrame;
  bool running = false;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> start({
    required void Function(AudioFrame frame) onFrame,
    void Function(AudioPreprocessingStats stats)? onStats,
  }) async {
    this.onFrame = onFrame;
    running = true;
    return true;
  }

  @override
  Future<void> stop() async {
    running = false;
    onFrame = null;
  }

  @override
  Future<void> dispose() async {}

  /// Simule l'arrivée d'une seconde d'audio (silence).
  void pushFrame() => onFrame?.call(AudioFrame(
        samples: Float32List(16000),
        sampleRate: 16000,
        numChannels: 1,
      ));
}

/// IA factice : renvoie les scores YAMNet que le test lui a donnés.
class FakeYamnet extends YamnetService {
  List<YamnetResult> next = [];

  @override
  bool get isLoaded => true;

  @override
  Future<void> loadModel() async {}

  @override
  List<YamnetResult> classify(AudioFrame frame) => next;

  @override
  void dispose() {}
}

YamnetResult _y(String label, double score) =>
    YamnetResult(index: 0, label: label, score: score);

SoundDetectionResult _det(String category, double score, int priority) =>
    SoundDetectionResult(
      category: category,
      yamnetClass: 'x',
      score: score,
      confirmed: true,
      vibrationPriority: priority,
      timestamp: DateTime.now(),
    );

void main() {
  late FakeVibrationExecutor executor;
  late FakeAudioService audio;
  late FakeYamnet yamnet;
  late SoundHapticPipeline pipeline;

  setUp(() async {
    executor = FakeVibrationExecutor();
    audio = FakeAudioService();
    yamnet = FakeYamnet();
    pipeline = SoundHapticPipeline(
      hapticEngine: HapticEngine(executor: executor),
      audioService: audio,
      yamnetService: yamnet,
    );
    await pipeline.loadModel();
    await pipeline.start();
  });

  /// Pousse une image audio dont YAMNet reconnaît [label] avec [score], et
  /// laisse le pipeline finir son traitement asynchrone.
  Future<void> hear(String label, double score) async {
    yamnet.next = [_y(label, score)];
    audio.pushFrame();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  test('TEST 1+2 — un premier son reconnu (aboiement) fait vibrer son motif',
      () async {
    await hear('Bark', 0.91);

    expect(pipeline.lastResult!.event.category, 'dog_bark');
    expect(pipeline.lastResult!.event.source, 'microphone');
    expect(pipeline.lastResult!.isSimulation, isFalse);
    expect(pipeline.lastResult!.status, SoundEventStatus.triggered);
    // dog_bark = 3 vibrations longues : [0, v, p, v, p, v, 0].
    expect(executor.vibrateCalls.single, [0, 500, 150, 500, 150, 500, 0]);
  });

  test('TEST 3+4 — un deuxième son (sonnette) fait vibrer un motif différent',
      () async {
    await hear('Bark', 0.91);
    await hear('Doorbell', 0.9);

    expect(executor.vibrateCalls.length, 2);
    expect(executor.vibrateCalls[1], [0, 150, 150, 150, 0]); // 2 courtes
    expect(executor.vibrateCalls[1], isNot(executor.vibrateCalls[0]));
  });

  test('TEST 5 — un score sous le seuil ne fait pas vibrer', () async {
    // Le filtre IA (EMA) retient déjà ce qui est trop faible : rien n'arrive
    // jusqu'au moteur.
    await hear('Bark', 0.05);

    expect(executor.vibrateCalls, isEmpty);
  });

  test('TEST 5b — le seuil du processor est aussi appliqué', () async {
    await pipeline.handleDetections([_det('dog_bark', 0.1, 1)]);

    expect(pipeline.lastResult!.status, SoundEventStatus.belowThreshold);
    expect(executor.vibrateCalls, isEmpty);
  });

  test('TEST 6 — une catégorie désactivée ne fait pas vibrer', () async {
    pipeline.setCategoryEnabled('dog_bark', false);
    await hear('Bark', 0.95);

    expect(pipeline.lastResult!.status, SoundEventStatus.categoryDisabled);
    expect(executor.vibrateCalls, isEmpty);
  });

  test('TEST 7 — après l\'arrêt de l\'écoute, plus aucune détection',
      () async {
    await pipeline.stop();
    expect(pipeline.isListening, isFalse);

    // Même une détection déjà en vol est ignorée.
    await pipeline.handleDetections([_det('dog_bark', 0.95, 1)]);
    audio.pushFrame(); // le micro est coupé : rien ne part

    expect(executor.vibrateCalls, isEmpty);
    expect(pipeline.lastResult, isNull);
  });

  test('TEST 8 — un son prolongé ne provoque pas de vibrations en rafale',
      () async {
    for (var i = 0; i < 5; i++) {
      await hear('Bark', 0.95);
    }

    expect(executor.vibrateCalls.length, 1);
    expect(pipeline.lastResult!.status, SoundEventStatus.inCooldown);
  });

  test('la détection la plus prioritaire fait vibrer, pas la plus faible',
      () async {
    // Alarme incendie (P5) et aboiement (P1) dans la même seconde.
    await pipeline.handleDetections(
        [_det('fire_alarm', 0.9, 5), _det('dog_bark', 0.9, 1)]);

    expect(executor.vibrateCalls.length, 1);
    expect(pipeline.lastTriggered!.event.category, 'fire_alarm');
  });

  test('un son simulé est marqué comme simulé', () async {
    final result = await pipeline.simulate('doorbell', 0.95);

    expect(result.status, SoundEventStatus.triggered);
    expect(result.isSimulation, isTrue);
    expect(executor.vibrateCalls.length, 1);
  });

  test('tester la vibration joue le motif sans règle de seuil', () async {
    await pipeline.testVibration('car_horn');

    expect(executor.vibrateCalls.single, [0, 900, 0]);
  });

  test('tester la vibration signale un appareil sans vibreur', () async {
    executor.hasVibratorResult = false;
    await pipeline.testVibration('car_horn');

    expect(pipeline.error, 'Appareil sans vibreur');
  });
}
