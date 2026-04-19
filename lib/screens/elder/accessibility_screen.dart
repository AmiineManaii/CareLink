// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:io';
import 'package:care_link/utils/fonctions_utils.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:care_link/services/presence_service.dart';
import 'dart:convert';
import 'dart:async';

import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/feature_card.dart';
import '../../services/ml/ml_service.dart';
import '../../utils/label_translations.dart';
import '../../widgets/elder/detection_result_dialog.dart';
import '../../widgets/elder/detection_history_dialog.dart';
import '../../widgets/elder/ocr_result_dialog.dart';
import '../../widgets/elder/tts_section.dart';
import 'package:care_link/services/api_service.dart';
import 'package:care_link/utils/face_storage.dart';

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
  final PresenceService _presenceService = PresenceService();

  StreamSubscription? _presenceSubscription;
  String? _lastImagePath;
  List<Map<String, dynamic>> _history = [];

  bool _isObjectScanning = false;
  bool _isOcrScanning = false;
  bool _isListening = false;
  bool _highContrast = false;
  bool _visualAlertEnabled = false;
  double _fontSize = 20.0;
  double _ttsRate = 0.5;

  // ── Lifecycle ─────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadHistory();
    _initTts();
    _listenToPresenceEvents();
    _mlService.initialize().then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    _flutterTts.stop();
    _speech.stop();
    _mlService.dispose();
    _presenceSubscription?.cancel();
    super.dispose();
  }

  // ── Presence ──────────────────────────────────────────────────

  void _listenToPresenceEvents() {
    _presenceSubscription = _presenceService.presenceStream.listen((event) {
      if (event['type'] == 'objectDetectionResult') {
        _handleDetectionResultEvent(event['data']);
      } else if (event['type'] == 'objectDetectionError') {
        
        if (mounted) {
          showSnackBar(
            "Erreur d'analyse IA : ${event['data']['error']}",
            context,
          );
        }
      }
    });
  }

  void _handleDetectionResultEvent(Map<String, dynamic> data) {
    final String aiResult = data['result'] ?? "";
    final String imageBase64 = data['image'] ?? "";

    if (aiResult.isNotEmpty && mounted) {
      final String resultText = "C'est $aiResult.";
      _saveToHistory(aiResult.toLowerCase(), aiResult, imageBase64);
      _showResultToast(resultText, aiResult, imageBase64, true);
    }
  }

  // ── Initialisation ────────────────────────────────────────────

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

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is double) await prefs.setDouble(key, value);
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
      if (_history.length > 20) _history.removeLast();
    });

    await prefs.setString('detection_history', jsonEncode(_history));
  }

  Future<void> _updateTtsRate(double rate) async {
    setState(() => _ttsRate = rate);
    await _flutterTts.setSpeechRate(rate);
    await _saveSetting('ttsRate', rate);
  }

  // ── Image picking ─────────────────────────────────────────────

  /// Ouvre la caméra et retourne le fichier sélectionné, ou null si annulé.
  Future<XFile?> _pickImageFromCamera({int quality = 92}) async {
    return _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: quality,
    );
  }

  // ── Object detection — backend (Ollama) ───────────────────────

  /// Envoie l'image au backend Ollama pour analyse asynchrone.
  /// Retourne true si la requête a bien été envoyée.
  Future<bool> _sendImageToBackend(XFile file, String elderId) async {
    try {
      debugPrint("DEBUG: Envoi image à backend Ollama");
      final bytes = await file.readAsBytes();
      final String base64Image = base64Encode(bytes);
      await ApiService().analyzeImage(base64Image, elderId);
      return true;
    } catch (e) {
      debugPrint('Erreur IA locale, repli sur TFLite: $e');
      return false;
    }
  }

  // ── Object detection — fallback TFLite ───────────────────────
  
  /// Détecte les objets avec TFLite et retourne les résultats bruts.
  Future<List<Map<String, dynamic>>> _detectWithTFLite(XFile file) async {
    final mlObjects = await _mlService.detectObjects(file.path);
    final bytes = await File(file.path).readAsBytes();
    final fullImg = img.decodeImage(bytes);

    if (mlObjects.isEmpty || fullImg == null) {
      return _classifyFullImage(fullImg);
    }

    return _classifyDetectedObjects(mlObjects, fullImg);
  }

  /// Classifie l'image entière quand aucun objet n'est détecté.
  Future<List<Map<String, dynamic>>> _classifyFullImage(
    img.Image? fullImg,
  ) async {
    final result = await _mlService.classifyImage(
      fullImg ?? img.Image(300, 300),
    );
    if (result != null) {
      return [
        {...result, "source": "tflite"},
      ];
    }
    return [];
  }

  /// Classifie chaque objet détecté individuellement (crop + classify).
  Future<List<Map<String, dynamic>>> _classifyDetectedObjects(
    List<dynamic> mlObjects,
    img.Image fullImg,
  ) async {
    final List<Map<String, dynamic>> results = [];

    for (final obj in mlObjects) {
      final bbox = obj.boundingBox;
      final croppedImg = cropWithMargin(fullImg, bbox);
      final tfliteResult = await _mlService.classifyImage(croppedImg);

      if (tfliteResult != null) {
        results.add({...tfliteResult, "box": bbox, "source": "tflite"});
      } else if (obj.labels.isNotEmpty) {
        results.add({
          "label": obj.labels.first.text.toLowerCase(),
          "confidence": obj.labels.first.confidence,
          "box": bbox,
          "source": "mlkit",
        });
      }
    }

    return results;
  }

  // ── Speech to text ────────────────────────────────────────────

  /// Vérifie la permission micro et initialise le moteur STT.
  /// Retourne true si tout est prêt.
  Future<bool> _requestMicPermissionAndInit() async {
    final status = await Permission.speech.request();
    if (!status.isGranted) {
      showSnackBar('Permission refusée', context);
      return false;
    }
    return _speech.initialize();
  }

  // ── Dialogs & UI feedback ─────────────────────────────────────

  void _showResultToast(
    String resultText,
    String aiResult,
    String imageBase64,
    bool isOllama,
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
          onPressed: () => _showDetectionResult(aiResult, imageBase64, isOllama),
        ),
      ),
    );
    _flutterTts.speak(resultText);
  }

  void _showDetectionResult(String aiResult, String imageBase64, bool isOllama) async {
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
            "confidence": isOllama ? 1 : 0.0,
            "source": isOllama ? "ollama" : "other",
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

  void _showTFLiteDetectionResult(
    String filePath,
    List<DetectedObject> mlObjects,
    List<Map<String, dynamic>> withFr,
    String resultText,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DetectionResultDialog(
        imagePath: filePath,
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
  }

  void _showHistory() {
    showDialog(
      context: context,
      builder: (_) => DetectionHistoryDialog(
        history: _history,
        onSpeak: (text) => _flutterTts.speak(text),
        context: context,
      ),
    );
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

  // ── Handlers (orchestration) ──────────────────────────────────

  Future<void> _handleObjectLabeling() async {
    if (!_mlService.isModelLoaded) {
      showSnackBar('⏳ Classifier en chargement…', context);
      return;
    }

    try {
      final XFile? file = await _pickImageFromCamera();
      if (file == null) return;

      setState(() {
        _isObjectScanning = true;
        _lastImagePath = file.path;
      });

      final elderId = InMemoryFaceStorage().getElderId();
      if (elderId == null) {
        showSnackBar('Erreur: ID utilisateur non trouvé', context);
        setState(() => _isObjectScanning = false);
        return;
      }

      // 1. Tenter le backend Ollama (asynchrone)
      final sent = await _sendImageToBackend(file, elderId);
      if (sent) {
        setState(() => _isObjectScanning = false);
        showSnackBar('Analyse d\'image en cours...', context);
        return;
      }
      //debugPrint("DEBUG: il va travailler avec TFLite");

      // 2. Fallback TFLite
      final rawResults = await _detectWithTFLite(file);
      setState(() => _isObjectScanning = false);

      final withFr = translateAndDeduplicate(rawResults);
      final labels = withFr.map((r) => r['labelFr'] as String).toList();
      final resultText = buildResultSentence(labels);

      _flutterTts.speak(resultText);
      _showTFLiteDetectionResult(
        file.path,
        await _mlService.detectObjects(file.path),
        withFr,
        resultText,
      );
      
    } catch (e) {
      setState(() => _isObjectScanning = false);
      showSnackBar('Erreur : $e', context);
    }
  }

  Future<void> _handleOCR() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image == null) return;

      setState(() => _isOcrScanning = true);
      final rawText = await _mlService.recognizeText(image.path);
      setState(() => _isOcrScanning = false);

      final enrichedText = enrichOcrText(rawText);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => OCRResultDialog(
          text: enrichedText,
          fontSize: _fontSize,
          onRead: () => _flutterTts.speak(enrichedText),
          onDismiss: () {
            _flutterTts.stop();
            Navigator.pop(context);
          },
        ),
      );
    } catch (e) {
      setState(() => _isOcrScanning = false);
      showSnackBar('Erreur : $e', context);
    }
  }

  Future<void> _handleSpeechToText() async {
    if (_isListening) {
      setState(() => _isListening = false);
      _speech.stop();
      return;
    }

    final ready = await _requestMicPermissionAndInit();
    if (!ready) return;

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
            _buildIdentificationHeader(),
            const SizedBox(height: 16),
            _buildObjectLabelingCard(),
            const SizedBox(height: 28),
            _buildOCRCard(),
            const SizedBox(height: 28),
            _buildSpeechToTextCard(),
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
                  showSnackBar('Veuillez écrire ou coller un texte', context);
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

  // ── Widget builders ───────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Que voulez-vous faire ?',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
        ),
        _buildAiStatusBadge(),
      ],
    );
  }

  Widget _buildAiStatusBadge() {
    final bool ready = _mlService.isModelLoaded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ready ? Colors.teal[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ready ? Icons.check_circle : Icons.hourglass_empty,
            size: 18,
            color: ready ? Colors.teal : Colors.orange,
          ),
          const SizedBox(width: 6),
          Text(
            ready ? 'IA prête' : 'Chargement…',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ready ? Colors.teal[700] : Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentificationHeader() {
    //print(_history);
    return FittedBox(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_history.isNotEmpty)
            TextButton.icon(
              onPressed: _showHistory,
              icon: const Icon(FontAwesomeIcons.history, size: 20),
              label: const Text(
                'Historique de Detcetion',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(foregroundColor: Colors.teal[700]),
            ),
        ],
      ),
    );
  }

  Widget _buildObjectLabelingCard() {
    return FeatureCard(
      icon: FontAwesomeIcons.magnifyingGlass,
      title: 'C\'est quoi ça ?',
      subtitle: 'Identifier un objet (bouteille, médicament, chaise…)',
      gradientColors: [Colors.teal[600]!, Colors.teal[700]!],
      onPressed: (_isObjectScanning || !_mlService.isModelLoaded)
          ? null
          : _handleObjectLabeling,
      isLoading: _isObjectScanning,
      buttonText: 'Identifier un objet',
    );
  }

  Widget _buildOCRCard() {
    return FeatureCard(
      icon: FontAwesomeIcons.camera,
      title: 'Scanner un document',
      subtitle: 'Lire et extraire les infos d\'une ordonnance, lettre…',
      gradientColors: [Colors.blue[600]!, Colors.blue[700]!],
      onPressed: _isOcrScanning ? null : _handleOCR,
      isLoading: _isOcrScanning,
      buttonText: 'Lire le document',
    );
  }

  Widget _buildSpeechToTextCard() {
    return FeatureCard(
      icon: FontAwesomeIcons.microphone,
      title: 'Parler → Écrire',
      subtitle: 'Dicter un message ou une note',
      gradientColors: [Colors.purple[600]!, Colors.purple[700]!],
      onPressed: _handleSpeechToText,
      buttonText: _isListening ? 'Écoute en cours…' : 'Commencer à parler',
      buttonBackgroundColor: _isListening ? Colors.red[600] : null,
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
