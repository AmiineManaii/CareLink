import 'dart:io';
import 'dart:async';

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
import 'face_login_screen.dart';

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
  double _currentZoom = 1.0;
  double _maxZoom = 1.0;
  Rect? _lastBox;
  int _stableFrames = 0;
  final int _minStableFrames = 8;
  final double _motionThreshold = 8.0;
  final double _sizeThreshold = 0.08;
  bool _ready = false;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _faceDetectorService = FaceDetectorService();
    _faceRecognitionService = FaceRecognitionService();
    initCamera();
  }

  Future<void> initCamera() async {
    final cameras = await availableCameras();

    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );
    _camera = frontCamera;

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
    try {
      _maxZoom = await _controller!.getMaxZoomLevel();
      _currentZoom = await _controller!.getMinZoomLevel();
      await _controller!.setZoomLevel(_currentZoom);
    } catch (_) {}
    await _controller!.startImageStream(_processCameraImage);

    setState(() {});
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;

    final inputImage = _convertCameraImage(image);
    final faces = await _faceDetectorService.detectFaces(inputImage);
    _imageSize = Size(image.width.toDouble(), image.height.toDouble());

    if (kDebugMode) {
      print("Faces detected: ${faces.length}");
      if (faces.isNotEmpty) {
        print("Face 1 bounding box: ${faces.first.boundingBox}");
      }
    }

    setState(() {
      _faces = faces;
    });

    // ✅ SI AU MOINS UN VISAGE EST DÉTECTÉ
    if (faces.isNotEmpty) {
      try {
        final imgImage = convertCameraImageToImage(image);
        var faceCrop = cropFace(imgImage, faces.first);
        faceCrop = resizeFace(faceCrop, 112);
        faceCrop = img.flipHorizontal(faceCrop);
        final embedding = _faceRecognitionService.getEmbedding(faceCrop);
        _adjustZoomForFace(faces.first);
        _updateStability(faces.first.boundingBox);
        _ready = hasSufficientContours(faces.first) && _stableFrames >= _minStableFrames;
        if (_isCapturing && _ready) {
          _embeddingBuffer.add(embedding);
        } else if (_ready) {
          _embeddingBuffer = [embedding];
          _startCapture();
        }
      } catch (e, stack) {
        if (kDebugMode) {
          print("Erreur lors du traitement du visage: $e");
          print(stack);
        }
      }
    }
    _isDetecting = false;
  }

  void _startCapture() {
    _isCapturing = true;
    _captureTimer?.cancel();
    _captureTimer = Timer(const Duration(seconds: 3), () async {
      if (_embeddingBuffer.isNotEmpty) {
        final averaged = _averageEmbeddings(_embeddingBuffer);
        setState(() {
          _lastEmbedding = averaged;
        });
        try {
          await _controller?.stopImageStream();
        } catch (_) {}
        await _onRegister();
      }
      _isCapturing = false;
      _embeddingBuffer.clear();
    });
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

  void _adjustZoomForFace(Face face) async {
    if (_controller == null) return;
    final size = _controller!.value.previewSize;
    if (size == null) return;
    final fraction = face.boundingBox.width / size.width;
    double target = _currentZoom;
    if (fraction < 0.30) {
      target = (_currentZoom + 0.2).clamp(1.0, _maxZoom);
    } else if (fraction > 0.55) {
      target = (_currentZoom - 0.1).clamp(1.0, _maxZoom);
    }
    if ((target - _currentZoom).abs() >= 0.05) {
      _currentZoom = target;
      try {
        await _controller!.setZoomLevel(_currentZoom);
      } catch (_) {}
    }
  }

  void _updateStability(Rect box) {
    if (_lastBox == null) {
      _lastBox = box;
      _stableFrames = 0;
      return;
    }
    final dx = (box.center.dx - _lastBox!.center.dx).abs();
    final dy = (box.center.dy - _lastBox!.center.dy).abs();
    final dw = (box.width - _lastBox!.width).abs() / _lastBox!.width;
    final dh = (box.height - _lastBox!.height).abs() / _lastBox!.height;
    if (dx < _motionThreshold && dy < _motionThreshold && dw < _sizeThreshold && dh < _sizeThreshold) {
      _stableFrames += 1;
    } else {
      _stableFrames = 0;
    }
    _lastBox = box;
  }
  InputImage _convertCameraImage(CameraImage image) {
    final WriteBuffer buffer = WriteBuffer();
    for (final Plane plane in image.planes) {
      buffer.putUint8List(plane.bytes);
    }
    final bytes = buffer.done().buffer.asUint8List();

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: _rotationIntToImageRotation(_camera!.sensorOrientation),
      format: Platform.isAndroid
          ? InputImageFormat.nv21
          : InputImageFormat.bgra8888,
      bytesPerRow: image.planes.first.bytesPerRow,
    );
    //print("visagee ${InputImage.fromBytes(bytes: bytes, metadata: metadata)}");
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

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetectorService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final previewSize = _controller!.value.previewSize!;
    final screenSize = MediaQuery.of(context).size;
    var scale = screenSize.aspectRatio * _controller!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Scaffold(
      appBar: AppBar(title: const Text("Signup – Reconnaissance faciale")),
      body: Stack(
        children: [
          Transform.scale(
            scale: scale,
            child: Center(child: CameraPreview(_controller!)),
          ),

          CustomPaint(
            painter: FacePainter(
              _faces,
              _imageSize ?? Size(previewSize.width, previewSize.height),
              ready: _ready,
            ),
          ),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _faces.length == 1
                        ? "Visage détecté ✅"
                        : _faces.isEmpty
                        ? "Place ton visage dans le cadre"
                        : "Un seul visage autorisé",
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onRegister() async {
    if (_lastEmbedding != null) {
      // Sauvegarder l'empreinte
      InMemoryFaceStorage().saveEmbedding(_lastEmbedding!);
      // Libérer la caméra proprement avant de naviguer
      try {
        await _controller?.stopImageStream();
      } catch (_) {}
      await _controller?.dispose();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Visage enregistré avec succès !")),
      );
      // Naviguer vers Login
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const FaceLoginScreen()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucun visage valide détecté.")),
      );
    }
  }
}
