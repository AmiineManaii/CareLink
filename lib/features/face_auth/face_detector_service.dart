import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectorService {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableLandmarks: true,
      enableContours: true,
    ),
  );

  Future<List<Face>> detectFaces(InputImage image) async {
    return await _faceDetector.processImage(image);
  }

  void dispose() {
    _faceDetector.close();
  }
}
