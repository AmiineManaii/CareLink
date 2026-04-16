import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:care_link/features/face_auth/face_storage.dart';
import 'package:care_link/main.dart';
import 'caregiver_home_screen.dart';
import 'caregiver_profile_screen.dart';

class CaregiverNavigation extends StatefulWidget {
  const CaregiverNavigation({super.key});

  @override
  State<CaregiverNavigation> createState() => _CaregiverNavigationState();
}

class _CaregiverNavigationState extends State<CaregiverNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const CaregiverHomeScreen(),
    const CaregiverProfileScreen(),
  ];

  Future<void> _logout(BuildContext context) async {
    await InMemoryFaceStorage().setLoggedIn(false);
    await InMemoryFaceStorage().setRole(''); // Clear role

    // Ping le service pour rafraîchir la config
    try {
      const channel = MethodChannel('fall_channel');
      await channel.invokeMethod('startService');
    } catch (e) {
      debugPrint('Error pinging service: $e');
    }

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const StartupGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Tableau de bord',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
