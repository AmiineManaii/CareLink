import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Convert CameraImage to img.Image (package:image)
img.Image convertCameraImageToImage(CameraImage cameraImage) {
  // On prend le plan Y (grayscale) pour simplifier
  final bytes = cameraImage.planes[0].bytes;
  return img.Image.fromBytes(
    cameraImage.width,
    cameraImage.height,
    bytes,
    format: img.Format.luminance,
  );
}

/// Rotate image to match camera sensor orientation used by ML Kit
img.Image rotateForSensor(img.Image image, int rotationDegrees) {
  switch (rotationDegrees) {
    case 90:
      return img.copyRotate(image,90);
    case 180:
      return img.copyRotate(image,  180);
    case 270:
      return img.copyRotate(image, 270);
    default:
      return image;
  }
}

/// Crop le visage à partir de l'image et du boundingBox
img.Image cropFace(img.Image originalImage, Face face) {
  final rect = face.boundingBox;

  int x = rect.left.toInt().clamp(0, originalImage.width - 1);
  int y = rect.top.toInt().clamp(0, originalImage.height - 1);
  int w = rect.width.toInt().clamp(0, originalImage.width - x);
  int h = rect.height.toInt().clamp(0, originalImage.height - y);

  return img.copyCrop(originalImage, x, y, w, h);
}

/// Resize l'image du visage pour TFLite
img.Image resizeFace(img.Image faceImage, int size) {
  return img.copyResize(faceImage, width: size, height: size);
}

Float32List imageToByteList(img.Image image) {
  final Float32List buffer = Float32List(1 * 112 * 112 * 3);
  int idx = 0;
  for (int y = 0; y < 112; y++) {
    for (int x = 0; x < 112; x++) {
      final pixel = image.getPixel(x, y);
      buffer[idx++] = (img.getRed(pixel) - 128) / 128.0;
      buffer[idx++] = (img.getGreen(pixel) - 128) / 128.0;
      buffer[idx++] = (img.getBlue(pixel) - 128) / 128.0;
    }
  }
  return buffer;
}
