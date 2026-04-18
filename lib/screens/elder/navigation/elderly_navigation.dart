import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:care_link/services/presence_service.dart';
import 'package:care_link/screens/elder/home_screen.dart';
import 'package:care_link/screens/elder/medications_screen.dart';
import 'package:care_link/screens/elder/contacts_screen.dart';
import 'package:care_link/screens/elder/accessibility_screen.dart';
import 'package:care_link/screens/elder/navigation/color_memory_game.dart';
import 'package:care_link/screens/elder/alerts_screen.dart';
import 'package:care_link/screens/elder/daily_tasks_screen.dart';

class ElderlyNavigation extends StatefulWidget {
  const ElderlyNavigation({super.key});

  @override
  State<ElderlyNavigation> createState() => _ElderlyNavigationState();
}

class _ElderlyNavigationState extends State<ElderlyNavigation> {
  final PresenceService _presenceService = PresenceService();
  final FlutterTts _flutterTts = FlutterTts();
  StreamSubscription? _presenceSubscription;

  @override
  void initState() {
    super.initState();
    _presenceService.initSocket('senior');
    _initTts();

    _presenceSubscription = _presenceService.presenceStream.listen((event) {
      if (event['type'] == 'objectDetectionResult') {
        _handleGlobalDetectionResult(event['data']);
      }
    });
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("fr-FR");
    await _flutterTts.setSpeechRate(0.5);
  }

  void _handleGlobalDetectionResult(Map<String, dynamic> data) {
    final String aiResult = data['result'] ?? "";
    if (aiResult.isEmpty) return;

    final String resultText = "Résultat d'analyse : C'est $aiResult.";

    _flutterTts.speak(resultText);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultText),
          backgroundColor: Colors.teal,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  void dispose() {
    _presenceSubscription?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  void _navigateTo(String view) {
    Widget screen;
    switch (view) {
      case 'medications':
        screen = const MedicationsScreen();
        break;
      case 'contacts':
        screen = const ContactsScreen();
        break;
      case 'accessibility':
        screen = const AccessibilityScreen();
        break;
      case 'memory_game':
        screen = const ColorMemoryGame();
        break;
      case 'alerts':
        screen = const AlertsScreen();
        break;
      case 'daily_tasks':
        screen = const DailyTasksScreen();
        break;
      default:
        return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return HomeScreen(onNavigate: _navigateTo);
  }
}
