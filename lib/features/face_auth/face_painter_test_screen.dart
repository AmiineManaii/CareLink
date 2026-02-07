import 'dart:async';
import 'dart:math';

import 'package:care_link/features/face_auth/face_painter.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FacePainterTestScreen extends StatefulWidget {
  const FacePainterTestScreen({super.key});

  @override
  State<FacePainterTestScreen> createState() => _FacePainterTestScreenState();
}

class _FacePainterTestScreenState extends State<FacePainterTestScreen> {
  final List<Face> _faces = [];
  bool _ready = false;
  Timer? _animationTimer;
  final Random _random = Random();
  List<Point<int>> _baseFacePoints = [];
  List<Point<int>> _baseLeftEyePoints = [];
  List<Point<int>> _baseRightEyePoints = [];
  List<Point<int>> _baseMouthPoints = [];
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _createTestFace();
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

  void _createTestFace() {
    _baseFacePoints = [
      const Point<int>(80, 130),
      const Point<int>(180, 80),
      const Point<int>(280, 130),
      const Point<int>(300, 250),
      const Point<int>(280, 370),
      const Point<int>(180, 400),
      const Point<int>(80, 370),
      const Point<int>(60, 250),
      const Point<int>(80, 130),
    ];

    _baseLeftEyePoints = [
      const Point<int>(130, 180),
      const Point<int>(140, 170),
      const Point<int>(150, 180),
      const Point<int>(140, 190),
      const Point<int>(130, 180),
    ];

    _baseRightEyePoints = [
      const Point<int>(230, 180),
      const Point<int>(240, 170),
      const Point<int>(250, 180),
      const Point<int>(240, 190),
      const Point<int>(230, 180),
    ];

    _baseMouthPoints = [
      const Point<int>(160, 300),
      const Point<int>(180, 310),
      const Point<int>(200, 310),
      const Point<int>(220, 300),
      const Point<int>(200, 320),
      const Point<int>(180, 320),
      const Point<int>(160, 300),
    ];

    _updateFace();
  }

  int _getRandomVariation() {
    return _random.nextInt(11) - 5;
  }

  void _updateFace() {
    final faceContour = FaceContour(
      points: _baseFacePoints.map((point) {
        return Point<int>(
          point.x + _getRandomVariation(),
          point.y + _getRandomVariation(),
        );
      }).toList(),
      type: FaceContourType.face,
    );

    final leftEyeContour = FaceContour(
      points: _baseLeftEyePoints.map((point) {
        return Point<int>(
          point.x + _getRandomVariation(),
          point.y + _getRandomVariation(),
        );
      }).toList(),
      type: FaceContourType.leftEye,
    );

    final rightEyeContour = FaceContour(
      points: _baseRightEyePoints.map((point) {
        return Point<int>(
          point.x + _getRandomVariation(),
          point.y + _getRandomVariation(),
        );
      }).toList(),
      type: FaceContourType.rightEye,
    );

    final mouthContour = FaceContour(
      points: _baseMouthPoints.map((point) {
        return Point<int>(
          point.x + _getRandomVariation(),
          point.y + _getRandomVariation(),
        );
      }).toList(),
      type: FaceContourType.upperLipTop,
    );

    final face = Face(
      boundingBox: Rect.fromLTWH(100, 150, 200, 250),
      contours: {
        FaceContourType.face: faceContour,
        FaceContourType.leftEye: leftEyeContour,
        FaceContourType.rightEye: rightEyeContour,
        FaceContourType.upperLipTop: mouthContour,
      },
      landmarks: {},
    );

    if (mounted) {
      setState(() {
        _faces.clear();
        _faces.add(face);
      });
    }
  }

  void _toggleReady() {
    setState(() {
      _ready = !_ready;
    });
  }

