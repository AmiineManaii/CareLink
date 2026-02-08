import 'package:flutter/material.dart';
import 'package:care_link/features/face_auth/face_storage.dart';
import 'package:care_link/main.dart';
import 'caregiver_home_screen.dart';

class CaregiverNavigation extends StatefulWidget {
  const CaregiverNavigation({super.key});

  @override
  State<CaregiverNavigation> createState() => _CaregiverNavigationState();
}

class _CaregiverNavigationState extends State<CaregiverNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const CaregiverHomeScreen(),
    const Center(child: Text("Notifications (A venir)")),
    const Center(child: Text("Profil Aidant (A venir)")),
  ];

  Future<void> _logout(BuildContext context) async {
    await InMemoryFaceStorage().setLoggedIn(false);
    await InMemoryFaceStorage().setRole(''); // Clear role
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
          if (index == 3) { // Déconnexion (simulé par un index hors liste ou via bouton)
             // Optionnel: ajouter un bouton déconnexion dans l'UI plutôt que dans la barre
          } else {
            setState(() {
              _currentIndex = index;
            });
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Tableau de bord',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alertes',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
      // Ajout temporaire pour permettre la déconnexion facile pendant le dev
      floatingActionButton: _currentIndex == 2 
        ? FloatingActionButton.extended(
            onPressed: () => _logout(context),
            label: const Text("Déconnexion"),
            icon: const Icon(Icons.logout),
            backgroundColor: Colors.red[100],
            foregroundColor: Colors.red[900],
          ) 
        : null,
    );
  }
}
