import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class OCRResultDialog extends StatelessWidget {
  final String text;
  final double fontSize;
  final VoidCallback onRead;
  final VoidCallback onDismiss;

  const OCRResultDialog({
    super.key,
    required this.text,
    required this.fontSize,
    required this.onRead,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      title: Row(children: [
        const Icon(Icons.description, size: 42, color: Colors.blue),
        const SizedBox(width: 20),
        const Text('Texte détecté',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
      ]),
      content: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 400),
        child: SingleChildScrollView(
          child: Text(text,
              style: TextStyle(
                  fontSize: fontSize + 4, color: Colors.black87, height: 1.5)),
        ),
      ),
      actionsPadding: const EdgeInsets.all(24),
      actions: [
        Column(children: [
          ElevatedButton.icon(
            onPressed: onRead,
            icon: const Icon(FontAwesomeIcons.volumeHigh, size: 32, color: Colors.white),
            label: const Text('LIRE À VOIX HAUTE',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 80),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Texte copié !', style: TextStyle(fontSize: 20)),
                  ));
                },
                child: const Text('COPIER',
                    style: TextStyle(fontSize: 22, color: Colors.blue)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: onDismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black87,
                  minimumSize: const Size(double.infinity, 80),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: const Text('FERMER',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ]),
      ],
    );
  }
}
