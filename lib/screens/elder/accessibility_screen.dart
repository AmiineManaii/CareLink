// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'dart:io';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/feature_card.dart';

class AccessibilityScreen extends StatefulWidget {
  const AccessibilityScreen({super.key});

  @override
  State<AccessibilityScreen> createState() => _AccessibilityScreenState();
}

class _AccessibilityScreenState extends State<AccessibilityScreen> {
  bool _isScanning       = false;
  bool _isListening      = false;
  bool _highContrast     = false;
  bool _visualAlertEnabled = false;
  bool _modelLoaded      = false;

  final TextEditingController _textController  = TextEditingController();
  double _fontSize = 20.0;
  double _ttsRate  = 0.5;

  final FlutterTts       _flutterTts      = FlutterTts();
  final stt.SpeechToText _speech          = stt.SpeechToText();
  final ImagePicker      _picker          = ImagePicker();
  final TextRecognizer   _textRecognizer  = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  // ML Kit — détection zones
  ObjectDetector? _objectDetector;

  // TFLite — classification précise de chaque zone
  Interpreter?  _interpreter;
  List<String>? _labels;

  // ── Traductions FR (ImageNet + COCO) ──────────────────────────
  static const Map<String, String> _translations = {
    // Bouteilles & boissons
    "bottle":             "une bouteille",
    "water bottle":       "une bouteille d'eau",
    "plastic bag":        "un sac plastique",
    // Nourriture
    "banana":             "une banane",
    "apple":              "une pomme",
    "orange":             "une orange",
    "pizza":              "une pizza",
    "hamburger":          "un hamburger",
    "hot dog":            "un hot-dog",
    "sandwich":           "un sandwich",
    "cake":               "un gâteau",
    "donut":              "un beignet",
    "broccoli":           "un brocoli",
    "carrot":             "une carotte",
    "cup":                "une tasse",
    "bowl":               "un bol",
    "fork":               "une fourchette",
    "knife":              "un couteau",
    "spoon":              "une cuillère",
    "plate":              "une assiette",
    // Médicaments
    "pill bottle":        "une boîte de médicaments",
    "medicine":           "un médicament",
    "capsule":            "une gélule",
    "syringe":            "une seringue",
    // Électronique
    "cell phone":         "un téléphone portable",
    "mobile phone":       "un téléphone portable",
    "smartphone":         "un smartphone",
    "laptop":             "un ordinateur portable",
    "computer keyboard":  "un clavier",
    "keyboard":           "un clavier",
    "mouse":              "une souris d'ordinateur",
    "remote control":     "une télécommande",
    "remote":             "une télécommande",
    "television":         "une télévision",
    "tv":                 "une télévision",
    "monitor":            "un écran",
    "speaker":            "une enceinte",
    "headphones":         "un casque audio",
    "earphone":           "des écouteurs",
    "camera":             "un appareil photo",
    "charger":            "un chargeur",
    // Mobilier
    "chair":              "une chaise",
    "armchair":           "un fauteuil",
    "couch":              "un canapé",
    "sofa":               "un canapé",
    "bed":                "un lit",
    "dining table":       "une table à manger",
    "table":              "une table",
    "desk":               "un bureau",
    "bookcase":           "une bibliothèque",
    "wardrobe":           "une armoire",
    "lamp":               "une lampe",
    "mirror":             "un miroir",
    // Cuisine
    "refrigerator":       "un réfrigérateur",
    "fridge":             "un réfrigérateur",
    "microwave":          "un micro-ondes",
    "oven":               "un four",
    "toaster":            "un grille-pain",
    "sink":               "un évier",
    "pan":                "une poêle",
    "pot":                "une casserole",
    "spatula":            "une spatule",
    // Vêtements
    "shirt":              "une chemise",
    "t-shirt":            "un t-shirt",
    "pants":              "un pantalon",
    "shoe":               "une chaussure",
    "sneaker":            "une basket",
    "boot":               "une botte",
    "hat":                "un chapeau",
    "cap":                "une casquette",
    "glasses":            "des lunettes",
    "sunglasses":         "des lunettes de soleil",
    "watch":              "une montre",
    "backpack":           "un sac à dos",
    "handbag":            "un sac à main",
    "suitcase":           "une valise",
    "umbrella":           "un parapluie",
    "tie":                "une cravate",
    // Personnes & animaux
    "person":             "une personne",
    "cat":                "un chat",
    "dog":                "un chien",
    "bird":               "un oiseau",
    "horse":              "un cheval",
    "cow":                "une vache",
    "sheep":              "un mouton",
    "elephant":           "un éléphant",
    "bear":               "un ours",
    "zebra":              "un zèbre",
    "giraffe":            "une girafe",
    // Véhicules
    "car":                "une voiture",
    "bicycle":            "un vélo",
    "motorcycle":         "une moto",
    "bus":                "un bus",
    "truck":              "un camion",
    "train":              "un train",
    "airplane":           "un avion",
    "boat":               "un bateau",
    // Bureau & papeterie
    "book":               "un livre",
    "pen":                "un stylo",
    "pencil":             "un crayon",
    "scissors":           "des ciseaux",
    "clock":              "une horloge",
    "vase":               "un vase",
    "teddy bear":         "un ours en peluche",
    "hair drier":         "un sèche-cheveux",
    "toothbrush":         "une brosse à dents",
    "potted plant":       "une plante en pot",
    "flower":             "une fleur",
    "tree":               "un arbre",
    "toilet":             "des toilettes",
    "bench":              "un banc",
    "traffic light":      "un feu de signalisation",
    "stop sign":          "un panneau stop",
    "fire hydrant":       "une borne d'incendie",
    "sports ball":        "un ballon",
    "tennis racket":      "une raquette de tennis",
    "skateboard":         "un skateboard",
    "surfboard":          "une planche de surf",
    "kite":               "un cerf-volant",
    "wine glass":         "un verre à vin",
    "frisbee":            "un frisbee",
    "skis":               "des skis",
  };

