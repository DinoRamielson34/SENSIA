import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/haptics/haptic_exceptions.dart';
import 'package:izahay/haptics/vibration_executor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('mg.izahay.izahay/haptics');
  const executor = MethodChannelVibrationExecutor();

  void mockChannel(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('hasVibrator retourne la valeur renvoyée par le canal natif', () async {
    mockChannel((call) async {
      expect(call.method, 'hasVibrator');
      return true;
    });
    expect(await executor.hasVibrator(), isTrue);
  });

  test('vibrate envoie les timings au canal natif', () async {
    List<Object?>? receivedTimings;
    mockChannel((call) async {
      expect(call.method, 'vibrate');
      receivedTimings = (call.arguments as Map)['timings'] as List<Object?>;
      return null;
    });
    await executor.vibrate([0, 150, 150, 150]);
    expect(receivedTimings, [0, 150, 150, 150]);
  });

  test('cancel appelle la méthode native cancel', () async {
    var called = false;
    mockChannel((call) async {
      called = true;
      expect(call.method, 'cancel');
      return null;
    });
    await executor.cancel();
    expect(called, isTrue);
  });

  // Le faux messager de test simule un vrai aller-retour binaire : l'erreur
  // levée dans mockChannel() est encodée puis décodée en une NOUVELLE
  // PlatformException côté executor (même code/message, autre instance).
  // On vérifie donc le contenu de la cause, pas son identité.
  Matcher wrapsPlatformExceptionWithMessage(String message) {
    return isA<HapticPlatformException>().having(
      (e) => e.cause,
      'cause',
      isA<PlatformException>().having(
        (p) => p.message,
        'message',
        message,
      ),
    );
  }

  test('une PlatformException de hasVibrator est enveloppée dans '
      'HapticPlatformException, cause d\'origine préservée', () async {
    mockChannel((call) async {
      throw PlatformException(code: 'ERROR', message: 'panne simulée');
    });

    await expectLater(
      () => executor.hasVibrator(),
      throwsA(wrapsPlatformExceptionWithMessage('panne simulée')),
    );
  });

  test('une PlatformException de vibrate est enveloppée dans '
      'HapticPlatformException, cause d\'origine préservée', () async {
    mockChannel((call) async {
      throw PlatformException(code: 'ERROR', message: 'panne simulée');
    });

    await expectLater(
      () => executor.vibrate([0, 100, 0]),
      throwsA(wrapsPlatformExceptionWithMessage('panne simulée')),
    );
  });

  test('une PlatformException de cancel est enveloppée dans '
      'HapticPlatformException, cause d\'origine préservée', () async {
    mockChannel((call) async {
      throw PlatformException(code: 'ERROR', message: 'panne simulée');
    });

    await expectLater(
      () => executor.cancel(),
      throwsA(wrapsPlatformExceptionWithMessage('panne simulée')),
    );
  });

  test('hasVibrator enveloppe MissingPluginException (aucun pont natif '
      'enregistré, ex. un second FlutterEngine) dans HapticPlatformException',
      () async {
    // Pas de mockChannel() ici : aucun handler n'est enregistré sur le
    // canal, ce qui reproduit un FlutterEngine sans le pont natif.
    await expectLater(
      () => executor.hasVibrator(),
      throwsA(isA<HapticPlatformException>()),
    );
  });

  test('vibrate enveloppe MissingPluginException dans HapticPlatformException',
      () async {
    await expectLater(
      () => executor.vibrate([0, 100, 0]),
      throwsA(isA<HapticPlatformException>()),
    );
  });

  test('cancel enveloppe MissingPluginException dans HapticPlatformException',
      () async {
    await expectLater(
      () => executor.cancel(),
      throwsA(isA<HapticPlatformException>()),
    );
  });
}
