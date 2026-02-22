// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Message;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../features/face_auth/face_storage.dart';
import '../../services/api_service.dart';

import '../../widgets/custom_app_bar.dart';
import '../../widgets/sos_button.dart';
import '../../widgets/quick_action_card.dart';

class HomeScreen extends StatefulWidget {
  final Function(String) onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _sosPressed = false;
  Timer? _sosTimer;
  Timer? _locationTimer; // Timer pour mettre à jour la position périodiquement
  Position? _lastKnownPosition; // Stocker la dernière position connue

  StreamSubscription<dynamic>? _fallSubscription;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static const MethodChannel _fallChannel = MethodChannel('fall_channel');
  static const EventChannel _fallEventsChannel = EventChannel('fall_events');

  final String smtpHost = dotenv.env['SMTP_HOST'] ?? 'smtp.gmail.com';
  final int smtpPort = int.tryParse(dotenv.env['SMTP_PORT'] ?? '') ?? 587;
  final String smtpUser = dotenv.env['SMTP_USER'] ?? '';
  final String smtpPassword = dotenv.env['SMTP_PASS'] ?? '';
  final String smtpRecipient = dotenv.env['SMTP_TO'] ?? '';

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _initFallDetection();
    _startLocationUpdates(); // Démarrer le suivi de position
  }

  // Fonction pour mettre à jour la position toutes les 30 secondes
  void _startLocationUpdates() {
    // Première récupération immédiate
    _updatePosition();

    // Puis toutes les 30 secondes
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updatePosition();
    });
  }

  Future<void> _updatePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever)
        return;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      if (mounted) {
        setState(() {
          _lastKnownPosition = position;
        });
      } else {
        _lastKnownPosition = position;
      }
      /*debugPrint(
        "Position mise à jour: ${position.latitude}, ${position.longitude}",
      );*/
    } catch (e) {
      debugPrint("Erreur mise à jour position périodique: $e");
    }
  }

  @override
  void dispose() {
    _sosTimer?.cancel();
    _locationTimer?.cancel(); // Arrêter le timer de localisation
    _fallSubscription?.cancel();
    super.dispose();
  }

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

  Future<void> _initNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);
    await _notifications.initialize(settings);
  }

  Future<void> _initFallDetection() async {
    try {
      await _fallChannel.invokeMethod('startService');
    } catch (e) {
      debugPrint('Erreur démarrage service chute: $e');
    }
    _fallSubscription = _fallEventsChannel.receiveBroadcastStream().listen(
      _onFallEvent,
      onError: (error) => debugPrint('Erreur flux chutes: $error'),
    );
  }

  Future<void> _onFallEvent(dynamic event) async {
    final success = await _sendSOS(showDialog: false);

    // La notification est gérée par le service Android,
    // mais on peut mettre à jour le statut dans l'appli si elle est ouverte.
    if (!success) {
      debugPrint("Échec de l'envoi du SOS automatique");
    } else {
      debugPrint("SOS automatique envoyé avec succès");
    }
  }

  // Future<void> _showFallNotification(String body) async { ... } (Supprimé car géré par Android)

  Future<bool> _sendSOS({bool showDialog = true}) async {
    try {
      // Tenter de récupérer la position, mais ne pas bloquer si ça échoue
      String lat = 'Inconnue';
      String lon = 'Inconnue';

      try {
        // Utiliser la dernière position connue si disponible (mise à jour en arrière-plan)
        if (_lastKnownPosition != null) {
          lat = _lastKnownPosition!.latitude.toStringAsFixed(6);
          lon = _lastKnownPosition!.longitude.toStringAsFixed(6);
          debugPrint("Utilisation de la dernière position connue: $lat, $lon");
        } else {
          // Sinon fallback sur une nouvelle demande (peut échouer si background)
          Position? lastPosition = await Geolocator.getLastKnownPosition();
          if (lastPosition != null) {
            lat = lastPosition.latitude.toStringAsFixed(6);
            lon = lastPosition.longitude.toStringAsFixed(6);
          }
        }
      } catch (e) {
        debugPrint(
          "Erreur récupération localisation (SOS continue quand même): $e",
        );
      }

      final elderId = InMemoryFaceStorage().getElderId();
      if (elderId != null) {
        try {
          // Si lat/lon inconnue, on peut envoyer 0.0 ou gérer côté serveur
          await ApiService().createSosAlert(
            elderId: elderId,
            latitude: lat == 'Inconnue' ? '0.0' : lat,
            longitude: lon == 'Inconnue' ? '0.0' : lon,
          );
        } catch (e) {
          debugPrint("Erreur API SOS: $e");
        }
      }

      if (smtpUser.isEmpty || smtpPassword.isEmpty || smtpRecipient.isEmpty) {
        if (showDialog) {
          await _showMessage('Configuration SMTP manquante');
        }
        return false;
      }

      final smtpServer = SmtpServer(
        smtpHost,
        port: smtpPort,
        username: smtpUser,
        password: smtpPassword,
        ssl: false,
        allowInsecure: false,
      );

      String mapLink = (lat != 'Inconnue' && lon != 'Inconnue')
          ? 'https://www.google.com/maps?q=$lat,$lon'
          : 'Position non disponible';

      final message = Message()
        ..from = Address(smtpUser, 'CareLink SOS')
        ..recipients.add(smtpRecipient)
        ..subject = '🚨 SOS – Alerte Urgente (Chute Détectée)'
        ..text =
            '''
ALERTE SOS 🚨

Latitude  : $lat
Longitude : $lon

Google Maps :
$mapLink
''';

      await send(message, smtpServer);
      if (showDialog) {
        await _showMessage('SOS envoyé avec succès');
      }
      return true;
    } catch (e) {
      debugPrint("Erreur critique envoi SOS: $e");
      if (showDialog) {
        await _showMessage('Erreur SMTP : $e');
      }
      return false;
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
          ),
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
            */
            ],
          ),
        ),
      ),
    );
  }
}
