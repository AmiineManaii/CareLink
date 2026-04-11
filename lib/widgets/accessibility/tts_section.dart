import 'package:flutter/material.dart';

class TTSSection extends StatelessWidget {
  final TextEditingController controller;
  final double fontSize;
  final double ttsRate;
  final Function(double) onRateChanged;
  final Function(double) onFontSizeChanged;
  final VoidCallback onRead;

  const TTSSection({
    super.key,
    required this.controller,
    required this.fontSize,
    required this.ttsRate,
    required this.onRateChanged,
    required this.onFontSizeChanged,
    required this.onRead,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.volume_up, size: 48, color: Colors.orange),
            SizedBox(width: 20),
            Expanded(
              child: Text('Lire un texte à voix haute',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 28),
          TextField(
            controller: controller,
            maxLines: 5,
            style: TextStyle(fontSize: fontSize),
            decoration: InputDecoration(
              hintText: 'Écrivez ou collez le texte ici…',
              hintStyle: const TextStyle(fontSize: 22),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, size: 36, color: Colors.grey),
                onPressed: () => controller.clear(),
              ),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Colors.orange, width: 3)),
              contentPadding: const EdgeInsets.all(24),
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: onRead,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 80),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('🔊 Lire le texte',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 40),
          const Text('Vitesse de lecture',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 16,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 22),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 34),
              valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
              valueIndicatorColor: Colors.orange,
              valueIndicatorTextStyle:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            child: Slider(
              value: ttsRate,
              min: 0.1,
              max: 1.0,
              divisions: 18,
              label: ttsRate.toStringAsFixed(1),
              onChanged: onRateChanged,
            ),
          ),
          Center(
            child: Text(
              'Vitesse actuelle : ${ttsRate.toStringAsFixed(1)}',
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
          ),
          const SizedBox(height: 40),
          const Text('Taille du texte',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 16,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 22),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 34),
            ),
            child: Slider(
              value: fontSize,
              min: 16,
              max: 32,
              divisions: 16,
              label: fontSize.toInt().toString(),
              onChanged: onFontSizeChanged,
            ),
          ),
          Center(
            child: Text(
              'Taille actuelle : ${fontSize.toInt()} px',
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }
}
