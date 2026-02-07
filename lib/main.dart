// ignore_for_file: deprecated_member_use

import 'package:care_link/features/face_auth/face_login_screen.dart';
import 'package:care_link/features/face_auth/face_signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/accessibility_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/medications_screen.dart';
import 'screens/family_dashboard_screen.dart';
import 'features/face_auth/face_storage.dart';
import 'screens/alerts_screen.dart';
import 'screens/caregiver_login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Assistance Senior',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      locale: const Locale('fr', 'FR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR')],
      home: const StartupGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class StartupGate extends StatelessWidget {
  const StartupGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _initializeAndCheck(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final loggedIn = snapshot.data ?? false;
        if (loggedIn) {
          return const MainNavigation();
        }
        return const AuthLandingScreen();
      },
    );
  }

  Future<bool> _initializeAndCheck() async {
    await InMemoryFaceStorage().initialize();
    return await InMemoryFaceStorage().isLoggedIn();
  }
}

class AuthLandingScreen extends StatelessWidget {
  const AuthLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Section Logo et Titre (1/3 de l'écran)
                Expanded(
                  flex: 2,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.blue[400]!, Colors.blue[600]!],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.health_and_safety_rounded,
                            size: 80,
                            color: Colors.blue[600],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Nom de l'application
                        const Text(
                          "CareLink",
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Votre santé, notre priorité",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Section Connexion (moitié inférieure)
                Expanded(
                  flex: 2,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Bouton Créer un compte
                        SizedBox(
                          width: double.infinity,
                          height: 70,
                          child: ElevatedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FaceSignupScreen(),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              foregroundColor: Colors.white,
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.person_add, size: 32),
                                SizedBox(width: 15),
                                Text(
                                  "Créer un compte",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Séparateur
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey[400], thickness: 1)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              child: Text(
                                "OU",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.grey[400], thickness: 1)),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Bouton Se connecter
                        SizedBox(
                          width: double.infinity,
                          height: 70,
                          child: OutlinedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FaceLoginScreen(),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue[600],
                              side: BorderSide(color: Colors.blue[600]!, width: 2.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.login, size: 32, color: Colors.blue[600]),
                                const SizedBox(width: 15),
                                Text(
                                  "Se connecter",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 10,
              right: 10,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CaregiverLoginScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.admin_panel_settings, size: 18),
                label: const Text('Aidant', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue[900],
                  backgroundColor: Colors.white.withOpacity(0.9),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Keeping MainNavigation for later reference if needed, but unused for now
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
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
      case 'family':
        screen = FamilyDashboardScreen(onBack: _goBack);
        break;
      case 'alerts':
        screen = const AlertsScreen();
        break;
      default:
        return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  void _goBack() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return HomeScreen(onNavigate: _navigateTo);
  }

  /*@override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HomeScreen(onNavigate: _navigateTo),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: "signupBtn",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FaceSignupScreen()),
              );
            },
            child: const Icon(Icons.person_add),
            tooltip: "Test Signup facial",
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: "loginBtn",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FaceLoginScreen()),
              );
            },
            child: const Icon(Icons.login),
            tooltip: "Test Login facial",
          ),
        ],
      ),
    );
  }*/
}
