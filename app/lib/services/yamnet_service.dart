import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/audio_frame.dart';

class YamnetResult {
  final int index;
  final String label;
  final double score;

  const YamnetResult({
    required this.index,
    required this.label,
    required this.score,
  });
}

class YamnetService {
  static const int expectedSamples = 15600;
  static const String modelAsset = 'assets/models/yamnet.tflite';
  static const String labelsAsset = 'assets/models/yamnet_class_map.csv';

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isLoaded = false;
  String? _error;
  List<int> _inputShape = [];
  List<int> _outputShape = [];

  bool get isLoaded => _isLoaded;
  String? get error => _error;
  List<int> get inputShape => _inputShape;
  List<int> get outputShape => _outputShape;
  int get labelCount => _labels.length;

  Future<void> loadModel() async {
    try {
      final modelData = await rootBundle.load(modelAsset);
      _interpreter = Interpreter.fromBuffer(modelData.buffer.asUint8List());

      _interpreter!.resizeInputTensor(0, [expectedSamples]);
      _interpreter!.allocateTensors();

      _inputShape = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;

      final csvData = await rootBundle.loadString(labelsAsset);
      _labels = _parseLabels(csvData);

      if (_labels.isEmpty) {
        throw Exception('No labels parsed from $labelsAsset');
      }

      _isLoaded = true;
      _error = null;
    } catch (e) {
      _error = e.toString();
      _isLoaded = false;
    }
  }

  List<String> _parseLabels(String csvData) {
    final lines = csvData.split('\n');
    final labels = <String>[];
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final firstComma = line.indexOf(',');
      if (firstComma < 0) continue;
      final secondComma = line.indexOf(',', firstComma + 1);
      if (secondComma < 0) continue;
      var displayName = line.substring(secondComma + 1);
      if (displayName.startsWith('"') && displayName.endsWith('"')) {
        displayName = displayName.substring(1, displayName.length - 1);
      }
      labels.add(displayName);
    }
    return labels;
  }

  List<YamnetResult> classify(AudioFrame frame) {
    if (!_isLoaded || _interpreter == null) {
      _error = 'Model not loaded';
      return [];
    }

    try {
      final input = Float32List(expectedSamples);
      final copyLen =
          frame.sampleCount < expectedSamples ? frame.sampleCount : expectedSamples;
      for (int i = 0; i < copyLen; i++) {
        input[i] = frame.samples[i];
      }

      final numOutputs = _interpreter!.getOutputTensors().length;
      final outputMap = <int, Object>{};
      for (int i = 0; i < numOutputs; i++) {
        final shape = _interpreter!.getOutputTensor(i).shape;
        outputMap[i] = _allocateOutput(shape);
      }

      _interpreter!.runForMultipleInputs([input], outputMap);

      final scores = _extractScores(outputMap[0]!);
      if (scores.isEmpty) {
        _error = 'No scores returned from model';
        return [];
      }

      final results = <YamnetResult>[];
      for (int i = 0; i < scores.length && i < _labels.length; i++) {
        results.add(YamnetResult(
          index: i,
          label: _labels[i],
          score: scores[i],
        ));
      }

      results.sort((a, b) => b.score.compareTo(a.score));
      _error = null;
      return results;
    } catch (e) {
      _error = 'Inference failed: $e';
      return [];
    }
  }

  Object _allocateOutput(List<int> shape) {
    if (shape.length == 1) {
      return List<double>.filled(shape[0], 0.0);
    }
    if (shape.length == 2) {
      return List.generate(
        shape[0],
        (_) => List<double>.filled(shape[1], 0.0),
      );
    }
    if (shape.length == 3) {
      return List.generate(
        shape[0],
        (_) => List.generate(
          shape[1],
          (_) => List<double>.filled(shape[2], 0.0),
        ),
      );
    }
    return List<double>.filled(shape.reduce((a, b) => a * b), 0.0);
  }

  List<double> _extractScores(Object raw) {
    if (raw is List<double>) return raw;
    if (raw is List && raw.isNotEmpty) {
      final first = raw[0];
      if (first is List<double>) return first;
      if (first is List && first.isNotEmpty && first[0] is double) {
        return first.cast<double>();
      }
    }
    return [];
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }
}