  // ── Init ────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initTts();
    _initMLKit();
    _loadClassifier();
  }

  void _initMLKit() {
    // ML Kit : détecte les zones, classifie grossièrement
    _objectDetector = ObjectDetector(
      options: ObjectDetectorOptions(
        mode: DetectionMode.single,
        classifyObjects: true,
        multipleObjects: true,
      ),
    );
    debugPrint('✅ ML Kit ObjectDetector initialisé');
  }

  Future<void> _loadClassifier() async {
    try {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(
        'assets/detection_final.tflite',
        options: options,
      );

      final raw  = await rootBundle.loadString('assets/labels_90.txt');
      _labels    = raw.split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      // Log shapes
      final inp = _interpreter!.getInputTensor(0);
      final outCount = _interpreter!.getOutputTensors().length;
      debugPrint('✅ Classifier chargé');
      debugPrint('   Input : ${inp.shape} | ${inp.type}');
      debugPrint('   Outputs count: $outCount');
      for (int i = 0; i < outCount; i++) {
        final out = _interpreter!.getOutputTensor(i);
        debugPrint('   Output $i: ${out.shape} | ${out.type}');
      }
      debugPrint('   Labels: ${_labels!.length}');

      setState(() => _modelLoaded = true);
    } catch (e) {
      debugPrint('❌ Erreur chargement classifier: $e');
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _highContrast = prefs.getBool('highContrast') ?? false;
      _fontSize     = prefs.getDouble('fontSize')   ?? 20.0;
      _ttsRate      = prefs.getDouble('ttsRate')    ?? 0.5;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool)   await prefs.setBool(key, value);
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
    _textRecognizer.close();
    _objectDetector?.close();
    _interpreter?.close();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════
  //  PIPELINE PRINCIPAL
  //  1. ML Kit → bounding boxes
  //  2. Pour chaque box → crop → TFLite classifier → label précis
  // ══════════════════════════════════════════════════════════════

  Future<void> _handleObjectLabeling() async {
    if (!_modelLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⏳ Classifier en chargement…',
            style: TextStyle(fontSize: 20)),
      ));
      return;
    }

    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 92,
      );
      if (file == null) return;

      setState(() => _isScanning = true);

      // ── Étape 1 : ML Kit détecte les zones ───────────────────
      final inputImage = InputImage.fromFilePath(file.path);
      final List<DetectedObject> mlObjects =
          await _objectDetector!.processImage(inputImage);

      debugPrint('🔍 ML Kit: ${mlObjects.length} objet(s) détecté(s)');

      // Charger l'image une seule fois pour les crops
      final bytes    = await File(file.path).readAsBytes();
      final fullImg  = img.decodeImage(bytes);

      final List<Map<String, dynamic>> finalResults = [];

      if (mlObjects.isEmpty || fullImg == null) {
        // Pas de zone détectée → classifier l'image entière
        debugPrint('⚠️ Aucune zone ML Kit → classification image entière');
        final result = await _classifyImage(fullImg ?? img.Image(300, 300));
        if (result != null) finalResults.add(result);
      } else {
        // ── Étape 2 : Pour chaque zone → crop → TFLite ─────────
        for (int i = 0; i < mlObjects.length; i++) {
          final obj  = mlObjects[i];
          final bbox = obj.boundingBox;

          debugPrint(
            '📦 Zone $i | ML Kit labels: '
            '${obj.labels.map((l) => "${l.text}(${(l.confidence * 100).toStringAsFixed(0)}%)").join(", ")} '
            '| box: ${bbox.left.toInt()},${bbox.top.toInt()} '
            '${bbox.width.toInt()}×${bbox.height.toInt()}',
          );

          // Crop de la zone détectée (avec marge de 10%)
          final int margin = ((bbox.width + bbox.height) * 0.05).toInt();
          final int left   = (bbox.left   - margin).clamp(0, fullImg.width ).toInt();
          final int top    = (bbox.top    - margin).clamp(0, fullImg.height).toInt();
          final int right  = (bbox.right  + margin).clamp(0, fullImg.width ).toInt();
          final int bottom = (bbox.bottom + margin).clamp(0, fullImg.height).toInt();
          final int w      = (right  - left).clamp(1, fullImg.width);
          final int h      = (bottom - top ).clamp(1, fullImg.height);

          final croppedImg = img.copyCrop(fullImg, left, top, w, h);

          // TFLite classifier sur le crop
          final tfliteResult = await _classifyImage(croppedImg);

          if (tfliteResult != null) {
            // Ajouter la bounding box ML Kit au résultat
            finalResults.add({
              ...tfliteResult,
              "box": bbox,
            });
            debugPrint(
              '✅ Zone $i → "${tfliteResult["label"]}" '
              '${(tfliteResult["confidence"] * 100).toStringAsFixed(1)}%',
            );
          } else {
            // TFLite pas sûr → utiliser le label ML Kit si disponible
            if (obj.labels.isNotEmpty) {
              final mlLabel = obj.labels.first.text.toLowerCase();
              finalResults.add({
                "label":      mlLabel,
                "confidence": obj.labels.first.confidence,
                "box":        bbox,
                "fromMlKit":  true,
              });
              debugPrint('↩️ Zone $i → ML Kit fallback: "$mlLabel"');
            }
          }
        }
      }

      setState(() => _isScanning = false);

      // ── Dédupliquer et traduire ──────────────────────────────
      final List<String>               detectedLabels = [];
      final List<Map<String, dynamic>> withFr         = [];

      for (final r in finalResults) {
        final String fr = _translate(r["label"] as String);
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
      _showDetectionDialog(file.path, mlObjects, withFr, resultText);

    } catch (e) {
      setState(() => _isScanning = false);
      debugPrint('❌ handleObjectLabeling: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : $e', style: const TextStyle(fontSize: 20)),
      ));
    }
  }

  // ── TFLite : classifier une image (supporte uint8 et float32) ──────────
  Future<Map<String, dynamic>?> _classifyImage(img.Image source) async {
    if (_interpreter == null || _labels == null) return null;

    try {
      final inputTensor = _interpreter!.getInputTensor(0);
      final inputShape  = inputTensor.shape;  // [1, H, W, 3]
      final inputType   = inputTensor.type;
      final int h       = inputShape[1];
      final int w       = inputShape[2];

      final resized = img.copyResize(source, width: w, height: h);

      Object input;
      if (inputType == TensorType.uint8) {
        final buffer = Uint8List(h * w * 3);
        int idx = 0;
        for (int y = 0; y < h; y++) {
          for (int x = 0; x < w; x++) {
            final p = resized.getPixel(x, y);
            buffer[idx++] = img.getRed(p);
            buffer[idx++] = img.getGreen(p);
            buffer[idx++] = img.getBlue(p);
          }
        }
        input = buffer.reshape([1, h, w, 3]);
      } else {
        final buffer = Float32List(h * w * 3);
        int idx = 0;
        for (int y = 0; y < h; y++) {
          for (int x = 0; x < w; x++) {
            final p = resized.getPixel(x, y);
            buffer[idx++] = img.getRed(p)   / 255.0;
            buffer[idx++] = img.getGreen(p) / 255.0;
            buffer[idx++] = img.getBlue(p)  / 255.0;
          }
        }
        input = buffer.reshape([1, h, w, 3]);
      }

      // Préparer les sorties (supporte plusieurs tenseurs de sortie)
      final outTensors = _interpreter!.getOutputTensors();
      final Map<int, Object> outputs = {};

      for (int i = 0; i < outTensors.length; i++) {
        final shape = outTensors[i].shape;
        final type  = outTensors[i].type;

        if (type == TensorType.uint8) {
          outputs[i] = _createUint8Buffer(shape);
        } else {
          outputs[i] = _createFloat32Buffer(shape);
        }
      }

      _interpreter!.runForMultipleInputs([input], outputs);

      // Chercher le tenseur de scores et de classes
      List<num>? scores;
      List<int>? classes;

      debugPrint('🔎 TFLite Outputs Analyse:');
      for (int i = 0; i < outTensors.length; i++) {
        final shape = outTensors[i].shape;
        debugPrint('   Output $i shape: $shape');

        // Détection heuristique
        if (shape.length == 2 && shape[0] == 1) {
          // [1, N] -> peut être scores ou classes
          final data = (outputs[i] as List)[0] as List;
          
          // Si les valeurs sont des entiers < labels.length -> probablement classes
          final isInt = data.every((e) => e is int || (e is double && e == e.toInt()));
          if (isInt && data.any((e) => e != 0)) {
             classes ??= data.map((e) => (e as num).toInt()).toList();
          } else {
             scores ??= data.map((e) => e as num).toList();
          }
        } 
        else if (shape.length == 1 && classes == null && scores == null) {
          // [N] -> peut être classification pure
          final data = outputs[i] as List;
          scores = data.map((e) => e as num).toList();
          classes = List.generate(scores.length, (i) => i);
        }
      }

      // Fallback si rien trouvé (classification pure sur le premier tenseur 2D)
      if ((scores == null || classes == null) && outTensors.isNotEmpty) {
         if (outTensors[0].shape.length == 2) {
           final data = (outputs[0] as List)[0] as List;
           scores = data.map((e) => e is int ? e / 255.0 : e as num).toList();
           classes = List.generate(scores.length, (i) => i);
         }
      }

      if (scores == null || classes == null || scores.isEmpty) {
        debugPrint('⚠️ Impossible d\'identifier les scores/classes');
        return null;
      }

      // Trouver le meilleur résultat
      int bestIdx = -1;
      double maxScore = -1.0;

      for (int i = 0; i < scores.length; i++) {
        if (scores[i] > maxScore) {
          maxScore = scores[i].toDouble();
          bestIdx = i;
        }
      }

      if (bestIdx == -1 || maxScore < 0.25) return null;

      final int classId = classes[bestIdx];
      
      // COCO Map: background=0, person=1, bicycle=2, etc.
      // Si labels_90.txt commence par person (index 0), on soustrait 1 si le modèle est 1-indexed.
      // On teste si labels[classId] est valide, sinon on essaie classId-1.
      int labelIdx = classId;
      if (labelIdx >= _labels!.length || _labels![labelIdx] == "n/a") {
         if (classId > 0 && (classId - 1) < _labels!.length) {
           labelIdx = classId - 1;
         }
      }

      if (labelIdx < 0 || labelIdx >= _labels!.length || _labels![labelIdx] == "n/a") return null;

      debugPrint('🎯 TFLite Best: ${_labels![labelIdx]} ($maxScore)');

      return {
        "label":      _labels![labelIdx],
        "confidence": maxScore,
      };
    } catch (e) {
      debugPrint('❌ _classifyImage: $e');
      return null;
    }
  }

  // Helper pour créer des buffers multi-dimensionnels (plus robuste avec reshape)
  Object _createUint8Buffer(List<int> shape) {
    final size = shape.isEmpty ? 0 : shape.reduce((a, b) => a * b);
    return Uint8List(size).reshape(shape);
  }

  Object _createFloat32Buffer(List<int> shape) {
    final size = shape.isEmpty ? 0 : shape.reduce((a, b) => a * b);
    return Float32List(size).reshape(shape);
  }


  String _translate(String label) {
    final key = label.toLowerCase().trim();
    // Chercher correspondance exacte
    if (_translations.containsKey(key)) return _translations[key]!;
    // Chercher correspondance partielle
    for (final entry in _translations.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        return entry.value;
      }
    }
    return label; // retourner en anglais si pas de traduction
  }

  // ── Dialog résultat ──────────────────────────────────────────
  void _showDetectionDialog(
    String imagePath,
    List<DetectedObject> mlObjects,
    List<Map<String, dynamic>> results,
    String resultText,
  ) {
    final bytes   = File(imagePath).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    final imgW    = decoded?.width.toDouble()  ?? 1.0;
    final imgH    = decoded?.height.toDouble() ?? 1.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        title: Row(children: [
          const Icon(FontAwesomeIcons.magnifyingGlass,
              size: 42, color: Colors.teal),
          const SizedBox(width: 20),
          const Expanded(
            child: Text('Identification',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            // Image avec bounding boxes ML Kit
            Container(
              height: 320,
              width: double.infinity,
              decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LayoutBuilder(builder: (_, c) => Stack(children: [
                  Image.file(File(imagePath),
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity),
                  CustomPaint(
                    painter: DetectionPainter(
                      results:      results,
                      imageWidth:   imgW,
                      imageHeight:  imgH,
                      widgetWidth:  c.maxWidth,
                      widgetHeight: c.maxHeight,
                    ),
                  ),
                ])),
              ),
            ),

            const SizedBox(height: 20),

            // Résultat principal
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: Colors.teal[50],
                  borderRadius: BorderRadius.circular(16)),
              child: Text(resultText,
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                  textAlign: TextAlign.center),
            ),

            // Détails par objet
            if (results.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              ...results.map((r) {
                final double conf  = r["confidence"] as double;
                final String label = r["labelFr"]    as String;
                final bool fromMl  = r["fromMlKit"]  as bool? ?? false;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Icon(
                      fromMl ? Icons.blur_on : Icons.psychology,
                      size: 22,
                      color: fromMl ? Colors.orange : Colors.teal,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(label,
                          style: const TextStyle(fontSize: 20)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                          color: _confColor(conf).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        '${(conf * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _confColor(conf)),
                      ),
                    ),
                  ]),
                );
              }),
              const SizedBox(height: 8),
              // Légende
              Row(children: [
                Icon(Icons.psychology, size: 16, color: Colors.teal),
                const SizedBox(width: 4),
                const Text('TFLite', style: TextStyle(fontSize: 14, color: Colors.teal)),
                const SizedBox(width: 16),
                Icon(Icons.blur_on, size: 16, color: Colors.orange),
                const SizedBox(width: 4),
                const Text('ML Kit', style: TextStyle(fontSize: 14, color: Colors.orange)),
              ]),
            ],
          ]),
        ),
        actionsPadding: const EdgeInsets.all(24),
        actions: [
          ElevatedButton.icon(
            onPressed: () => _flutterTts.speak(resultText),
            icon: const Icon(Icons.volume_up, color: Colors.white, size: 28),
            label: const Text('RÉÉCOUTER',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[400],
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 70),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () { _flutterTts.stop(); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[600],
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 80),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('MERCI',
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Color _confColor(double c) =>
      c >= 0.70 ? Colors.green : c >= 0.45 ? Colors.orange : Colors.red;

  // ── OCR ────────────────────────────────────────────────────────
  Future<void> _handleOCR() async {
    try {
      final XFile? image = await _picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.rear);
      if (image == null) return;

      setState(() => _isScanning = true);
      final inputImage = InputImage.fromFilePath(image.path);
      final recognized = await _textRecognizer.processImage(inputImage);
      setState(() => _isScanning = false);

      String text = recognized.text.trim();
      if (text.isEmpty) {
        text = "Aucun texte détecté. Réessayez avec une image plus nette.";
      } else if (text.toLowerCase().contains("ordonnance") ||
          text.toLowerCase().contains("dosage") ||
          text.toLowerCase().contains("fois par jour")) {
        text = "📜 Ce document ressemble à une ordonnance.\n\n$text";
      }
      _showOCRResultDialog(text);
    } catch (e) {
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : $e', style: const TextStyle(fontSize: 20)),
      ));
    }
  }

  void _showOCRResultDialog(String text) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
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
                    fontSize: _fontSize + 4,
                    color: Colors.black87,
                    height: 1.5)),
          ),
        ),
        actionsPadding: const EdgeInsets.all(24),
        actions: [
          Column(children: [
            ElevatedButton.icon(
              onPressed: () => _flutterTts.speak(text),
              icon: const Icon(FontAwesomeIcons.volumeHigh,
                  size: 32, color: Colors.white),
              label: const Text('LIRE À VOIX HAUTE',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 80),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Texte copié !',
                          style: TextStyle(fontSize: 20)),
                    ));
                  },
                  child: const Text('COPIER',
                      style: TextStyle(fontSize: 22, color: Colors.blue)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _flutterTts.stop();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.black87,
                    minimumSize: const Size(double.infinity, 80),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  child: const Text('FERMER',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ]),
        ],
      ),
    );
  }

  // ── Speech To Text ─────────────────────────────────────────────
  Future<void> _handleSpeechToText() async {
    if (!_isListening) {
      final status = await Permission.speech.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Permission refusée',
              style: TextStyle(fontSize: 20)),
        ));
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
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  title: const Text('Texte transcrit',
                      style: TextStyle(fontSize: 26)),
                  content: Text(val.recognizedWords,
                      style: const TextStyle(fontSize: 22)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK',
                          style: TextStyle(fontSize: 22)),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Veuillez écrire ou coller un texte',
            style: TextStyle(fontSize: 20)),
      ));
    }
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
            Row(children: [
              const Expanded(
                child: Text('Que voulez-vous faire ?',
                    style: TextStyle(
                        fontSize: 30, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: _modelLoaded
                        ? Colors.teal[50]
                        : Colors.orange[50],
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    _modelLoaded
                        ? Icons.check_circle
                        : Icons.hourglass_empty,
                    size: 18,
                    color: _modelLoaded ? Colors.teal : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _modelLoaded ? 'IA prête' : 'Chargement…',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _modelLoaded
                            ? Colors.teal[700]
                            : Colors.orange[700]),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 40),

            FeatureCard(
              icon: FontAwesomeIcons.magnifyingGlass,
              title: 'C\'est quoi ça ?',
              subtitle:
                  'Identifier un objet (bouteille, médicament, chaise…)',
              gradientColors: [Colors.teal[600]!, Colors.teal[700]!],
              onPressed: (_isScanning || !_modelLoaded)
                  ? null
                  : _handleObjectLabeling,
              isLoading: _isScanning,
              buttonText: 'Identifier un objet',
            ),
            const SizedBox(height: 28),

            FeatureCard(
              icon: FontAwesomeIcons.camera,
              title: 'Scanner un document',
              subtitle:
                  'Lire et extraire les infos d\'une ordonnance, lettre…',
              gradientColors: [Colors.blue[600]!, Colors.blue[700]!],
              onPressed: _isScanning ? null : _handleOCR,
              isLoading: _isScanning,
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
              buttonBackgroundColor:
                  _isListening ? Colors.red[600] : null,
            ),
            const SizedBox(height: 40),

            Container(
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
                  Row(children: [
                    const Icon(Icons.volume_up,
                        size: 48, color: Colors.orange),
                    const SizedBox(width: 20),
                    const Expanded(
                      child: Text('Lire un texte à voix haute',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _textController,
                    maxLines: 5,
                    style: TextStyle(fontSize: _fontSize),
                    decoration: InputDecoration(
                      hintText: 'Écrivez ou collez le texte ici…',
                      hintStyle: const TextStyle(fontSize: 22),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear,
                            size: 36, color: Colors.grey),
                        onPressed: () => _textController.clear(),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(
                              color: Colors.orange, width: 3)),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('🔊 Lire le texte',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 40),
                  const Text('Vitesse de lecture',
                      style: TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 16,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 22),
                      overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 34),
                      valueIndicatorShape:
                          const PaddleSliderValueIndicatorShape(),
                      valueIndicatorColor: Colors.orange,
                      valueIndicatorTextStyle: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    child: Slider(
                      value: _ttsRate,
                      min: 0.1, max: 1.0, divisions: 18,
                      label: _ttsRate.toStringAsFixed(1),
                      onChanged: _updateTtsRate,
                    ),
                  ),
                  Center(
                    child: Text(
                      'Vitesse actuelle : ${_ttsRate.toStringAsFixed(1)}',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text('Taille du texte',
                      style: TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 16,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 22),
                      overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 34),
                    ),
                    child: Slider(
                      value: _fontSize,
                      min: 16, max: 32, divisions: 16,
                      label: _fontSize.toInt().toString(),
                      onChanged: (v) {
                        setState(() => _fontSize = v);
                        _saveSetting('fontSize', v);
                      },
                    ),
                  ),
                  Center(
                    child: Text(
                      'Taille actuelle : ${_fontSize.toInt()} px',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            const Text('Autres paramètres',
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold)),
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
          BoxShadow(
              color: Colors.grey.withOpacity(0.12), blurRadius: 12),
        ],
      ),
      child: Row(children: [
        Icon(icon, size: 40, color: Colors.grey[700]),
        const SizedBox(width: 24),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w500)),
        ),
        Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.teal[600]),
      ]),
    );
  }
}

