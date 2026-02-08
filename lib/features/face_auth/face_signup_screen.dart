// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:care_link/features/face_auth/face_recognition_service.dart';
import 'package:care_link/features/face_auth/face_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

import 'face_detector_service.dart';
import 'face_painter.dart';
import 'face_storage.dart';
import 'package:care_link/main.dart';
import 'face_compare_service.dart';

class FaceSignupScreen extends StatefulWidget {
  const FaceSignupScreen({super.key});

  @override
  State<FaceSignupScreen> createState() => _FaceSignupScreenState();
}

class _FaceSignupScreenState extends State<FaceSignupScreen> {
  CameraController? _controller;
  CameraDescription? _camera;
  late FaceDetectorService _faceDetectorService;
  late FaceRecognitionService _faceRecognitionService;

  bool _isDetecting = false;
  bool _isCapturing = false;
  List<Face> _faces = [];
  List<double>? _lastEmbedding;
  List<List<double>> _embeddingBuffer = [];
  Timer? _captureTimer;
  Size? _imageSize;
  DateTime? _captureEndTime;
  bool _isCentered = false;

  @override
  void initState() {
    super.initState();
    _faceDetectorService = FaceDetectorService();
    _faceRecognitionService = FaceRecognitionService();
    initCamera();
  }

  String _countdownText() {
    if (_captureEndTime == null) return "Vérification en cours…";
    final remainingMs = _captureEndTime!
        .difference(DateTime.now())
        .inMilliseconds;
    final seconds = (remainingMs / 1000).clamp(0, 3);
    return "Vérification dans ${seconds.toStringAsFixed(1)} s…";
  }

  Future<void> initCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _camera = frontCamera;

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      await _controller!.startImageStream(_processCameraImage);

