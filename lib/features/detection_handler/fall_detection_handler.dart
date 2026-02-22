import 'package:flutter_foreground_task/flutter_foreground_task.dart';

// ⚠️ Obligatoire — annotation pour que Flutter trouve cette fonction
@pragma('vm:entry-point')
void startFallDetectionCallback() {
  FlutterForegroundTask.setTaskHandler(FallDetectionHandler());
}

class FallDetectionHandler extends TaskHandler {
  
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('[FallDetection] Service démarré à $timestamp');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Appelé toutes les X secondes — peut servir à vérifier l'état
    // La détection réelle se fait via sendData depuis l'UI
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    print('[FallDetection] Service détruit à $timestamp');
  }

  // Reçoit les données envoyées depuis l'UI Flutter
  @override
  void onReceiveData(Object data) {
    if (data == 'FALL_DETECTED') {
      print('[FallDetection] ⚠️ CHUTE DÉTECTÉE — envoi alerte...');
      // Ici tu peux appeler ton API, envoyer SMS, etc.
      // Mettre à jour la notification
      FlutterForegroundTask.updateService(
        notificationTitle: '⚠️ CHUTE DÉTECTÉE ⚠️',
        notificationText: 'Une alerte est en cours d\'envoi...',
      );
    }
  }
}