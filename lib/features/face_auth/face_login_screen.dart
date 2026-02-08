// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:care_link/features/face_auth/face_recognition_service.dart';
import 'package:care_link/features/face_auth/face_utils.dart';
import 'package:care_link/features/face_auth/face_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

import 'face_detector_service.dart';
import 'face_painter.dart';
import 'package:care_link/main.dart';
import 'package:care_link/services/api_service.dart';

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
  bool _isCentered = false;
  bool _readyToCapture = true;
  List<Face> _faces = [];
  String _authStatus = "Recherche de visage...";
  Color _statusColor = Colors.white;
  List<List<double>> _embeddingBuffer = [];
  Timer? _captureTimer;
  Size? _imageSize;
  DateTime? _captureEndTime;

  @override
  void initState() {
    super.initState();
    _faceDetectorService = FaceDetectorService();
    _faceRecognitionService = FaceRecognitionService();
    initCamera();
  }

  Future<void> initCamera() async {
    await InMemoryFaceStorage().initialize();
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
    if (!mounted) return;
    await _controller!.startImageStream(_processCameraImage);
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetectorService.dispose();
    _captureTimer?.cancel();
    super.dispose();
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting || _isSuccess) return;
    _isDetecting = true;

    try {
      final inputImage = _convertCameraImage(image);
      final faces = await _faceDetectorService.detectFaces(inputImage);
      final rotation = _camera?.sensorOrientation ?? 0;
      _imageSize = (rotation == 90 || rotation == 270)
          ? Size(image.height.toDouble(), image.width.toDouble())
          : Size(image.width.toDouble(), image.height.toDouble());

      if (!mounted) return;
      setState(() {
        _faces = faces;
        _isCentered = faces.isNotEmpty ? _checkCentered(faces.first) : false;
      });

      if (faces.isNotEmpty) {
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
          if (_readyToCapture && _isCentered) {
            _isCapturing = true;
            _readyToCapture = false;
            _captureEndTime = DateTime.now().add(const Duration(seconds: 3));
            _embeddingBuffer = [embedding];
            _startCapture(stored: InMemoryFaceStorage().getEmbedding());
          } else if (!_isCentered) {
            _readyToCapture = true;
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _authStatus = "Placez votre visage dans le cadre";
            _statusColor = Colors.white;
            _readyToCapture = true;
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

  void _startCapture({List<double>? stored}) {
    _captureTimer?.cancel();
    _captureTimer = Timer(const Duration(seconds: 3), () async {
      if (_embeddingBuffer.isNotEmpty) {
        final averaged = _averageEmbeddings(_embeddingBuffer);
        final res = await ApiService().elderSigninFace(embedding: averaged);
        final elderId = res['elderId']?.toString() ?? '';
        final elderCode = res['code']?.toString() ?? '';
        if (elderId.isNotEmpty) {
          _isSuccess = true;
          final ctrl = _controller;
          setState(() {
            _controller = null;
            _authStatus = "Authentification réussie !";
            _statusColor = Colors.green;
          });
          try {
            await ctrl?.stopImageStream();
          } catch (_) {}
          try {
            await ctrl?.dispose();
          } catch (_) {}
          await InMemoryFaceStorage().setLoggedIn(true);
          await InMemoryFaceStorage().setElderId(elderId);
          await InMemoryFaceStorage().setElderCode(elderCode);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Utilisateur reconnu")));
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const ElderlyNavigation()),
            (route) => false,
          );
        } else {
          setState(() {
            _authStatus = "Visage non reconnu";
            _statusColor = Colors.red;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Aucun utilisateur correspondant")),
          );
        }
      }
      _isCapturing = false;
      _embeddingBuffer.clear();
      // Exiger un recentrage avant une nouvelle tentative
      _readyToCapture = false;
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

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Connexion Faciale")),
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
                        _controller != null && _controller!.value.isInitialized
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
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      color: Colors.black54,
                      child: Text(
                        _isCapturing ? _countdownText() : _authStatus,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _statusColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _countdownText() {
    if (_captureEndTime == null) return "Vérification en cours…";
    final remainingMs = _captureEndTime!
        .difference(DateTime.now())
        .inMilliseconds;
    final seconds = (remainingMs / 1000).clamp(0, 3);
    return "Vérification dans ${seconds.toStringAsFixed(1)} s…";
  }

  bool _checkCentered(Face face) {
    if (_imageSize == null) return false;
    final cx = face.boundingBox.center.dx;
    final cy = face.boundingBox.center.dy;
    final nx = (cx / _imageSize!.width) - 0.5;
    final ny = (cy / _imageSize!.height) - 0.5;
    final dist = math.sqrt(nx * nx + ny * ny);
    return dist < 0.25;
  }
}
