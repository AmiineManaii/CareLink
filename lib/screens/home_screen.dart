// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:async';
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

  @override
  void dispose() {
    _sosTimer?.cancel();
    super.dispose();
  }

  void _handleSOSPress() {
    setState(() {
      _sosPressed = true;
    });

    _sosTimer = Timer(const Duration(seconds: 2), () {
      // Simuler l'activation SOS
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('🚨 SOS ACTIVÉ!'),
          content: const Text(
            '✓ Appel d\'urgence lancé\n✓ SMS envoyé aux contacts\n✓ Position GPS partagée\n✓ Message vocal automatique',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      setState(() {
        _sosPressed = false;
      });
    });
  }

  void _handleSOSRelease() {
    _sosTimer?.cancel();
    setState(() {
      _sosPressed = false;
    });
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
