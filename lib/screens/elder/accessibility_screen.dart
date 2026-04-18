// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../../widgets/custom_app_bar.dart';
import '../../widgets/feature_card.dart';
import '../../services/ml_service.dart';
import '../../utils/label_translations.dart';
import '../../widgets/accessibility/detection_result_dialog.dart';
import '../../widgets/accessibility/detection_history_dialog.dart';
import '../../widgets/accessibility/ocr_result_dialog.dart';
import '../../widgets/accessibility/tts_section.dart';
import 'package:care_link/services/api_service.dart';
import 'package:care_link/features/face_auth/face_storage.dart';
import 'dart:convert';

class AccessibilityScreen extends StatefulWidget {
  const AccessibilityScreen({super.key});

  @override
  State<AccessibilityScreen> createState() => _AccessibilityScreenState();
}

class _AccessibilityScreenState extends State<AccessibilityScreen> {
  final MLService _mlService = MLService();
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _textController = TextEditingController();
  IO.Socket? _socket;
  String? _lastImagePath;
  List<Map<String, dynamic>> _history = [];

  bool _isObjectScanning = false;
  bool _isOcrScanning = false;
  bool _isListening = false;
  bool _highContrast = false;
  bool _visualAlertEnabled = false;
  double _fontSize = 20.0;
  double _ttsRate = 0.5;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadHistory();
    _initTts();
    _initSocket();
    _mlService.initialize().then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    _flutterTts.stop();
    _speech.stop();
    _mlService.dispose();
    _socket?.dispose();
    super.dispose();
  }

  // ── Initialisation ──────────────────────────────────────────

  Future<void> _initSocket() async {
    final elderId = InMemoryFaceStorage().getElderId();
    if (elderId == null) return;
    final baseUrl = ApiService().baseUrl;
    try {
      _socket = IO.io(
        baseUrl,
        IO.OptionBuilder().setTransports(['websocket']).setQuery({
          'elderId': elderId,
        }).build(),
      );

      _socket!.onConnect((_) {
        debugPrint('Accessibility connected to socket');
        _socket!.emit('registerElder', {'elderId': elderId});
      });

      _socket!.on('objectDetectionResult', (data) {
        final String aiResult = data['result'] ?? "";
        final String imageBase64 = data['image'] ?? "";

        if (aiResult.isNotEmpty && mounted) {
          // ✅ Ollama result is used directly as requested by the user
          final String resultText = "C'est $aiResult.";

          _saveToHistory(aiResult.toLowerCase(), aiResult, imageBase64);
          _showResultToast(resultText, aiResult, imageBase64);
        }
      });

      _socket!.on('objectDetectionError', (data) {
        if (mounted) {
          _showSnackBar("Erreur d'analyse IA : ${data['error']}");
        }
      });

      _socket!.connect();
    } catch (e) {
      debugPrint('Error initializing socket: $e');
    }
  }

  void _showResultToast(
    String resultText,
    String aiResult,
    String imageBase64,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Résultat prêt : $resultText",
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.teal,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: "VOIR",
          textColor: Colors.white,
          onPressed: () {
            _showDetectionResult(aiResult, imageBase64);
          },
        ),
      ),
    );
    _flutterTts.speak(resultText);
  }

  void _showDetectionResult(String aiResult, String imageBase64) async {
    final String fr = LabelTranslations.translate(aiResult.toLowerCase());
    final String resultText = "C'est $fr.";

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DetectionResultDialog(
        imagePath: _lastImagePath ?? "",
        imageBase64: imageBase64,
        mlObjects: const [],
        results: [
          {
            "label": aiResult.toLowerCase(),
            "labelFr": fr,
            "confidence": 1.0,
            "source": "ollama",
          },
        ],
        resultText: resultText,
        onReplay: () => _flutterTts.speak(resultText),
        onDismiss: () {
          _flutterTts.stop();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showHistory() {
    showDialog(
      context: context,
      builder: (_) => DetectionHistoryDialog(
        history: _history,
        onSpeak: (text) => _flutterTts.speak(text),
      ),
    );
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("fr-FR");
    await _flutterTts.setSpeechRate(_ttsRate);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _highContrast = prefs.getBool('highContrast') ?? false;
      _fontSize = prefs.getDouble('fontSize') ?? 20.0;
      _ttsRate = prefs.getDouble('ttsRate') ?? 0.5;
    });
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyData = prefs.getString('detection_history');
    if (historyData != null) {
      setState(() {
        _history = List<Map<String, dynamic>>.from(jsonDecode(historyData));
      });
    }
  }

  Future<void> _saveToHistory(
    String label,
    String labelFr,
    String imageBase64,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final newItem = {
      'label': label,
      'labelFr': labelFr,
      'image': imageBase64,
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() {
      _history.insert(0, newItem);
      if (_history.length > 20) _history.removeLast(); // Garder les 20 derniers
    });

    await prefs.setString('detection_history', jsonEncode(_history));
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is double) await prefs.setDouble(key, value);
  }

  Future<void> _updateTtsRate(double rate) async {
    setState(() => _ttsRate = rate);
    await _flutterTts.setSpeechRate(rate);
    await _saveSetting('ttsRate', rate);
  }

  // ── Handlers ──────────────────────────────────────────────────

  Future<void> _handleObjectLabeling() async {
    if (!_mlService.isModelLoaded) {
      _showSnackBar('⏳ Classifier en chargement…');
      return;
    }

    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 92,
      );
      if (file == null) return;

      setState(() {
        _isObjectScanning = true;
        _lastImagePath = file.path;
      });

      final elderId = InMemoryFaceStorage().getElderId();
      if (elderId == null) {
        _showSnackBar('Erreur: ID utilisateur non trouvé');
        setState(() => _isObjectScanning = false);
        return;
      }

      // 1. Tenter l'IA locale via le backend (Ollama) - Version Asynchrone
      try {
        final bytes = await file.readAsBytes();
        final String base64Image = base64Encode(bytes);

        await ApiService().analyzeImage(base64Image, elderId);

        // ✅ Reset loading state immediately after request is sent
        setState(() => _isObjectScanning = false);
        _showSnackBar(
          'Analyse lancée... Vous recevrez une notification quand le résultat sera prêt.',
        );
        return; // L'analyse continue en arrière-plan
      } catch (e) {
        debugPrint('⚠️ Erreur IA locale, repli sur TFLite: $e');
      }

      // 2. Repli sur l'ancienne méthode (TFLite) si l'IA locale échoue
      final mlObjects = await _mlService.detectObjects(file.path);
      final bytes = await File(file.path).readAsBytes();
      final fullImg = img.decodeImage(bytes);

      final List<Map<String, dynamic>> finalResults = [];

      if (mlObjects.isEmpty || fullImg == null) {
        final result = await _mlService.classifyImage(
          fullImg ?? img.Image(300, 300),
        );
        if (result != null) {
          finalResults.add({...result, "source": "tflite"});
        }
      } else {
        for (final obj in mlObjects) {
          final bbox = obj.boundingBox;
          final int margin = ((bbox.width + bbox.height) * 0.05).toInt();
          final int left = (bbox.left - margin).clamp(0, fullImg.width).toInt();
          final int top = (bbox.top - margin).clamp(0, fullImg.height).toInt();
          final int right = (bbox.right + margin)
              .clamp(0, fullImg.width)
              .toInt();
          final int bottom = (bbox.bottom + margin)
              .clamp(0, fullImg.height)
              .toInt();
          final croppedImg = img.copyCrop(
            fullImg,
            left,
            top,
            right - left,
            bottom - top,
          );

          final tfliteResult = await _mlService.classifyImage(croppedImg);
          if (tfliteResult != null) {
            finalResults.add({
              ...tfliteResult,
              "box": bbox,
              "source": "tflite",
            });
          } else if (obj.labels.isNotEmpty) {
            finalResults.add({
              "label": obj.labels.first.text.toLowerCase(),
              "confidence": obj.labels.first.confidence,
              "box": bbox,
              "source": "mlkit",
            });
          }
        }
      }

      setState(() => _isObjectScanning = false);

      final List<String> detectedLabels = [];
      final List<Map<String, dynamic>> withFr = [];
      for (final r in finalResults) {
        final String fr = LabelTranslations.translate(r["label"] as String);
        if (!detectedLabels.contains(fr)) {
          detectedLabels.add(fr);
          withFr.add({...r, "labelFr": fr});
        }
      }

      final String resultText = detectedLabels.isEmpty
          ? "Je n'arrive pas à identifier d'objets ici."
          : detectedLabels.length == 1
          ? "C'est ${detectedLabels.first}."
          : "Je vois : ${detectedLabels.join(', ')}.";

      _flutterTts.speak(resultText);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => DetectionResultDialog(
          imagePath: file.path,
          mlObjects: mlObjects,
          results: withFr,
          resultText: resultText,
          onReplay: () => _flutterTts.speak(resultText),
          onDismiss: () {
            _flutterTts.stop();
            Navigator.pop(context);
          },
        ),
      );
    } catch (e) {
      setState(() => _isObjectScanning = false);
      _showSnackBar('Erreur : $e');
    }
  }

  Future<void> _handleOCR() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image == null) return;

      setState(() => _isOcrScanning = true);
      String text = await _mlService.recognizeText(image.path);
      setState(() => _isOcrScanning = false);

      if (text.isEmpty) {
        text = "Aucun texte détecté. Réessayez avec une image plus nette.";
      } else if (text.toLowerCase().contains("ordonnance") ||
          text.toLowerCase().contains("dosage") ||
          text.toLowerCase().contains("fois par jour")) {
        text = "📜 Ce document ressemble à une ordonnance.\n\n$text";
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => OCRResultDialog(
          text: text,
          fontSize: _fontSize,
          onRead: () => _flutterTts.speak(text),
          onDismiss: () {
            _flutterTts.stop();
            Navigator.pop(context);
          },
        ),
      );
    } catch (e) {
      setState(() => _isOcrScanning = false);
      _showSnackBar('Erreur : $e');
    }
  }

  Future<void> _handleSpeechToText() async {
    if (!_isListening) {
      final status = await Permission.speech.request();
      if (!status.isGranted) {
        _showSnackBar('Permission refusée');
        return;
      }
      final available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            if (val.finalResult) {
              setState(() => _isListening = false);
              _textController.text = val.recognizedWords;
              _showTranscriptionDialog(val.recognizedWords);
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

  void _showTranscriptionDialog(String text) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Texte transcrit', style: TextStyle(fontSize: 26)),
        content: Text(text, style: const TextStyle(fontSize: 22)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(fontSize: 22)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(fontSize: 20))),
    );
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Accessibilité', showBackButton: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Identification',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                if (_history.isNotEmpty)
                  TextButton.icon(
                    onPressed: _showHistory,
                    icon: const Icon(FontAwesomeIcons.history, size: 20),
                    label: const Text(
                      'Historique',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.teal[700],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FeatureCard(
              icon: FontAwesomeIcons.magnifyingGlass,
              title: 'C\'est quoi ça ?',
              subtitle: 'Identifier un objet (bouteille, médicament, chaise…)',
              gradientColors: [Colors.teal[600]!, Colors.teal[700]!],
              onPressed: (_isObjectScanning || !_mlService.isModelLoaded)
                  ? null
                  : _handleObjectLabeling,
              isLoading: _isObjectScanning,
              buttonText: 'Identifier un objet',
            ),
            const SizedBox(height: 28),
            FeatureCard(
              icon: FontAwesomeIcons.camera,
              title: 'Scanner un document',
              subtitle: 'Lire et extraire les infos d\'une ordonnance, lettre…',
              gradientColors: [Colors.blue[600]!, Colors.blue[700]!],
              onPressed: _isOcrScanning ? null : _handleOCR,
              isLoading: _isOcrScanning,
              buttonText: 'Lire le document',
            ),
            const SizedBox(height: 28),
            FeatureCard(
              icon: FontAwesomeIcons.microphone,
              title: 'Parler → Écrire',
              subtitle: 'Dicter un message ou une note',
              gradientColors: [Colors.purple[600]!, Colors.purple[700]!],
              onPressed: _handleSpeechToText,
              buttonText: _isListening
                  ? 'Écoute en cours…'
                  : 'Commencer à parler',
              buttonBackgroundColor: _isListening ? Colors.red[600] : null,
            ),
            const SizedBox(height: 40),
            TTSSection(
              controller: _textController,
              fontSize: _fontSize,
              ttsRate: _ttsRate,
              onRateChanged: _updateTtsRate,
              onFontSizeChanged: (v) {
                setState(() => _fontSize = v);
                _saveSetting('fontSize', v);
              },
              onRead: () {
                if (_textController.text.trim().isNotEmpty) {
                  _flutterTts.speak(_textController.text);
                } else {
                  _showSnackBar('Veuillez écrire ou coller un texte');
                }
              },
            ),
            const SizedBox(height: 40),
            const Text(
              'Autres paramètres',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildBigSwitch(
              icon: FontAwesomeIcons.eye,
              title: 'Contraste élevé',
              value: _highContrast,
              onChanged: (v) {
                setState(() => _highContrast = v);
                _saveSetting('highContrast', v);
              },
            ),
            _buildBigSwitch(
              icon: FontAwesomeIcons.bolt,
              title: 'Alertes lumineuses',
              value: _visualAlertEnabled,
              onChanged: (v) {
                setState(() => _visualAlertEnabled = v);
                _saveSetting('visualAlertEnabled', v);
              },
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Que voulez-vous faire ?',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _mlService.isModelLoaded
                ? Colors.teal[50]
                : Colors.orange[50],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _mlService.isModelLoaded
                    ? Icons.check_circle
                    : Icons.hourglass_empty,
                size: 18,
                color: _mlService.isModelLoaded ? Colors.teal : Colors.orange,
              ),
              const SizedBox(width: 6),
              Text(
                _mlService.isModelLoaded ? 'IA prête' : 'Chargement…',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _mlService.isModelLoaded
                      ? Colors.teal[700]
                      : Colors.orange[700],
                ),
              ),
            ],
          ),
        ),
      ],
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
            child: Text(
              title,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w500),
            ),
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