  void _toggleAnimation() {
    setState(() {
      _isAnimating = !_isAnimating;
    });

    if (_isAnimating) {
      _animationTimer?.cancel();
      _animationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (mounted) {
          _updateFace();
        } else {
          timer.cancel();
        }
      });
    } else {
      _animationTimer?.cancel();
      _resetToBasePoints();
    }
  }

  void _resetToBasePoints() {
    final faceContour = FaceContour(
      points: _baseFacePoints,
      type: FaceContourType.face,
    );

    final leftEyeContour = FaceContour(
      points: _baseLeftEyePoints,
      type: FaceContourType.leftEye,
    );

    final rightEyeContour = FaceContour(
      points: _baseRightEyePoints,
      type: FaceContourType.rightEye,
    );

    final mouthContour = FaceContour(
      points: _baseMouthPoints,
      type: FaceContourType.upperLipTop,
    );

    final face = Face(
      boundingBox: Rect.fromLTWH(100, 150, 200, 250),
      contours: {
        FaceContourType.face: faceContour,
        FaceContourType.leftEye: leftEyeContour,
        FaceContourType.rightEye: rightEyeContour,
        FaceContourType.upperLipTop: mouthContour,
      },
      landmarks: {},
    );

    if (mounted) {
      setState(() {
        _faces.clear();
        _faces.add(face);
      });
    }
  }

  void _addMoreContours() {
    if (_faces.isEmpty) return;

    final face = _faces.first;

    final noseContour = FaceContour(
      points: [
        Point<int>(180 + _getRandomVariation(), 210 + _getRandomVariation()),
        Point<int>(185 + _getRandomVariation(), 230 + _getRandomVariation()),
        Point<int>(180 + _getRandomVariation(), 250 + _getRandomVariation()),
        Point<int>(175 + _getRandomVariation(), 230 + _getRandomVariation()),
        Point<int>(180 + _getRandomVariation(), 210 + _getRandomVariation()),
      ],
      type: FaceContourType.noseBottom,
    );

    final leftEyebrowContour = FaceContour(
      points: [
        Point<int>(120 + _getRandomVariation(), 160 + _getRandomVariation()),
        Point<int>(135 + _getRandomVariation(), 150 + _getRandomVariation()),
        Point<int>(155 + _getRandomVariation(), 155 + _getRandomVariation()),
      ],
      type: FaceContourType.leftEyebrowTop,
    );

    final rightEyebrowContour = FaceContour(
      points: [
        Point<int>(205 + _getRandomVariation(), 155 + _getRandomVariation()),
        Point<int>(225 + _getRandomVariation(), 150 + _getRandomVariation()),
        Point<int>(240 + _getRandomVariation(), 160 + _getRandomVariation()),
      ],
      type: FaceContourType.rightEyebrowTop,
    );

    final updatedFace = Face(
      boundingBox: face.boundingBox,
      contours: {
        ...face.contours,
        FaceContourType.noseBottom: noseContour,
        FaceContourType.leftEyebrowTop: leftEyebrowContour,
        FaceContourType.rightEyebrowTop: rightEyebrowContour,
      },
      landmarks: face.landmarks,
    );

    setState(() {
      _faces.clear();
      _faces.add(updatedFace);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calcul de la taille responsive
    final screenWidth = MediaQuery.of(context).size.width;
    final paintWidth = screenWidth * 0.85;
    final paintHeight = paintWidth * 1.25;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test FacePainter - Animation'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        child: Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: paintWidth,
                  height: paintHeight,
                  constraints: BoxConstraints(
                    maxWidth: 400,
                    maxHeight: 500,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: CustomPaint(
                    painter: FacePainter(
                      _faces,
                      Size(paintWidth, paintHeight),
                      ready: _ready,
                    ),
                    size: Size(paintWidth, paintHeight),
                  ),
                ),

                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _ready ? '✅ PRÊT' : '⏳ EN ATTENTE',
                        style: TextStyle(
                          color: _ready ? Colors.green : Colors.orange,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isAnimating ? Icons.motion_photos_on : Icons.motion_photos_off,
                            color: _isAnimating ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isAnimating ? 'ANIMATION ACTIVE' : 'ANIMATION INACTIVE',
                            style: TextStyle(
                              color: _isAnimating ? Colors.green : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Text(
                        'Visages: ${_faces.length}',
                        style: const TextStyle(color: Colors.white),
                      ),

                      if (_faces.isNotEmpty)
                        Text(
                          'Variation: ±5 pixels chaque 0.5s',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),

                      const SizedBox(height: 10),

                      Text(
                        'Contours: ${_faces.isNotEmpty ? _faces.first.contours.length : 0}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 15),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _toggleReady,
                      icon: Icon(_ready ? Icons.timer_off : Icons.timer),
                      label: Text(_ready ? 'Désactiver' : 'Activer Prêt'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _ready ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(160, 50),
                      ),
                    ),

                    ElevatedButton.icon(
                      onPressed: _toggleAnimation,
                      icon: Icon(_isAnimating ? Icons.pause : Icons.play_arrow),
                      label: Text(_isAnimating ? 'Pause' : 'Démarrer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isAnimating ? Colors.orange : Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(160, 50),
                      ),
                    ),

                    ElevatedButton.icon(
                      onPressed: _addMoreContours,
                      icon: const Icon(Icons.add_circle),
                      label: const Text('Contours'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(160, 50),
                      ),
                    ),

                    ElevatedButton.icon(
                      onPressed: _resetToBasePoints,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Reset'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(160, 50),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Retour à l\'accueil'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 50),
                  ),
                ),

                const SizedBox(height: 15),

                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.blueGrey[900],
                  child: Column(
                    children: [
                      const Text(
                        'LÉGENDE:',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 15,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          Column(
                            children: [
                              Icon(Icons.crop_square, color: Colors.orange),
                              const Text(
                                'En attente',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Icon(Icons.crop_square, color: Colors.green),
                              const Text(
                                'Prêt',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Icon(Icons.circle, color: Colors.red, size: 14),
                              const Text(
                                'Contours',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Icon(Icons.motion_photos_on, color: Colors.blue, size: 14),
                              const Text(
                                'Animation',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}