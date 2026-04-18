import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:care_link/services/api_service.dart';
import 'package:care_link/utils/face_storage.dart';

class SOSService {
  static final SOSService _instance = SOSService._internal();
  factory SOSService() => _instance;
  SOSService._internal();

  Future<void> sendSOS(Position? position) async {
    final elderId = InMemoryFaceStorage().getElderId();
    if (elderId == null) return;

    final lat = position?.latitude;
    final lng = position?.longitude;

    try {
      // 1. Envoyer l'alerte au backend
      try {
        await ApiService().createAlert(
          elderId: elderId,
          type: 'SOS_BUTTON',
          description: 'Bouton SOS pressé par l\'utilisateur',
          latitude: lat,
          longitude: lng,
        );
      } catch (e) {
        debugPrint("Erreur lors de l'envoi de l'alerte au backend: $e");
      }

      // 2. Envoyer un email via SMTP
      await _sendEmailAlert(lat, lng);

      debugPrint("SOS envoyé avec succès");
    } catch (e) {
      debugPrint("Erreur lors de l'envoi du SOS: $e");
    }
  }

  Future<void> _sendEmailAlert(double? lat, double? lng) async {
    final String smtpUser = dotenv.env['SMTP_USER'] ?? '';
    final String smtpPassword = dotenv.env['SMTP_PASS'] ?? '';
    final String smtpRecipient = dotenv.env['SMTP_TO'] ?? '';

    if (smtpUser.isEmpty || smtpPassword.isEmpty || smtpRecipient.isEmpty) {
      debugPrint("Configuration SMTP incomplète");
      return;
    }

    final smtpServer = gmail(smtpUser, smtpPassword);

    String googleMapsUrl = (lat != null && lng != null)
        ? "https://www.google.com/maps/search/?api=1&query=$lat,$lng"
        : "Position inconnue";

    final message = Message()
      ..from = Address(smtpUser, 'CareLink Alert')
      ..recipients.add(smtpRecipient)
      ..subject = 'ALERTE SOS - CareLink'
      ..text = 'Une alerte SOS a été déclenchée.\n\nPosition: $googleMapsUrl';

    try {
      await send(message, smtpServer);
      debugPrint("Email d'alerte SOS envoyé");
    } catch (e) {
      debugPrint("Erreur envoi email SOS: $e");
    }
  }
}
