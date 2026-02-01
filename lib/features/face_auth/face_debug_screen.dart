import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:ui' as ui;

import 'face_detector_service.dart';
import 'face_recognition_service.dart';
import 'face_utils.dart';
import 'face_storage.dart';

class FaceDetectionDebugScreen extends StatefulWidget {
  const FaceDetectionDebugScreen({super.key});

  @override
  State<FaceDetectionDebugScreen> createState() => _FaceDetectionDebugScreenState();
}

class _FaceDetectionDebugScreenState extends State<FaceDetectionDebugScreen> {
  // Services
  late FaceDetectorService _faceDetectorService;
  late FaceRecognitionService _faceRecognitionService;
  
  // État de l'application
  File? _selectedImage;
  List<int>? _imageBytes;
  Size _imageSize = Size.zero;
  List<Face> _detectedFaces = [];
  List<double>? _faceEmbedding;
  bool _isProcessing = false;
  String _debugLog = "Choisissez une image pour commencer\n";
  int _currentStep = 0;
  List<String> _steps = [
    "1. Chargement de l'image",
    "2. Détection des visages",
    "3. Dessin de la bounding box",
    "4. Extraction des contours",
    "5. Génération de l'empreinte",
    "6. Sauvegarde de l'empreinte"
  ];
  
  // Paramètres de dessin
  bool _showBoundingBox = true;
  bool _showContours = true;
  
  // Pour l'animation
  Timer? _stepTimer;
  int _animationFrame = 0;

  @override
  void initState() {
    super.initState();
    _faceDetectorService = FaceDetectorService();
    _faceRecognitionService = FaceRecognitionService();
    _addLog("✅ Services initialisés");
  }

  @override
  void dispose() {
    _faceDetectorService.dispose();
    _faceRecognitionService.close();
    _stepTimer?.cancel();
    super.dispose();
  }

