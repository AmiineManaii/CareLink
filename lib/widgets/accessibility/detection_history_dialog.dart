import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'detection_result_dialog.dart';

class DetectionHistoryDialog extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final Function(String) onSpeak;

  const DetectionHistoryDialog({
    super.key,
    required this.history,
    required this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      title: Row(
        children: [
          const Icon(
            FontAwesomeIcons.history,
            size: 32,
            color: Colors.teal,
          ),
          const SizedBox(width: 16),
          const Text(
            'Historique',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 30),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 500,
        child: history.isEmpty
            ? const Center(
                child: Text(
                  'Aucune détection récente',
                  style: TextStyle(fontSize: 20, color: Colors.grey),
                ),
              )
            : ListView.separated(
                itemCount: history.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final item = history[index];
                  final String labelFr = item['labelFr'] ?? 'Inconnu';
                  final String imageBase64 = item['image'] ?? '';
                  final DateTime timestamp = DateTime.parse(item['timestamp']);
                  final String timeStr = DateFormat('dd/MM HH:mm').format(timestamp);

                  Uint8List? imageBytes;
                  if (imageBase64.isNotEmpty) {
                    try {
                      imageBytes = base64Decode(imageBase64);
                    } catch (e) {
                      debugPrint('Error decoding history image: $e');
                    }
                  }

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    leading: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: imageBytes != null
                            ? Image.memory(imageBytes, fit: BoxFit.cover)
                            : const Icon(Icons.image_not_supported),
                      ),
                    ),
                    title: Text(
                      labelFr,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      timeStr,
                      style: const TextStyle(fontSize: 16),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.volume_up, color: Colors.teal, size: 28),
                      onPressed: () => onSpeak("C'est $labelFr."),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => DetectionResultDialog(
                          imagePath: "",
                          imageBase64: imageBase64,
                          mlObjects: const [],
                          results: [
                            {
                              "label": item['label'],
                              "labelFr": labelFr,
                              "confidence": 1.0,
                              "source": "ollama",
                            },
                          ],
                          resultText: "C'est $labelFr.",
                          onReplay: () => onSpeak("C'est $labelFr."),
                          onDismiss: () => Navigator.pop(context),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
