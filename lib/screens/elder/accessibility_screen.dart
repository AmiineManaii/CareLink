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
  double _fontSize = 18;
  String _ttsSpeed = 'Normale';

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
      _fontSize = prefs.getDouble('fontSize') ?? 18.0;
      _visualAlertEnabled = prefs.getBool('visualAlertEnabled') ?? false;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    }
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("fr-FR");
    await _setTtsSpeed(_ttsSpeed);
  }

  Future<void> _setTtsSpeed(String speed) async {
    double rate = 0.5;
    if (speed == 'Lente') rate = 0.3;
    if (speed == 'Rapide') rate = 0.7;
    await _flutterTts.setSpeechRate(rate);
  }

  @override
  void dispose() {
    _textController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  void _handleOCR() {
    setState(() {
      _isScanning = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isScanning = false;
      });
      const text =
          'Ordonnance médicale\n\nPatient: Marie Dubois\nMédicament: Doliprane 1000mg\nPosologie: 1 comprimé 3 fois par jour\nDurée: 7 jours\n\n🔊 Le texte va maintenant être lu à voix haute...';
      _flutterTts.speak(text);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('📷 TEXTE DÉTECTÉ'),
          content: const Text(text),
          actions: [
            TextButton(
              onPressed: () {
                _flutterTts.stop();
                Navigator.pop(context);
              },
              child: const Text('OK'),
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
          const SnackBar(content: Text('Permission micro refusée.')),
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
                  title: const Text('✅ TEXTE TRANSCRIT'),
                  content: Text('"${val.recognizedWords}"'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
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
        const SnackBar(content: Text('ℹ️ Veuillez entrer un texte à lire.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Outils d\'accessibilité',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // OCR Section
            FeatureCard(
              icon: FontAwesomeIcons.camera,
              title: 'Scanner un document',
              subtitle: 'Ordonnance, panneau, étiquette...',
              gradientColors: [Colors.blue[500]!, Colors.blue[600]!],
              onPressed: _isScanning ? null : _handleOCR,
              isLoading: _isScanning,
              buttonText: 'Ouvrir l\'appareil photo',
            ),

            const SizedBox(height: 16),

            // Speech to Text
            FeatureCard(
              icon: FontAwesomeIcons.microphone,
              title: 'Parole → Texte',
              subtitle: 'Dicter un message vocal',
              gradientColors: [Colors.purple[500]!, Colors.purple[600]!],
              onPressed: _handleSpeechToText,
              isLoading: false,
              buttonText: _isListening
                  ? 'Écoute en cours...'
                  : '🎤 Commencer à parler',
              buttonBackgroundColor: _isListening ? Colors.red[500] : null,
              footerText:
                  '💬 Idéal pour les personnes ayant des difficultés à écrire ou avec troubles moteurs',
            ),

            const SizedBox(height: 16),

            // Text to Speech
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          FontAwesomeIcons.volumeHigh,
                          color: Colors.orange[600],
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Texte → Parole',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                            ),
                            Text(
                              'Faire lire un texte à voix haute',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _textController,
                    maxLines: 4,
                    style: TextStyle(fontSize: _fontSize),
                    decoration: InputDecoration(
                      hintText: 'Entrez ou collez un texte ici...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.orange[500]!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _handleTextToSpeech,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[500],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '🔊 Lire le texte',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Vitesse de lecture',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        DropdownButton<String>(
                          value: _ttsSpeed,
                          items: ['Lente', 'Normale', 'Rapide']
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _ttsSpeed = val);
                              _setTtsSpeed(val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Accessibility Settings
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        FontAwesomeIcons.gear,
                        color: Colors.grey[600],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Paramètres d\'accessibilité',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Font Size
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  FontAwesomeIcons.textHeight,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Taille du texte',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${_fontSize.toInt()}px',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Slider(
                          value: _fontSize,
                          min: 14,
                          max: 28,
                          divisions: 7,
                          onChanged: (value) {
                            setState(() {
                              _fontSize = value;
                            });
                            _saveSetting('fontSize', value);
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('Petit', style: TextStyle(color: Colors.grey)),
                            Text('Moyen', style: TextStyle(color: Colors.grey)),
                            Text('Grand', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // High Contrast
                  _buildSettingRow(
                    icon: FontAwesomeIcons.eye,
                    title: 'Contraste élevé',
                    subtitle: 'Pour malvoyants',
                    value: _highContrast,
                    onChanged: (value) {
                      setState(() {
                        _highContrast = value;
                      });
                      _saveSetting('highContrast', value);
                    },
                  ),

                  // Audio Descriptions
                  _buildSettingRow(
                    icon: FontAwesomeIcons.volumeHigh,
                    title: 'Descriptions audio',
                    subtitle: 'Pour non-voyants',
                    value: true,
                    onChanged: (_) {},
                  ),

                  // Vibrations
                  _buildSettingRow(
                    icon: FontAwesomeIcons.mobileVibrate,
                    title: 'Vibrations',
                    subtitle: 'Pour malentendants',
                    value: true,
                    onChanged: (_) {},
                  ),

                  // Visual Alerts
                  _buildSettingRow(
                    icon: FontAwesomeIcons.bolt,
                    title: 'Alertes visuelles',
                    subtitle: 'Flash lors des notifications',
                    value: _visualAlertEnabled,
                    onChanged: (value) {
                      setState(() {
                        _visualAlertEnabled = value;
                      });
                      _saveSetting('visualAlertEnabled', value);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Help Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.green[500]!, Colors.green[600]!],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Guide d\'utilisation',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildGuideItem(
                    '📷',
                    'Scannez des documents pour les entendre',
                  ),
                  _buildGuideItem('🎤', 'Dictez vos messages à la voix'),
                  _buildGuideItem(
                    '🔊',
                    'Écoutez tous les textes et notifications',
                  ),
                  _buildGuideItem(
                    '⚙️',
                    'Personnalisez l\'interface selon vos besoins',
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Voir le tutoriel complet'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.grey[600], size: 20),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(subtitle, style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            ],
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildGuideItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