// ── Painter ────────────────────────────────────────────────────────
class DetectionPainter extends CustomPainter {
  final List<Map<String, dynamic>> results;
  final double imageWidth, imageHeight, widgetWidth, widgetHeight;

  const DetectionPainter({
    required this.results,
    required this.imageWidth,  required this.imageHeight,
    required this.widgetWidth, required this.widgetHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scale =
        (widgetWidth / imageWidth) < (widgetHeight / imageHeight)
            ? widgetWidth  / imageWidth
            : widgetHeight / imageHeight;
    final double ox = (widgetWidth  - imageWidth  * scale) / 2;
    final double oy = (widgetHeight - imageHeight * scale) / 2;

    for (final r in results) {
      if (!r.containsKey("box")) continue;
      final Rect   box   = r["box"]        as Rect;
      final double conf  = r["confidence"] as double;
      final String label = r["labelFr"]    as String? ?? r["label"] as String;
      final bool fromMl  = r["fromMlKit"]  as bool?   ?? false;

      final Color color = fromMl
          ? Colors.orangeAccent
          : conf >= 0.70
              ? Colors.greenAccent
              : Colors.tealAccent;

      canvas.drawRect(
        Rect.fromLTRB(
          ox + box.left   * scale, oy + box.top    * scale,
          ox + box.right  * scale, oy + box.bottom * scale,
        ),
        Paint()
          ..style      = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..color      = color,
      );

      (TextPainter(
        text: TextSpan(
          text: ' $label ${(conf * 100).toStringAsFixed(0)}% ',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              backgroundColor: Colors.black54),
        ),
        textDirection: TextDirection.ltr,
      )..layout())
          .paint(canvas,
              Offset(ox + box.left * scale, oy + box.top * scale - 20));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}