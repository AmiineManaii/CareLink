import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'package:care_link/utils/face_storage.dart';
import 'package:care_link/services/location_service.dart';
import 'package:care_link/services/sos_service.dart';
import 'package:care_link/services/home_service.dart';

import 'package:care_link/widgets/common/custom_app_bar.dart';
import 'package:care_link/widgets/common/sos_button.dart';
import 'package:care_link/widgets/common/quick_action_card.dart';
import 'package:care_link/main.dart';

class HomeScreen extends StatefulWidget {
  final Function(String) onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocationService _locationService = LocationService();
  final SOSService _sosService = SOSService();
  final HomeService _homeService = HomeService();

  bool _sosPressed = false;
  Timer? _sosTimer;
  StreamSubscription<Position?>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _setupApp();
  }

  Future<void> _setupApp() async {
    _locationService.startLocationUpdates();
    _positionSubscription = _locationService.positionStream.listen((pos) {
      if (mounted) setState(() {});
    });

    await _homeService.fetchCaregiverPhone();
    await _homeService.scheduleMedications();
    await _homeService.scheduleDailyTasks();
    await _initFallDetection();
  }

  Future<void> _initFallDetection() async {
    try {
      const channel = MethodChannel('fall_channel');
      await channel.invokeMethod('startService');
    } catch (e) {
      debugPrint('Error starting fall detection service: $e');
    }
  }

  @override
  void dispose() {
    _sosTimer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  void _handleSOSPress() {
    _sosTimer?.cancel();
    setState(() => _sosPressed = true);
    _sosTimer = Timer(const Duration(seconds: 2), () {
      if (_sosPressed) {
        _sosService.sendSOS(_locationService.lastKnownPosition);
        setState(() => _sosPressed = false);
      }
    });
  }

  void _handleSOSRelease() {
    _sosTimer?.cancel();
    setState(() => _sosPressed = false);
  }

  Future<void> _logout() async {
    await InMemoryFaceStorage().setLoggedIn(false);
    await InMemoryFaceStorage().setRole('');

    try {
      const channel = MethodChannel('fall_channel');
      await channel.invokeMethod('startService');
    } catch (e) {
      debugPrint('Error pinging service: $e');
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const StartupGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: CustomAppBar(
        title: 'Mon Espace',
        showBackButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black, size: 28),
            onPressed: _logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SOSButton(
              isPressed: _sosPressed,
              onTapDown: () => _handleSOSPress(),
              onTapUp: () => _handleSOSRelease(),
              onTapCancel: () => _handleSOSRelease(),
            ),
            const SizedBox(height: 30),
            _buildActionGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 20,
      crossAxisSpacing: 20,
      children: [
        QuickActionCard(
          title: 'Médicaments',
          subtitle: 'Mes rappels',
          icon: FontAwesomeIcons.pills,
          gradientColors: [Colors.blue, Colors.blueAccent],
          onTap: () => widget.onNavigate('medications'),
        ),
        QuickActionCard(
          title: 'Contacts',
          subtitle: 'Mes proches',
          icon: FontAwesomeIcons.addressBook,
          gradientColors: [Colors.green, Colors.greenAccent],
          onTap: () => widget.onNavigate('contacts'),
        ),
        QuickActionCard(
          title: 'Assistance',
          subtitle: 'Aide visuelle',
          icon: FontAwesomeIcons.universalAccess,
          gradientColors: [Colors.orange, Colors.orangeAccent],
          onTap: () => widget.onNavigate('accessibility'),
        ),
        QuickActionCard(
          title: 'Jeux',
          subtitle: 'Mémoire',
          icon: FontAwesomeIcons.gamepad,
          gradientColors: [Colors.purple, Colors.purpleAccent],
          onTap: () => widget.onNavigate('memory_game'),
        ),
        QuickActionCard(
          title: 'Alertes',
          subtitle: 'Historique SOS',
          icon: FontAwesomeIcons.bell,
          gradientColors: [Colors.red, Colors.redAccent],
          onTap: () => widget.onNavigate('alerts'),
        ),
        QuickActionCard(
          title: 'Tâches',
          subtitle: 'Ma journée',
          icon: FontAwesomeIcons.listCheck,
          gradientColors: [Colors.teal, Colors.tealAccent],
          onTap: () => widget.onNavigate('daily_tasks'),
        ),
      ],
    );
  }
}
