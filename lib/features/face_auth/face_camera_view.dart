import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class FaceCameraView extends StatelessWidget {
  final CameraController controller;

  const FaceCameraView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return CameraPreview(controller);
  }
}
