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

    for (var face in faces) {
      final rect = Rect.fromLTRB(
        face.boundingBox.left * size.width / imageSize.width,
        face.boundingBox.top * size.height / imageSize.height,
        face.boundingBox.right * size.width / imageSize.width,
        face.boundingBox.bottom * size.height / imageSize.height,
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
              pts.first.x.toDouble() * size.width / imageSize.width,
              pts.first.y.toDouble() * size.height / imageSize.height,
            );
            path.moveTo(first.dx, first.dy);
            for (int i = 1; i < pts.length; i++) {
              final p = Offset(
                pts[i].x.toDouble() * size.width / imageSize.width,
                pts[i].y.toDouble() * size.height / imageSize.height,
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