  void _addLog(String message) {
    setState(() {
      _debugLog = "[${DateTime.now().toIso8601String().split('T')[1].split('.')[0]}] $message\n${_debugLog.substring(0, _debugLog.length < 3000 ? _debugLog.length : 3000)}";
    });
    print("DEBUG: $message");
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      
      if (pickedFile == null) return;
      
      setState(() {
        _selectedImage = File(pickedFile.path);
        _imageBytes = _selectedImage!.readAsBytesSync();
        _detectedFaces.clear();
        _faceEmbedding = null;
        _currentStep = 0;
        _isProcessing = true;
      });
      
      _addLog("📸 Image sélectionnée: ${pickedFile.path}");
      _addLog("📏 Chargement de l'image...");
      
      // Obtenir la taille de l'image
      final bytes = await File(pickedFile.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      
      setState(() {
        _imageSize = Size(
          frame.image.width.toDouble(),
          frame.image.height.toDouble(),
        );
      });
      
      _addLog("✅ Image chargée: ${_imageSize.width.toInt()}x${_imageSize.height.toInt()}");
      
      // Démarrer les étapes automatiquement
      _startStepByStepProcess(pickedFile.path);
      
    } catch (e) {
      _addLog("❌ Erreur lors de la sélection de l'image: $e");
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _startStepByStepProcess(String imagePath) async {
    // Étape 1: Chargement de l'image
    setState(() {
      _currentStep = 1;
    });
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Étape 2: Détection des visages
    _addLog("🔍 Étape 2: Détection des visages...");
    setState(() {
      _currentStep = 2;
    });
    
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _faceDetectorService.detectFaces(inputImage);
      
      setState(() {
        _detectedFaces = faces;
      });
      
      _addLog("✅ ${faces.length} visage(s) détecté(s)");
      
      if (faces.isEmpty) {
        _addLog("⚠️ Aucun visage détecté dans l'image");
        setState(() {
          _isProcessing = false;
        });
        return;
      }
      
      // Afficher les détails du premier visage
      final firstFace = faces.first;
      _addLog("📐 Bounding box: ${firstFace.boundingBox}");
      _addLog("📏 Largeur: ${firstFace.boundingBox.width.toInt()}px");
      _addLog("📏 Hauteur: ${firstFace.boundingBox.height.toInt()}px");
      
      // Compter les contours disponibles
      int contourCount = 0;
      for (final entry in firstFace.contours.entries) {
        final contour = entry.value;
        if (contour != null && contour.points.isNotEmpty) {
          contourCount++;
          _addLog("   • ${entry.key}: ${contour.points.length} points");
        }
      }
      _addLog("🎯 Contours disponibles: $contourCount");
      
    } catch (e) {
      _addLog("❌ Erreur lors de la détection: $e");
      setState(() {
        _isProcessing = false;
      });
      return;
    }
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Étape 3: Dessin de la bounding box
    _addLog("🖌️ Étape 3: Dessin de la bounding box...");
    setState(() {
      _currentStep = 3;
      _showBoundingBox = true;
    });
    
    // Animation de la bounding box
    _startBoundingBoxAnimation();
    await Future.delayed(const Duration(seconds: 1));
    
    // Étape 4: Extraction des contours
    _addLog("✏️ Étape 4: Extraction des contours...");
    setState(() {
      _currentStep = 4;
      _showContours = true;
    });
    
    _startContourAnimation();
    await Future.delayed(const Duration(seconds: 1));
    
    // Étape 5: Génération de l'empreinte
    _addLog("🧠 Étape 5: Génération de l'empreinte faciale...");
    setState(() {
      _currentStep = 5;
    });
    
    try {
      if (_detectedFaces.isNotEmpty && _selectedImage != null) {
        // Charger l'image avec le package image
        final imageBytes = await _selectedImage!.readAsBytes();
        final image = img.decodeImage(imageBytes);
        
        if (image != null) {
          final face = _detectedFaces.first;
          final faceCrop = cropFace(image, face);
          
          if (faceCrop != null) {
            final resizedFace = resizeFace(faceCrop, 112);
            final flippedFace = img.flipHorizontal(resizedFace);
            final embedding = _faceRecognitionService.getEmbedding(flippedFace);
            
            setState(() {
              _faceEmbedding = embedding;
            });
            
            _addLog("✅ Empreinte générée: ${embedding.length} dimensions");
            _addLog("📊 Premières valeurs: ${embedding.sublist(0, 5).map((v) => v.toStringAsFixed(3)).join(', ')}...");
          }
        }
      }
    } catch (e) {
      _addLog("❌ Erreur génération empreinte: $e");
    }
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Étape 6: Sauvegarde de l'empreinte
    _addLog("💾 Étape 6: Sauvegarde de l'empreinte...");
    setState(() {
      _currentStep = 6;
    });
    
    if (_faceEmbedding != null) {
      InMemoryFaceStorage().saveEmbedding(_faceEmbedding!);
      _addLog("✅ Empreinte sauvegardée en mémoire");
      _addLog("🔑 Vous pouvez maintenant tester la reconnaissance");
    }
    
    setState(() {
      _isProcessing = false;
    });
    
    _addLog("🎉 Processus terminé !");
  }

  void _startBoundingBoxAnimation() {
    _animationFrame = 0;
    _stepTimer?.cancel();
    
    _stepTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      setState(() {
        _animationFrame++;
      });
      
      if (_animationFrame > 15) {
        timer.cancel();
      }
    });
  }

  void _startContourAnimation() {
    _animationFrame = 0;
    _stepTimer?.cancel();
    
    _stepTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      setState(() {
        _animationFrame++;
      });
      
      if (_animationFrame > 30) {
        timer.cancel();
      }
    });
  }

  void _testRecognition() {
    if (_faceEmbedding == null) {
      _addLog("⚠️ Aucune empreinte disponible pour tester");
      return;
    }
    
    final stored = InMemoryFaceStorage().getEmbedding();
    if (stored == null) {
      _addLog("⚠️ Aucune empreinte stockée pour comparaison");
      return;
    }
    
    // Calculer la distance euclidienne
    double sum = 0;
    for (int i = 0; i < _faceEmbedding!.length; i++) {
      sum += pow(_faceEmbedding![i] - stored[i], 2);
    }
    final distance = sqrt(sum);
    
    _addLog("📏 Distance avec l'empreinte stockée: ${distance.toStringAsFixed(4)}");
    _addLog(distance < 0.8 ? "✅ Reconnaissance réussie !" : "❌ Visage différent");
  }

  void _clearAll() {
    setState(() {
      _selectedImage = null;
      _imageBytes = null;
      _imageSize = Size.zero;
      _detectedFaces.clear();
      _faceEmbedding = null;
      _currentStep = 0;
      _debugLog = "Choisissez une image pour commencer\n";
      _showBoundingBox = true;
      _showContours = true;
    });
    _addLog("🧹 Tout a été effacé");
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug - Détection Faciale'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _clearAll,
            tooltip: 'Tout effacer',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Barre de progression
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.deepPurple[50],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Étapes de Reconnaissance Faciale',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _currentStep / 6,
                    backgroundColor: Colors.grey[300],
                    color: Colors.green,
                    minHeight: 8,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Étape $_currentStep/6: ${_currentStep > 0 && _currentStep <= 6 ? _steps[_currentStep - 1] : "En attente"}',
                    style: TextStyle(
                      color: _currentStep == 0 ? Colors.grey : Colors.deepPurple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // Zone principale (Scrollable)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Zone d'image
                    Container(
                      width: screenWidth,
                      height: screenHeight * 0.4,
                      color: Colors.black,
                      child: _buildImageDisplay(),
                    ),
                    
                    // Contrôles et logs
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildControlPanel(),
                          const SizedBox(height: 20),
                          _buildDebugLog(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageDisplay() {
    if (_imageBytes == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image, size: 60, color: Colors.grey[700]),
            const SizedBox(height: 16),
            const Text(
              'Aucune image sélectionnée',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('Choisir une image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Image de fond
        Positioned.fill(
          child: Image.memory(
            Uint8List.fromList(_imageBytes!),
            fit: BoxFit.contain,
          ),
        ),

        // Overlay avec détection
        if (_detectedFaces.isNotEmpty)
          Positioned.fill(
            child: CustomPaint(
              painter: _FaceDebugPainter(
                faces: _detectedFaces,
                imageSize: _imageSize,
                showBoundingBox: _showBoundingBox,
                showContours: _showContours,
                animationFrame: _animationFrame,
                step: _currentStep,
              ),
            ),
          ),

        // Indicateur en haut à droite
        if (_detectedFaces.isNotEmpty)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_detectedFaces.length} visage(s)',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  if (_animationFrame > 0)
                    Text(
                      'Frame: $_animationFrame',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildControlPanel() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contrôles',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            // Bouton pour choisir une image
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _pickImage,
              icon: const Icon(Icons.photo_library, size: 20),
              label: const Text('Choisir une image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Bouton pour démarrer le processus
            if (_selectedImage != null && !_isProcessing)
              ElevatedButton.icon(
                onPressed: () => _startStepByStepProcess(_selectedImage!.path),
                icon: const Icon(Icons.play_arrow, size: 20),
                label: const Text('Démarrer le processus'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            
            const SizedBox(height: 12),
            
            // Options d'affichage
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Checkbox(
                        value: _showBoundingBox,
                        onChanged: (value) => setState(() => _showBoundingBox = value ?? true),
                      ),
                      const Text('Bounding Box'),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Checkbox(
                        value: _showContours,
                        onChanged: (value) => setState(() => _showContours = value ?? true),
                      ),
                      const Text('Contours'),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Bouton de test de reconnaissance
            if (_faceEmbedding != null)
              ElevatedButton.icon(
                onPressed: _testRecognition,
                icon: const Icon(Icons.face, size: 20),
                label: const Text('Tester la reconnaissance'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            
            const SizedBox(height: 12),
            
            // Statistiques
            Card(
              color: Colors.grey[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Statistiques',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('• Visages détectés: ${_detectedFaces.length}'),
                    if (_detectedFaces.isNotEmpty)
                      Text('• Taille image: ${_imageSize.width.toInt()}x${_imageSize.height.toInt()}'),
                    if (_faceEmbedding != null)
                      Text('• Dimensions embedding: ${_faceEmbedding!.length}'),
                    if (_isProcessing)
                      const Text('• ⚡ Traitement en cours...', style: TextStyle(color: Colors.orange)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugLog() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Logs de débogage',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() => _debugLog = ""),
                  icon: const Icon(Icons.clear_all),
                  tooltip: 'Effacer les logs',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                reverse: true,
                child: Text(
                  _debugLog,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Légende
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
                  children: [
                    Container(width: 20, height: 3, color: Colors.green),
                    const SizedBox(width: 4),
                    const Text('Bounding Box', style: TextStyle(fontSize: 10)),
                  ],
                ),
                Row(
                  children: [
                    Container(width: 20, height: 2, color: Colors.red),
                    const SizedBox(width: 4),
                    const Text('Contours', style: TextStyle(fontSize: 10)),
                  ],
                ),
                Row(
                  children: [
                    Container(width: 20, height: 2, color: Colors.blue),
                    const SizedBox(width: 4),
                    const Text('Points', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FaceDebugPainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final bool showBoundingBox;
  final bool showContours;
  final int animationFrame;
  final int step;

  _FaceDebugPainter({
    required this.faces,
    required this.imageSize,
    required this.showBoundingBox,
    required this.showContours,
    required this.animationFrame,
    required this.step,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    // Calculer le ratio pour garder les proportions de l'image
    final double imageAspectRatio = imageSize.width / imageSize.height;
    final double canvasAspectRatio = canvasSize.width / canvasSize.height;
    
    double scale;
    double dx = 0;
    double dy = 0;
    
    if (canvasAspectRatio > imageAspectRatio) {
      // Le canvas est plus large que l'image => marges sur les côtés
      scale = canvasSize.height / imageSize.height;
      dx = (canvasSize.width - imageSize.width * scale) / 2;
    } else {
      // Le canvas est plus étroit que l'image => marges en haut/bas
      scale = canvasSize.width / imageSize.width;
      dy = (canvasSize.height - imageSize.height * scale) / 2;
    }
    
    // Fonction pour transformer les coordonnées
    double transformX(double x) => dx + x * scale;
    double transformY(double y) => dy + y * scale;

    for (final face in faces) {
      // Bounding box avec animation (étape 3)
      if (showBoundingBox) {
        final boxPaint = Paint()
          ..color = Colors.green.withOpacity(0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = step == 3 ? 2.0 + (animationFrame * 0.1) : 2.0;

        final rect = Rect.fromLTRB(
          transformX(face.boundingBox.left),
          transformY(face.boundingBox.top),
          transformX(face.boundingBox.right),
          transformY(face.boundingBox.bottom),
        );
        canvas.drawRect(rect, boxPaint);

        // Texte avec coordonnées
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${face.boundingBox.width.toInt()}x${face.boundingBox.height.toInt()}',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(rect.left, rect.top - 12),
        );
      }

      // Contours avec animation (étape 4)
      if (showContours && step >= 4) {
        final contourPaint = Paint()
          ..color = Colors.red.withOpacity(0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

        for (final contour in face.contours.values) {
          if (contour != null && contour.points.isNotEmpty) {
            final path = Path();
            final firstPoint = contour.points.first;
            path.moveTo(
              transformX(firstPoint.x.toDouble()),
              transformY(firstPoint.y.toDouble()),
            );

            for (final point in contour.points.skip(1)) {
              path.lineTo(
                transformX(point.x.toDouble()),
                transformY(point.y.toDouble()),
              );
            }

            if (contour.points.length > 2) {
              path.close();
            }

            canvas.drawPath(path, contourPaint);

            // Points des contours (animation progressive)
            if (step == 4) {
              final pointPaint = Paint()
                ..color = Colors.blue
                ..style = PaintingStyle.fill;

              final pointsToShow = min(animationFrame, contour.points.length);
              for (int i = 0; i < pointsToShow; i++) {
                final point = contour.points[i];
                canvas.drawCircle(
                  Offset(
                    transformX(point.x.toDouble()),
                    transformY(point.y.toDouble()),
                  ),
                  2,
                  pointPaint,
                );
              }
            }
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FaceDebugPainter oldDelegate) {
    return oldDelegate.faces != faces ||
        oldDelegate.animationFrame != animationFrame ||
        oldDelegate.step != step ||
        oldDelegate.showBoundingBox != showBoundingBox ||
        oldDelegate.showContours != showContours;
  }
}