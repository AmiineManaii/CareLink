// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../widgets/custom_app_bar.dart';
import '../widgets/sos_button.dart';
import '../widgets/quick_action_card.dart';

class HomeScreen extends StatefulWidget {
  final Function(String) onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _sosPressed = false;
  Timer? _sosTimer;

  final String smtpHost = 'smtp.gmail.com';
  final int smtpPort = 587;
  final String smtpUser = 'your email';
  final String smtpPassword = 'your password';
  final String smtpRecipient = 'your email';

  void _handleSOSPress() {
    setState(() => _sosPressed = true);
    _sosTimer = Timer(const Duration(seconds: 2), () {
      _sendSOS();
      setState(() => _sosPressed = false);
    });
  }

  void _handleSOSRelease() {
    _sosTimer?.cancel();
    setState(() => _sosPressed = false);
  }

  Future<void> _sendSOS() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return _showMessage('Localisation désactivée');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _showMessage('Permission localisation refusée');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final lat = position.latitude.toStringAsFixed(6);
      final lon = position.longitude.toStringAsFixed(6);

      final smtpServer = SmtpServer(
        smtpHost,
        port: smtpPort,
        username: smtpUser,
        password: smtpPassword,
        ssl: false,
        allowInsecure: false,
      );

      final message = Message()
        ..from = Address(smtpUser, 'CareLink SOS')
        ..recipients.add(smtpRecipient)
        ..subject = '🚨 SOS – Alerte Urgente'
        ..text = '''
ALERTE SOS 🚨

Latitude  : $lat
Longitude : $lon

Google Maps :
https://www.google.com/maps?q=$lat,$lon
''';

      await send(message, smtpServer);
      await _showMessage('SOS envoyé avec succès');
    } catch (e) {
      await _showMessage('Erreur SMTP : $e');
    }
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('SOS'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: CustomAppBar(title: 'Accueil', showBackButton: false),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              // SOS Button Section
              Column(
                children: [
                 
                  SOSButton(
                    isPressed: _sosPressed,
                    onPressedDown: _handleSOSPress,
                    onPressedUp: _handleSOSRelease,
                  ),
                  ],
              ),


              
              const SizedBox(height: 16),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  QuickActionCard(
                    title: 'Médicaments',
                    subtitle: 'Rappels',
                    icon: FontAwesomeIcons.bell,
                    gradientColors: [Colors.purple[500]!, Colors.purple[600]!],
                    onTap: () => widget.onNavigate('medications'),
                  ),
                  QuickActionCard(
                    title: 'Contacts',
                    subtitle: 'Appel rapide',
                    icon: FontAwesomeIcons.phone,
                    gradientColors: [Colors.green[500]!, Colors.green[600]!],
                    onTap: () => widget.onNavigate('contacts'),
                  ),
                  QuickActionCard(
                    title: 'Assistance',
                    subtitle: 'Outils vocaux',
                    icon: FontAwesomeIcons.volumeHigh,
                    gradientColors: [Colors.blue[500]!, Colors.blue[600]!],
                    onTap: () => widget.onNavigate('accessibility'),
                  ),
                  QuickActionCard(
                    title: 'Alertes',
                    subtitle: 'Historique',
                    icon: FontAwesomeIcons.triangleExclamation,
                    gradientColors: [Colors.orange[500]!, Colors.orange[600]!],
                    onTap: () => widget.onNavigate('alerts'),
                  ),
                ],
              ),

              /*const SizedBox(height: 32),

              // Recent Activity
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activité récente',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildActivityItem(
                      color: Colors.green,
                      title: 'Médicament pris',
                      subtitle: 'Aspirine - 14:00',
                    ),
                    const SizedBox(height: 12),
                    _buildActivityItem(
                      color: Colors.blue,
                      title: 'Appel reçu',
                      subtitle: 'Marie Dupont - 12:30',
                    ),
                  ],
                ),
              ),
            */],
          ),
        ),
      ),
    );
  }

 }
