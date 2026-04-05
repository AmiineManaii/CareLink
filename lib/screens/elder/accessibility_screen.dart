// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/feature_card.dart';

class AccessibilityScreen extends StatefulWidget {
  const AccessibilityScreen({super.key});

  @override
  State<AccessibilityScreen> createState() => _AccessibilityScreenState();
}

class _AccessibilityScreenState extends State<AccessibilityScreen> {
  bool _isScanning = false;
  bool _isListening = false;
  bool _highContrast = false;
  bool _visualAlertEnabled = false;

  final TextEditingController _textController = TextEditingController();
  double _fontSize = 20.0;
  double _ttsRate = 0.5;

  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initTts();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _highContrast = prefs.getBool('highContrast') ?? false;
      _fontSize = prefs.getDouble('fontSize') ?? 20.0;
      _ttsRate = prefs.getDouble('ttsRate') ?? 0.5;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is double) await prefs.setDouble(key, value);
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("fr-FR");
    await _flutterTts.setSpeechRate(_ttsRate);
  }

  Future<void> _updateTtsRate(double rate) async {
    setState(() => _ttsRate = rate);
    await _flutterTts.setSpeechRate(rate);
    await _saveSetting('ttsRate', rate);
  }

  @override
  void dispose() {
    _textController.dispose();
    _flutterTts.stop();
    _speech.stop();
    super.dispose();
  }

  // ==================== ACTIONS ====================

  void _handleOCR() {
    setState(() => _isScanning = true);

    Future.delayed(const Duration(seconds: 2), () {
      setState(() => _isScanning = false);

      const text = "Ordonnance médicale\nPatient : Marie Dubois\nMédicament : Doliprane 1000mg\n1 comprimé 3 fois par jour pendant 7 jours";

      _flutterTts.speak(text);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Texte trouvé', style: TextStyle(fontSize: 26)),
          content: Text(text, style: const TextStyle(fontSize: 22)),
          actions: [
            TextButton(
              onPressed: () {
                _flutterTts.stop();
                Navigator.pop(context);
              },
              child: const Text('Fermer', style: TextStyle(fontSize: 22)),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _handleSpeechToText() async {
    if (!_isListening) {
      var status = await Permission.speech.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission refusée', style: TextStyle(fontSize: 20))),
        );
        return;
      }

      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            if (val.finalResult) {
              setState(() => _isListening = false);
              _textController.text = val.recognizedWords;

              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text('Texte transcrit', style: TextStyle(fontSize: 26)),
                  content: Text(val.recognizedWords, style: const TextStyle(fontSize: 22)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK', style: TextStyle(fontSize: 22)),
                    ),
                  ],
                ),
              );
            }
          },
          localeId: "fr_FR",
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _handleTextToSpeech() {
    if (_textController.text.trim().isNotEmpty) {
      _flutterTts.speak(_textController.text);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez écrire ou coller un texte', style: TextStyle(fontSize: 20)),
        ),
      );
    }
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Accessibilité',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Que voulez-vous faire ?',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),

            // Scanner un document
            FeatureCard(
              icon: FontAwesomeIcons.camera,
              title: 'Scanner un document',
              subtitle: 'Ordonnance, panneau, étiquette...',
              gradientColors: [Colors.blue[600]!, Colors.blue[700]!],
              onPressed: _isScanning ? null : _handleOCR,
              isLoading: _isScanning,
              buttonText: 'Ouvrir l\'appareil photo',
            ),

            const SizedBox(height: 28),

            // Parler → Écrire
            FeatureCard(
              icon: FontAwesomeIcons.microphone,
              title: 'Parler → Écrire',
              subtitle: 'Dicter un message ou une note',
              gradientColors: [Colors.purple[600]!, Colors.purple[700]!],
              onPressed: _handleSpeechToText,
              buttonText: _isListening ? 'Écoute en cours...' : 'Commencer à parler',
              buttonBackgroundColor: _isListening ? Colors.red[600] : null,
            ),

            const SizedBox(height: 40),

            // Section Texte → Parole
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.volume_up, size: 48, color: Colors.orange),
                      const SizedBox(width: 20),
                      const Expanded(
                        child: Text(
                          'Lire un texte à voix haute',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  TextField(
                    controller: _textController,
                    maxLines: 5,
                    style: TextStyle(fontSize: _fontSize),
                    decoration: InputDecoration(
                      hintText: 'Écrivez ou collez le texte ici...',
                      hintStyle: const TextStyle(fontSize: 22),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Colors.orange, width: 3),
                      ),
                      contentPadding: const EdgeInsets.all(24),
                    ),
                  ),

                  const SizedBox(height: 28),

                  ElevatedButton(
                    onPressed: _handleTextToSpeech,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 80),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text(
                      '🔊 Lire le texte',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Vitesse de lecture - Slider pleine largeur
                  const Text('Vitesse de lecture', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 16,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 22),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 34),
                      valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
                      valueIndicatorColor: Colors.orange,
                      valueIndicatorTextStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    child: Slider(
                      value: _ttsRate,
                      min: 0.1,
                      max: 1.0,
                      divisions: 18,
                      label: _ttsRate.toStringAsFixed(1),
                      onChanged: _updateTtsRate,
                    ),
                  ),
                  Center(
                    child: Text(
                      'Vitesse actuelle : ${_ttsRate.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Taille du texte - Slider pleine largeur
                  const Text('Taille du texte', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 16,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 22),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 34),
                    ),
                    child: Slider(
                      value: _fontSize,
                      min: 16,
                      max: 32,
                      divisions: 16,
                      label: _fontSize.toInt().toString(),
                      onChanged: (value) {
                        setState(() => _fontSize = value);
                        _saveSetting('fontSize', value);
                      },
                    ),
                  ),
                  Center(
                    child: Text(
                      'Taille actuelle : ${_fontSize.toInt()} px',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Autres paramètres
            const Text(
              'Autres paramètres',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            _buildBigSwitch(
              icon: FontAwesomeIcons.eye,
              title: 'Contraste élevé',
              value: _highContrast,
              onChanged: (value) {
                setState(() => _highContrast = value);
                _saveSetting('highContrast', value);
              },
            ),

            _buildBigSwitch(
              icon: FontAwesomeIcons.bolt,
              title: 'Alertes lumineuses',
              value: _visualAlertEnabled,
              onChanged: (value) {
                setState(() => _visualAlertEnabled = value);
                _saveSetting('visualAlertEnabled', value);
              },
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildBigSwitch({
    required IconData icon,
    required String title,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.12), blurRadius: 12),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 40, color: Colors.grey[700]),
          const SizedBox(width: 24),
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w500)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.teal[600],
          ),
        ],
      ),
    );
  }
}