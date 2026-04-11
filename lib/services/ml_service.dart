import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class MLService {
  ObjectDetector? _objectDetector;
  Interpreter? _interpreter;
  List<String>? _labels;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  bool get isModelLoaded => _interpreter != null && _labels != null;

  Future<void> initialize() async {
    _initMLKit();
    await _loadClassifier();
  }

  void _initMLKit() {
    _objectDetector = ObjectDetector(
      options: ObjectDetectorOptions(
        mode: DetectionMode.single,
        classifyObjects: true,
        multipleObjects: true,
      ),
    );
    debugPrint('✅ ML Kit ObjectDetector initialisé');
  }

  Future<void> _loadClassifier() async {
    try {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(
        'assets/detection_final.tflite',
        options: options,
      );

      final raw = await rootBundle.loadString('assets/labels_90.txt');
      _labels = raw.split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      final inp = _interpreter!.getInputTensor(0);
      final outCount = _interpreter!.getOutputTensors().length;
      debugPrint('✅ Classifier chargé');
      debugPrint('   Input : ${inp.shape} | ${inp.type}');
      debugPrint('   Outputs count: $outCount');
      for (int i = 0; i < outCount; i++) {
        final out = _interpreter!.getOutputTensor(i);
        debugPrint('   Output $i: ${out.shape} | ${out.type}');
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement classifier: $e');
    }
  }

  Future<List<DetectedObject>> detectObjects(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    return await _objectDetector!.processImage(inputImage);
  }

  Future<String> recognizeText(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognized = await _textRecognizer.processImage(inputImage);
    return recognized.text.trim();
  }

  Future<Map<String, dynamic>?> classifyImage(img.Image source) async {
    if (_interpreter == null || _labels == null) return null;

    try {
      final inputTensor = _interpreter!.getInputTensor(0);
      final inputShape = inputTensor.shape;
      final inputType = inputTensor.type;
      final int h = inputShape[1];
      final int w = inputShape[2];

      final resized = img.copyResize(source, width: w, height: h);

      Object input;
      if (inputType == TensorType.uint8) {
        final buffer = Uint8List(h * w * 3);
        int idx = 0;
        for (int y = 0; y < h; y++) {
          for (int x = 0; x < w; x++) {
            final p = resized.getPixel(x, y);
            buffer[idx++] = img.getRed(p);
            buffer[idx++] = img.getGreen(p);
            buffer[idx++] = img.getBlue(p);
          }
        }
        input = buffer.reshape([1, h, w, 3]);
      } else {
        final buffer = Float32List(h * w * 3);
        int idx = 0;
        for (int y = 0; y < h; y++) {
          for (int x = 0; x < w; x++) {
            final p = resized.getPixel(x, y);
            buffer[idx++] = img.getRed(p) / 255.0;
            buffer[idx++] = img.getGreen(p) / 255.0;
            buffer[idx++] = img.getBlue(p) / 255.0;
          }
        }
        input = buffer.reshape([1, h, w, 3]);
      }

      final outTensors = _interpreter!.getOutputTensors();
      final Map<int, Object> outputs = {};

      for (int i = 0; i < outTensors.length; i++) {
        final shape = outTensors[i].shape;
        final type = outTensors[i].type;
        if (type == TensorType.uint8) {
          outputs[i] = _createUint8Buffer(shape);
        } else {
          outputs[i] = _createFloat32Buffer(shape);
        }
      }

      _interpreter!.runForMultipleInputs([input], outputs);

      List<num>? scores;
      List<int>? classes;

      for (int i = 0; i < outTensors.length; i++) {
        final shape = outTensors[i].shape;
        if (shape.length == 2 && shape[0] == 1) {
          final data = (outputs[i] as List)[0] as List;
          final isInt = data.every((e) => e is int || (e is double && e == e.toInt()));
          if (isInt && data.any((e) => e != 0)) {
            classes ??= data.map((e) => (e as num).toInt()).toList();
          } else {
            scores ??= data.map((e) => e as num).toList();
          }
        } else if (shape.length == 1 && classes == null && scores == null) {
          final data = outputs[i] as List;
          scores = data.map((e) => e as num).toList();
          classes = List.generate(scores.length, (i) => i);
        }
      }

      if ((scores == null || classes == null) && outTensors.isNotEmpty) {
        if (outTensors[0].shape.length == 2) {
          final data = (outputs[0] as List)[0] as List;
          scores = data.map((e) => e is int ? e / 255.0 : e as num).toList();
          classes = List.generate(scores.length, (i) => i);
        }
      }

      if (scores == null || classes == null || scores.isEmpty) return null;

      int bestIdx = -1;
      double maxScore = -1.0;
      for (int i = 0; i < scores.length; i++) {
        if (scores[i] > maxScore) {
          maxScore = scores[i].toDouble();
          bestIdx = i;
        }
      }

      if (bestIdx == -1 || maxScore < 0.25) return null;

      final int classId = classes[bestIdx];
      int labelIdx = classId;
      if (labelIdx >= _labels!.length || _labels![labelIdx] == "n/a") {
        if (classId > 0 && (classId - 1) < _labels!.length) {
          labelIdx = classId - 1;
        }
      }

      if (labelIdx < 0 || labelIdx >= _labels!.length || _labels![labelIdx] == "n/a") return null;

      return {
        "label": _labels![labelIdx],
        "confidence": maxScore,
      };
    } catch (e) {
      debugPrint('❌ MLService._classifyImage: $e');
      return null;
    }
  }

  Object _createUint8Buffer(List<int> shape) {
    final size = shape.isEmpty ? 0 : shape.reduce((a, b) => a * b);
    return Uint8List(size).reshape(shape);
  }

  Object _createFloat32Buffer(List<int> shape) {
    final size = shape.isEmpty ? 0 : shape.reduce((a, b) => a * b);
    return Float32List(size).reshape(shape);
  }

  void dispose() {
    _objectDetector?.close();
    _interpreter?.close();
    _textRecognizer.close();
  }
}
