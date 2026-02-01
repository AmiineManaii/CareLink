import 'package:care_link/features/face_auth/face_debug_screen.dart';
import 'package:care_link/features/face_auth/face_login_screen.dart';
import 'package:care_link/features/face_auth/face_painter_test_screen.dart';
import 'package:care_link/features/face_auth/face_signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/accessibility_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/medications_screen.dart';
import 'screens/family_dashboard_screen.dart';

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
      // home: const MainNavigation(), // Old home
      home: const FaceAuthTestScreen(), // New test home
      debugShowCheckedModeBanner: false,
    );
  }
}

class FaceAuthTestScreen extends StatelessWidget {
  const FaceAuthTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Test Face Auth")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add),
              label: const Text("Tester Sign Up (Enregistrement)"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FaceSignupScreen()),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text("Tester Sign In (Connexion)"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FaceLoginScreen()),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FaceDetectionDebugScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: const Text('Mode Debug (Tester contours)'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FacePainterTestScreen()),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Démarrer le Test'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 18),
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
      default:
        return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  void _goBack() {
    Navigator.pop(context);
  }

  /*@override
  Widget build(BuildContext context) {
    return HomeScreen(onNavigate: _navigateTo);
  }*/
  @override
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
  }
}
