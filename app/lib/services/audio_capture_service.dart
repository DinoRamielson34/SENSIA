import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioCaptureService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _streamSub;
  bool _isRecording = false;
  int _bytesReceived = 0;

  static const int sampleRate = 16000;
  static const int numChannels = 1;
  static const AudioEncoder encoder = AudioEncoder.pcm16bits;

  bool get isRecording => _isRecording;
  int get bytesReceived => _bytesReceived;

  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> startCapture({
    required void Function(Uint8List rawData) onRawData,
  }) async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return false;

    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: encoder,
        sampleRate: sampleRate,
        numChannels: numChannels,
      ),
    );

    _isRecording = true;
    _bytesReceived = 0;

    _streamSub = stream.listen((data) {
      _bytesReceived += data.length;
      onRawData(data);
    });

    return true;
  }

  Future<void> stopCapture() async {
    await _streamSub?.cancel();
    _streamSub = null;
    if (_isRecording) {
      await _recorder.stop();
    }
    _isRecording = false;
    _bytesReceived = 0;
  }

  Future<void> dispose() async {
    await stopCapture();
    _recorder.dispose();
  }
}
