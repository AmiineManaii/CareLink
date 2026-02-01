import 'package:tflite_flutter/tflite_flutter.dart';
import 'face_utils.dart';
import 'package:image/image.dart' as img;

class FaceRecognitionService {
  late Interpreter _interpreter;

  FaceRecognitionService() {
    _loadModel();
  }

  Future<void> _loadModel() async {
    _interpreter = await Interpreter.fromAsset('assets/mobilefacenet.tflite');
  }

  // Convertit l'image crop et resize en embedding
  List<double> getEmbedding(img.Image faceImage) {
    // S'assurer que l'image est 112x112 et 3 canaux
    final prepared = img.copyResize(faceImage, width: 112, height: 112);
    // Aplatir en float32 puis remodeler en [1, 112, 112, 3]
    final inputFlat = imageToByteList(prepared).toList();
    final input = inputFlat.reshape([1, 112, 112, 3]);
    final output = List<double>.filled(192, 0).reshape([1, 192]); // 192 dimensions
    _interpreter.run(input, output);
    return List<double>.from(output[0]);
  }

  void close() {
    _interpreter.close();
  }
}
