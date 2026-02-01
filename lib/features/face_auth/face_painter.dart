import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final bool ready;

  FacePainter(this.faces, this.imageSize, {this.ready = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ready ? Colors.green : Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Calculer le ratio pour garder les proportions de l'image
    final double imageAspectRatio = imageSize.width / imageSize.height;
    final double canvasAspectRatio = size.width / size.height;
    
    double scale;
    double dx = 0;
    double dy = 0;
    
    if (canvasAspectRatio > imageAspectRatio) {
      // Le canvas est plus large que l'image => marges sur les côtés
      scale = size.height / imageSize.height;
      dx = (size.width - imageSize.width * scale) / 2;
    } else {
      // Le canvas est plus étroit que l'image => marges en haut/bas
      scale = size.width / imageSize.width;
      dy = (size.height - imageSize.height * scale) / 2;
    }
    
    // Fonction pour transformer les coordonnées
    double transformX(double x) => dx + x * scale;
    double transformY(double y) => dy + y * scale;

    for (var face in faces) {
      final rect = Rect.fromLTRB(
        transformX(face.boundingBox.left),
        transformY(face.boundingBox.top),
        transformX(face.boundingBox.right),
        transformY(face.boundingBox.bottom),
      );
      canvas.drawRect(rect, paint);

      // Dessiner les contours
      final paintContours = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      void paintContour(FaceContourType type) {
        final contour = face.contours[type];
        if (contour?.points != null) {
          final pts = contour!.points;
          if (pts.length > 1) {
            final path = Path();
            final first = Offset(
              transformX(pts.first.x.toDouble()),
              transformY(pts.first.y.toDouble()),
            );
            path.moveTo(first.dx, first.dy);
            for (int i = 1; i < pts.length; i++) {
              final p = Offset(
                transformX(pts[i].x.toDouble()),
                transformY(pts[i].y.toDouble()),
              );
              path.lineTo(p.dx, p.dy);
            }
            canvas.drawPath(path, paintContours);
          }
        }
      }

      for (final type in FaceContourType.values) {
        paintContour(type);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}