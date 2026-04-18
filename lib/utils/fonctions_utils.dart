

import 'dart:io';

import 'package:care_link/utils/face_storage.dart';
import 'package:care_link/utils/label_translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
const MethodChannel fallChannel = MethodChannel('fall_channel');
const EventChannel fallEventsChannel = EventChannel('fall_events');
final String smsRecipient = dotenv.env['SMS_TO'] ?? '';

  void showSnackBar(String message, BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(fontSize: 20))),
    );
  }
  String buildResultSentence(List<String> labels) {
    if (labels.isEmpty) return "Je n'arrive pas à identifier d'objets ici.";
    if (labels.length == 1) return "C'est ${labels.first}.";
    return "Je vois : ${labels.join(', ')}.";
  }

  List<Map<String, dynamic>> translateAndDeduplicate(
    List<Map<String, dynamic>> results,
  ) {
    final List<String> seen = [];
    final List<Map<String, dynamic>> output = [];

    for (final r in results) {
      final String fr = LabelTranslations.translate(r["label"] as String);
      if (!seen.contains(fr)) {
        seen.add(fr);
        output.add({...r, "labelFr": fr});
      }
    }

    return output;
  }

  String enrichOcrText(String rawText) {
    if (rawText.isEmpty) {
      return "Aucun texte détecté. Réessayez avec une image plus nette.";
    }
    final lower = rawText.toLowerCase();
    if (lower.contains("ordonnance") ||
        lower.contains("dosage") ||
        lower.contains("fois par jour")) {
      return "📜 Ce document ressemble à une ordonnance.\n\n$rawText";
    }
    return rawText;
  }

  img.Image cropWithMargin(img.Image source, dynamic bbox) {
    final int margin = ((bbox.width + bbox.height) * 0.05).toInt();
    final int left = (bbox.left - margin).clamp(0, source.width).toInt();
    final int top = (bbox.top - margin).clamp(0, source.height).toInt();
    final int right = (bbox.right + margin).clamp(0, source.width).toInt();
    final int bottom = (bbox.bottom + margin).clamp(0, source.height).toInt();
    return img.copyCrop(source, left, top, right - left, bottom - top);
  }


Future<bool> hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }


  Future<void> sendSMSFallback(String lat, String lon) async {
    // Try to get caregiver phone from storage first
    String recipient =
        InMemoryFaceStorage().getCaregiverPhone() ?? smsRecipient;

    if (recipient.isEmpty) {
      debugPrint("SMS Fallback: No recipient configured");
      return;
    }

    try {
      final status = await Permission.sms.request();
      if (status.isGranted) {
        final message =
            "ALERTE SOS - CareLink\n"
            "Position: https://www.google.com/maps?q=$lat,$lon\n"
            "Lat: $lat, Lon: $lon";

        await fallChannel.invokeMethod('sendSMS', {
          'phone': recipient,
          'message': message,
        });
        debugPrint("SOS SMS envoyé à $recipient");
      } else {
        debugPrint("Permission SMS refusée");
      }
    } catch (e) {
      debugPrint("Erreur envoi SMS fallback: $e");
    }
  }