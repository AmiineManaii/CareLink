import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class PermissionService {
  static Future<void> requestAllPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
      Permission.location,
      Permission.notification,
      Permission.sms,
      Permission.activityRecognition,
      Permission.ignoreBatteryOptimizations,
    ].request();

    // Permissions spécifiques Android 13+ pour les médias
    if (defaultTargetPlatform == TargetPlatform.android) {
      await [
        Permission.photos,
        Permission.audio,
        Permission.videos,
      ].request();
    }

    statuses.forEach((permission, status) {
      debugPrint('Permission $permission: $status');
    });
  }

  static Future<bool> hasAllCriticalPermissions() async {
    bool camera = await Permission.camera.isGranted;
    bool mic = await Permission.microphone.isGranted;
    bool location = await Permission.location.isGranted;
    bool notification = await Permission.notification.isGranted;

    return camera && mic && location && notification;
  }
}
