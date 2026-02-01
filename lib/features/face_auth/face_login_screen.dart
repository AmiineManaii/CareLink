import 'dart:io';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:care_link/features/face_auth/face_recognition_service.dart';
import 'package:care_link/features/face_auth/face_utils.dart';
import 'package:care_link/features/face_auth/face_compare_service.dart';
import 'package:care_link/features/face_auth/face_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

import 'face_detector_service.dart';
import 'face_painter.dart';

class FaceLoginScreen extends StatefulWidget {
  const FaceLoginScreen({super.key});

  @override
  State<FaceLoginScreen> createState() => _FaceLoginScreenState();
}

class _FaceLoginScreenState extends State<FaceLoginScreen> {
  CameraController? _controller;
  CameraDescription? _camera;
  late FaceDetectorService _faceDetectorService;
  late FaceRecognitionService _faceRecognitionService;

  bool _isDetecting = false;
  bool _isSuccess = false;
  bool _isCapturing = false;
  List<Face> _faces = [];
  String _authStatus = "Recherche de visage...";
  Color _statusColor = Colors.white;
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
      orElse: () => cameras.first,
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
    if (!mounted) return;
    await _controller!.startImageStream(_processCameraImage);
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetectorService.dispose();
    super.dispose();
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting || _isSuccess) return;
    _isDetecting = true;

    try {
      final inputImage = _convertCameraImage(image);
      final faces = await _faceDetectorService.detectFaces(inputImage);
      _imageSize = Size(image.width.toDouble(), image.height.toDouble());

      if (!mounted) return;
      setState(() {
        _faces = faces;
      });

      if (faces.isNotEmpty) {
        // Zoom dynamique pour cadrer le visage
        _adjustZoomForFace(faces.first);
        // Ajouter l'embedding au buffer pour moyenne
        final imgImage = convertCameraImageToImage(image);
        var faceCrop = cropFace(imgImage, faces.first);
        faceCrop = resizeFace(faceCrop, 112);
        faceCrop = img.flipHorizontal(faceCrop);
        final embedding = _faceRecognitionService.getEmbedding(faceCrop);
        _updateStability(faces.first.boundingBox);
        _ready = hasSufficientContours(faces.first) && _stableFrames >= _minStableFrames;
        if (_isCapturing && _ready) {
          _embeddingBuffer.add(embedding);
        } else if (_ready) {
          _isCapturing = true;
          _embeddingBuffer = [embedding];
          _startCapture(stored: InMemoryFaceStorage().getEmbedding());
        }
      } else {
        if (mounted) {
          setState(() {
            _authStatus = "Placez votre visage dans le cadre";
            _statusColor = Colors.white;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) print("Error processing image: $e");
    } finally {
      _isDetecting = false;
    }
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

  Future<void> _authenticateFace(CameraImage image, Face face) async {
    try {
      final storedEmbedding = InMemoryFaceStorage().getEmbedding();
      if (storedEmbedding == null) {
        if (mounted) {
          setState(() {
            _authStatus = "Aucun utilisateur enregistré (Signup d'abord)";
            _statusColor = Colors.orange;
          });
        }
        return;
      }

      final imgImage = convertCameraImageToImage(image);
      var faceCrop = cropFace(imgImage, face);
      // Resize + flip horizontal pour caméra frontale
      faceCrop = resizeFace(faceCrop, 112);
      faceCrop = img.flipHorizontal(faceCrop);
      final embedding = _faceRecognitionService.getEmbedding(faceCrop);

      final isMatch = FaceCompareService.match(embedding, storedEmbedding);

      if (mounted) {
        if (isMatch) {
          _isSuccess = true;
          await _controller?.stopImageStream();
          setState(() {
            _authStatus = "Authentification réussie !";
            _statusColor = Colors.green;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Bienvenue ! Connexion réussie.")),
          );
          // TODO: Navigate to Home Screen
        } else {
          setState(() {
            _authStatus = "Visage non reconnu";
            _statusColor = Colors.red;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) print("Auth error: $e");
    }
  }

  void _startCapture({List<double>? stored}) {
    _captureTimer?.cancel();
    _captureTimer = Timer(const Duration(seconds: 2), () async {
      if (_embeddingBuffer.isNotEmpty) {
        final averaged = _averageEmbeddings(_embeddingBuffer);
        final storedEmbedding = stored ?? InMemoryFaceStorage().getEmbedding();
        if (storedEmbedding != null) {
          final isMatch = FaceCompareService.match(averaged, storedEmbedding);
          if (mounted) {
            if (isMatch) {
              _isSuccess = true;
              await _controller?.stopImageStream();
              setState(() {
                _authStatus = "Authentification réussie !";
                _statusColor = Colors.green;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Bienvenue ! Connexion réussie.")),
              );
            } else {
              setState(() {
                _authStatus = "Visage non reconnu";
                _statusColor = Colors.red;
              });
            }
          }
        }
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

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _controller!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Scaffold(
      appBar: AppBar(title: const Text("Connexion Faciale")),
      body: Stack(
        children: [
          Transform.scale(
            scale: scale,
            child: Center(child: CameraPreview(_controller!)),
          ),
          if (_camera != null)
            CustomPaint(
              painter: FacePainter(
                _faces,
                _imageSize ??
                    Size(
                      _controller!.value.previewSize!.width,
                      _controller!.value.previewSize!.height,
                    ),
                ready: _ready,
              ),
            ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              color: Colors.black54,
              child: Text(
                _authStatus,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _statusColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
