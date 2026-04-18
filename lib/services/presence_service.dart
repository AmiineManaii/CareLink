import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:care_link/services/api_service.dart';
import 'package:care_link/utils/face_storage.dart';

class PresenceService {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  io.Socket? _socket;
  Timer? _heartbeatTimer;
  final _presenceController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get presenceStream => _presenceController.stream;

  String? _currentRole;
  String? _currentId;

  void initSocket(String role) {
    final id = role == 'aidant'
        ? InMemoryFaceStorage().getCaregiverId()
        : InMemoryFaceStorage().getElderId();

    if (id == null) return;

    // Si le socket est déjà connecté avec le même rôle et ID, on ne fait rien
    if (_socket?.connected == true &&
        _currentRole == role &&
        _currentId == id) {
      return;
    }

    // Si on change de rôle ou d'ID, on déconnecte l'ancien socket
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }

    _currentRole = role;
    _currentId = id;

    final baseUrl = ApiService().baseUrl;
    try {
      _socket = io.io(
        baseUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .build(),
      );

      _socket!.onConnect((_) {
        debugPrint('$role connected to socket');
        if (role == 'aidant') {
          _socket!.emit('registerCaregiver', {'caregiverId': id});
        } else {
          _socket!.emit('registerElder', {'elderId': id});
        }

        _startHeartbeat(role, id);
      });

      if (role == 'aidant') {
        _socket!.on('elderPresence', (data) {
          _presenceController.add(data);
        });
      } else {
        _socket!.on('objectDetectionResult', (data) {
          _presenceController.add({
            'type': 'objectDetectionResult',
            'data': data,
          });
        });
      }

      _socket!.onDisconnect((_) {
        _heartbeatTimer?.cancel();
      });

      _socket!.connect();
    } catch (e) {
      debugPrint('Socket initialization error: $e');
    }
  }

  void _startHeartbeat(String role, String id) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (role == 'aidant') {
        _socket!.emit('caregiverHeartbeat');
      } else {
        _socket!.emit('elderHeartbeat', {'elderId': id});
      }
    });
  }

  Future<void> refreshPresenceViaHttp(String caregiverId) async {
    try {
      final data = await ApiService().caregiverHeartbeat(caregiverId);
      final elder = data['elder'];
      if (elder is Map<String, dynamic>) {
        _presenceController.add(elder);
      }
    } catch (e) {
      debugPrint('Error refreshing presence via HTTP: $e');
      rethrow;
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _socket?.dispose();
    _presenceController.close();
  }
}
