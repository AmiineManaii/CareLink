import 'dart:async';
import 'dart:io';
import 'package:care_link/services/api_service.dart';
import 'package:care_link/utils/fonctions_utils.dart';
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
import 'package:image_picker/image_picker.dart';

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
  final ApiService _apiService = ApiService();

  bool _sosPressed = false;
  Timer? _sosTimer;
  StreamSubscription<Position?>? _positionSubscription;
  StreamSubscription<dynamic>? _fallSubscription;

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
    _fallSubscription = fallEventsChannel.receiveBroadcastStream().listen(
      _onFallEvent,
      onError: (error) => debugPrint('Erreur flux chutes: $error'),
    );
  }

  @override
  void dispose() {
    _sosTimer?.cancel();
    _positionSubscription?.cancel();
    _fallSubscription?.cancel();
    super.dispose();
  }

  Future<void> _takeimage() async {
    String elder = await InMemoryFaceStorage().getElderId() ?? '';
    String caregiver = await InMemoryFaceStorage().getCaregiverId() ?? '';
    var picker = ImagePicker();
    var pick = await picker.pickImage(source: ImageSource.gallery);
    if (pick == null) {
      return;
    }
    await _apiService.uploadImage(File(pick.path), elder, caregiver);
  }

  Future<void> _handleSOSPress() async {

    _sosTimer?.cancel();
    setState(() => _sosPressed = true);
    _sosTimer = Timer(const Duration(seconds: 2), () {
      if (_sosPressed) {
        _sosService.sendSOS(_locationService.lastKnownPosition);
        setState(() => _sosPressed = false);
        
      }
      
    });
    await _takeimage();
  }

  void _handleSOSRelease() {
    showSnackBar('SOS Envoyé', context);
    _sosTimer?.cancel();
    setState(() => _sosPressed = false);
  }

  Future<void> _onFallEvent(dynamic event) async {
    await _sosService.sendSOS(_locationService.lastKnownPosition);
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
