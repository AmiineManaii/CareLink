import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

class DetectionResultDialog extends StatelessWidget {
  final String imagePath;
  final List<DetectedObject> mlObjects;
  final List<Map<String, dynamic>> results;
  final String resultText;
  final VoidCallback onReplay;
  final VoidCallback onDismiss;

  const DetectionResultDialog({
    super.key,
    required this.imagePath,
    required this.mlObjects,
    required this.results,
    required this.resultText,
    required this.onReplay,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = File(imagePath).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    final imgW = decoded?.width.toDouble() ?? 1.0;
    final imgH = decoded?.height.toDouble() ?? 1.0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      title: Row(
        children: [
          const Icon(
            FontAwesomeIcons.magnifyingGlass,
            size: 42,
            color: Colors.teal,
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Text(
              'Identification',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 320,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LayoutBuilder(
                  builder: (_, c) => Stack(
                    children: [
                      Image.file(
                        File(imagePath),
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                      CustomPaint(
                        painter: DetectionPainter(
                          results: results,
                          imageWidth: imgW,
                          imageHeight: imgH,
                          widgetWidth: c.maxWidth,
                          widgetHeight: c.maxHeight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.teal[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                resultText,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (results.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              ...results.map((r) {
                final double conf = r["confidence"] as double;
                final String label = r["labelFr"] as String;
                final String source = r["source"] as String? ?? "tflite";

                IconData sourceIcon;
                Color sourceColor;
                String sourceLabel;

                switch (source) {
                  case "ollama":
                    sourceIcon = Icons.auto_awesome;
                    sourceColor = Colors.deepPurple;
                    sourceLabel = "Ollama";
                    break;
                  case "mlkit":
                    sourceIcon = Icons.blur_on;
                    sourceColor = Colors.orange;
                    sourceLabel = "ML Kit";
                    break;
                  default:
                    sourceIcon = Icons.psychology;
                    sourceColor = Colors.teal;
                    sourceLabel = "TFLite";
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(sourceIcon, size: 22, color: sourceColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: const TextStyle(fontSize: 20)),
                            Text(
                              sourceLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: sourceColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _confColor(conf).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${(conf * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _confColor(conf),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: Colors.deepPurple),
                  SizedBox(width: 4),
                  Text(
                    'Ollama',
                    style: TextStyle(fontSize: 14, color: Colors.deepPurple),
                  ),
                  SizedBox(width: 16),
                  Icon(Icons.psychology, size: 16, color: Colors.teal),
                  SizedBox(width: 4),
                  Text(
                    'TFLite',
                    style: TextStyle(fontSize: 14, color: Colors.teal),
                  ),
                  SizedBox(width: 16),
                  Icon(Icons.blur_on, size: 16, color: Colors.orange),
                  SizedBox(width: 4),
                  Text(
                    'ML Kit',
                    style: TextStyle(fontSize: 14, color: Colors.orange),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.all(24),
      actions: [
        ElevatedButton.icon(
          onPressed: onReplay,
          icon: const Icon(Icons.volume_up, color: Colors.white, size: 28),
          label: const Text(
            'RÉÉCOUTER',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal[400],
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 70),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: onDismiss,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal[600],
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 80),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Text(
            'MERCI',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Color _confColor(double c) => c >= 0.70
      ? Colors.green
      : c >= 0.45
      ? Colors.orange
      : Colors.red;
}

class DetectionPainter extends CustomPainter {
  final List<Map<String, dynamic>> results;
  final double imageWidth, imageHeight, widgetWidth, widgetHeight;

  const DetectionPainter({
    required this.results,
    required this.imageWidth,
    required this.imageHeight,
    required this.widgetWidth,
    required this.widgetHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scale =
        (widgetWidth / imageWidth) < (widgetHeight / imageHeight)
        ? widgetWidth / imageWidth
        : widgetHeight / imageHeight;
    final double ox = (widgetWidth - imageWidth * scale) / 2;
    final double oy = (widgetHeight - imageHeight * scale) / 2;

    for (final r in results) {
      if (!r.containsKey("box")) continue;
      final Rect box = r["box"] as Rect;
      final double conf = r["confidence"] as double;
      final String label = r["labelFr"] as String? ?? r["label"] as String;
      final String source = r["source"] as String? ?? "tflite";

      Color color;
      if (source == "mlkit") {
        color = Colors.orangeAccent;
      } else if (source == "ollama") {
        color = Colors.deepPurpleAccent;
      } else {
        color = conf >= 0.70 ? Colors.greenAccent : Colors.tealAccent;
      }

      canvas.drawRect(
        Rect.fromLTRB(
          ox + box.left * scale,
          oy + box.top * scale,
          ox + box.right * scale,
          oy + box.bottom * scale,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..color = color,
      );

      (TextPainter(
        text: TextSpan(
          text: ' $label ${(conf * 100).toStringAsFixed(0)}% ',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.black54,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout()).paint(
        canvas,
        Offset(ox + box.left * scale, oy + box.top * scale - 20),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
