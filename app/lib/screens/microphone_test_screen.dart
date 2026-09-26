import 'package:flutter/material.dart';
import '../services/audio_capture_service.dart';

class MicrophoneTestScreen extends StatefulWidget {
  const MicrophoneTestScreen({super.key});

  @override
  State<MicrophoneTestScreen> createState() => _MicrophoneTestScreenState();
}

class _MicrophoneTestScreenState extends State<MicrophoneTestScreen> {
  final AudioCaptureService _audioService = AudioCaptureService();
  bool _isActive = false;
  int _bytesReceived = 0;
  String _statusMessage = 'Microphone arrêté';

  Future<void> _startCapture() async {
    final granted = await _audioService.requestPermission();
    if (!granted) {
      setState(() => _statusMessage = 'Permission microphone refusée');
      return;
    }

    final started = await _audioService.startCapture(
      onData: (bytesReceived) {
        if (mounted) {
          setState(() => _bytesReceived = bytesReceived);
        }
      },
    );

    if (started) {
      setState(() {
        _isActive = true;
        _statusMessage = 'Microphone actif';
      });
    }
  }

  Future<void> _stopCapture() async {
    await _audioService.stopCapture();
    setState(() {
      _isActive = false;
      _bytesReceived = 0;
      _statusMessage = 'Microphone arrêté';
    });
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SENSIA')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mic,
                size: 72,
                color: _isActive ? Colors.green : null,
              ),
              const SizedBox(height: 16),
              const Text(
                'MICROPHONE TEST',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _isActive ? null : _startCapture,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('DÉMARRER'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: _isActive ? _stopCapture : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('ARRÊTER'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'État : $_statusMessage',
                style: TextStyle(
                  fontSize: 18,
                  color: _isActive ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              if (_isActive) ...[
                const Text(
                  'Données audio reçues :',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatBytes(_bytesReceived),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Flux audio en cours...',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
