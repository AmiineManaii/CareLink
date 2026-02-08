// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
  final TextEditingController _textController = TextEditingController();
  double _fontSize = 18;

  @override
  void dispose() {
    _textController.dispose();
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
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('📷 TEXTE DÉTECTÉ'),
          content: const Text(
            'Ordonnance médicale\n\nPatient: Marie Dubois\nMédicament: Doliprane 1000mg\nPosologie: 1 comprimé 3 fois par jour\nDurée: 7 jours\n\n🔊 Le texte va maintenant être lu à voix haute...',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  void _handleSpeechToText() {
    if (!_isListening) {
      setState(() {
        _isListening = true;
      });

      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text('🎤 Parlez maintenant...'),
          content: Text(
            'Exemple: "Bonjour Marie, comment vas-tu aujourd\'hui?"',
          ),
        ),
      );

      Future.delayed(const Duration(seconds: 3), () {
        setState(() {
          _isListening = false;
        });
        showDialog(
          context: context,
          builder: (context) => const AlertDialog(
            title: Text('✅ TEXTE TRANSCRIT'),
            content: Text(
              '\'Bonjour Marie, comment vas-tu aujourd\'hui?\'\n\nLe message est prêt à être envoyé.',
            ),
            actions: [TextButton(onPressed: null, child: Text('OK'))],
          ),
        );
      });
    }
  }

  void _handleTextToSpeech() {
    if (_textController.text.trim().isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('🔊 LECTURE VOCALE'),
          content: Text(
            '"${_textController.text}"\n\nLe texte sera lu à voix haute avec une voix claire et naturelle.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
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
                          value: 'Normale',
                          items: ['Lente', 'Normale', 'Rapide']
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (_) {},
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                    icon: FontAwesomeIcons.earListen,
                    title: 'Alertes visuelles',
                    subtitle: 'Flash au lieu du son',
                    value: true,
                    onChanged: (_) {},
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
