import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final bool ready;

  FacePainter(this.faces, this.imageSize, {this.ready = false});

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = ready ? Colors.green : Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final double imageAspectRatio = imageSize.width / imageSize.height;
    final double canvasAspectRatio = size.width / size.height;
    
    double scale;
    double dx = 0;
    double dy = 0;
    
    if (canvasAspectRatio > imageAspectRatio) {
      scale = size.height / imageSize.height;
      dx = (size.width - imageSize.width * scale) / 2;
    } else {
      scale = size.width / imageSize.width;
      dy = (size.height - imageSize.height * scale) / 2;
    }
    
    double transformX(double x) => dx + x * scale;
    double transformY(double y) => dy + y * scale;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = 0.35 * (size.shortestSide);
    final dimPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;
    final dimPaint = Paint()..color = Colors.black54;
    canvas.drawPath(dimPath, dimPaint);
    canvas.drawCircle(center, radius, borderPaint);

    for (var face in faces) {
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
