import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'fall_detection_handler.dart';

class FallDetectionManager {

  // Appeler une seule fois au démarrage de l'app
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'fall_detection_channel',
        channelName: 'Détection de Chute',
        channelDescription: 'CareLink surveille les chutes en arrière-plan',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(10000), // toutes les 10s
        autoRunOnBoot: true,        // redémarre après reboot du téléphone
        allowWakeLock: true,        // garde le CPU actif
      ),
    );
  }

  // Demande les permissions puis démarre
  static Future<void> startService() async {
    // Permission batterie (important pour Infinix/Xiaomi/Samsung)
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    // Permission notification (Android 13+)
    final perm = await FlutterForegroundTask.checkNotificationPermission();
    if (perm != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    // Démarrer le service
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'Surveillance active',
      notificationText: 'CareLink veille sur vous',
      callback: startFallDetectionCallback,
    );
  }

  static Future<void> stopService() async {
    await FlutterForegroundTask.stopService();
  }

  // Envoyer un événement au handler background
  static void notifyFall() {
    FlutterForegroundTask.sendDataToTask('FALL_DETECTED');
  }
}