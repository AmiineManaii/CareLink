import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Timer? _locationTimer;
  Position? _lastKnownPosition;
  final _positionController = StreamController<Position?>.broadcast();

  Stream<Position?> get positionStream => _positionController.stream;
  Position? get lastKnownPosition => _lastKnownPosition;

  void startLocationUpdates() {
    _updatePosition();
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updatePosition();
    });
  }

  void stopLocationUpdates() {
    _locationTimer?.cancel();
  }

  Future<void> _updatePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 15),
        );
      } catch (e) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position != null) {
        _lastKnownPosition = position;
        _positionController.add(position);
      }
    } catch (e) {
      debugPrint("Error updating position: $e");
    }
  }

  void dispose() {
    _locationTimer?.cancel();
    _positionController.close();
  }
}