      setState(() {});
    } catch (e) {
      if (kDebugMode) {
        print("Erreur initialisation caméra: $e");
      }
      _showErrorSnackBar("Erreur d'initialisation de la caméra");
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      final inputImage = _convertCameraImage(image);
      final faces = await _faceDetectorService.detectFaces(inputImage);
      final rotation = _camera?.sensorOrientation ?? 0;
      _imageSize = (rotation == 90 || rotation == 270)
          ? Size(image.height.toDouble(), image.width.toDouble())
          : Size(image.width.toDouble(), image.height.toDouble());

      if (kDebugMode) {
        print("Faces detected: ${faces.length}");
        if (faces.isNotEmpty) {
          print("Face 1 bounding box: ${faces.first.boundingBox}");
        }
      }

      setState(() {
        _faces = faces;
        _isCentered = faces.isNotEmpty ? _checkCentered(faces.first) : false;
      });

      // ✅ SI AU MOINS UN VISAGE EST DÉTECTÉ
      if (faces.isNotEmpty) {
        try {
          final imgImage = convertCameraImageToImage(image);
          final rotated = rotateForSensor(imgImage, rotation);
          var faceCrop = cropFace(rotated, faces.first);
          faceCrop = resizeFace(faceCrop, 112);
          if (_camera?.lensDirection == CameraLensDirection.front) {
            faceCrop = img.flipHorizontal(faceCrop);
          }
          final embedding = _faceRecognitionService.getEmbedding(faceCrop);

          if (_isCapturing) {
            _embeddingBuffer.add(embedding);
          } else {
            if (_isCentered) {
              _embeddingBuffer = [embedding];
              _startCapture();
            }
          }
        } catch (e, stack) {
          if (kDebugMode) {
            print("Erreur lors du traitement du visage: $e");
            print(stack);
          }
        }
      } else {
        // Aucun visage détecté, réinitialiser l'état
        if (_isCapturing) {
          _cancelCapture();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Erreur dans _processCameraImage: $e");
      }
    } finally {
      _isDetecting = false;
    }
  }

  void _startCapture() {
    if (_isCapturing) return;

    _isCapturing = true;
    _captureEndTime = DateTime.now().add(const Duration(seconds: 3));
    _captureTimer?.cancel();
    _captureTimer = Timer(const Duration(seconds: 3), () async {
      if (_embeddingBuffer.isNotEmpty && _embeddingBuffer.length >= 3) {
        final averaged = _averageEmbeddings(_embeddingBuffer);
        setState(() {
          _lastEmbedding = averaged;
        });
        await _onRegister();
      } else {
        _showErrorSnackBar("Pas assez d'échantillons pour l'enregistrement");
        _cancelCapture();
      }
    });
  }

  void _cancelCapture() {
    _captureTimer?.cancel();
    _captureTimer = null;
    _isCapturing = false;
    _embeddingBuffer.clear();
    _captureEndTime = null;
    setState(() {});
  }

  List<double> _averageEmbeddings(List<List<double>> list) {
    final length = list.first.length;
    final sums = List<double>.filled(length, 0);
    for (final vec in list) {
      for (int i = 0; i < length; i++) {
        sums[i] += vec[i];
      }
    }
    final count = list.length.toDouble();
    return sums.map((v) => v / count).toList();
  }

  InputImage _convertCameraImage(CameraImage image) {
    final WriteBuffer buffer = WriteBuffer();
    for (final Plane plane in image.planes) {
      buffer.putUint8List(plane.bytes);
    }
    final bytes = buffer.done().buffer.asUint8List();

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: _rotationIntToImageRotation(_camera?.sensorOrientation ?? 0),
      format: Platform.isAndroid
          ? InputImageFormat.nv21
          : InputImageFormat.bgra8888,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  InputImageRotation _rotationIntToImageRotation(int rotation) {
    switch (rotation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  bool _checkCentered(Face face) {
    if (_imageSize == null) return false;
    final cx = face.boundingBox.center.dx;
    final cy = face.boundingBox.center.dy;
    final nx = (cx / _imageSize!.width) - 0.5;
    final ny = (cy / _imageSize!.height) - 0.5;
    final dist = math.sqrt(nx * nx + ny * ny);
    return dist < 0.2;
  }

  Future<void> _onRegister() async {
    if (_lastEmbedding != null) {
      final existing = InMemoryFaceStorage().getEmbedding();
      if (existing == null) {
        await InMemoryFaceStorage().saveEmbedding(_lastEmbedding!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Reconnaissance ajoutée")),
          );
        }
      } else {
        final same = FaceCompareService.match(_lastEmbedding!, existing);
        if (same) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Cette reconnaissance existe déjà")),
            );
          }
        } else {
          await InMemoryFaceStorage().saveEmbedding(_lastEmbedding!);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Nouvelle reconnaissance ajoutée")),
            );
          }
        }
      }
      await InMemoryFaceStorage().setLoggedIn(true);
      await InMemoryFaceStorage().setRole('personne_agee');
      _captureTimer?.cancel();
      try {
        await _controller?.stopImageStream();
        await _controller?.dispose();
      } catch (_) {}
      setState(() {
        _controller = null;
      });
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ElderlyNavigation()),
        (route) => false,
      );
    } else {
      _showErrorSnackBar("Aucun visage valide détecté.");
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    _controller?.dispose();
    _faceDetectorService.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("Initialisation de la caméra..."),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Signup – Reconnaissance faciale")),
      body: Column(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Transform(
                    alignment: Alignment.center,
                    transform:
                        (_camera?.lensDirection == CameraLensDirection.front)
                        ? (Matrix4.identity()..scale(-1.0, 1.0, 1.0))
                        : Matrix4.identity(),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _controller != null
                            ? CameraPreview(_controller!)
                            : const SizedBox.shrink(),
                        CustomPaint(
                          painter: FacePainter(
                            _faces,
                            _imageSize ??
                                Size(
                                  _controller!.value.previewSize!.width,
                                  _controller!.value.previewSize!.height,
                                ),
                            ready: _isCentered && _isCapturing,
                            mirror:
                                (_camera?.lensDirection ==
                                CameraLensDirection.front),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        _isCapturing
                            ? _countdownText()
                            : (_faces.isEmpty
                                  ? "Place ton visage dans le cadre"
                                  : (_isCentered
                                        ? "Visage détecté ✅ Maintenez la position"
                                        : "Centre ton visage dans le cercle")),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (_isCapturing)
                  LinearProgressIndicator(
                    value: _captureEndTime != null
                        ? 1.0 -
                              (_captureEndTime!
                                      .difference(DateTime.now())
                                      .inMilliseconds /
                                  3000.0)
                        : 0,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isCentered ? Colors.green : Colors.orange,
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  _isCapturing
                      ? "Ne bougez pas pendant l'enregistrement..."
                      : "Positionnez votre visage au centre du cercle",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isCapturing ? Colors.blue : Colors.black87,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
