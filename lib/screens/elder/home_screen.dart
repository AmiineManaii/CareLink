// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'package:care_link/features/face_auth/face_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/api_service.dart';
import '../../services/medication_reminder_service.dart';
import '../../models/medication.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import '../../widgets/custom_app_bar.dart';
import '../../widgets/sos_button.dart';
import '../../widgets/quick_action_card.dart';
import 'color_memory_game.dart';
import '../../main.dart';

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
  static const MethodChannel _fallChannel = MethodChannel('fall_channel');
  static const EventChannel _fallEventsChannel = EventChannel('fall_events');

  final String smtpHost = dotenv.env['SMTP_HOST'] ?? 'smtp.gmail.com';
  final int smtpPort = int.tryParse(dotenv.env['SMTP_PORT'] ?? '') ?? 587;
  final String smtpUser = dotenv.env['SMTP_USER'] ?? '';
  final String smtpPassword = dotenv.env['SMTP_PASS'] ?? '';
  final String smtpRecipient = dotenv.env['SMTP_TO'] ?? '';
  final String smsRecipient = dotenv.env['SMS_TO'] ?? '';

  @override
  void initState() {
    super.initState();
    _setupApp();
  }

  Future<void> _setupApp() async {
    await _initNotifications();
    await _initFallDetection();
    _startLocationUpdates();
    await _fetchCaregiverPhone();
    await _scheduleMedications();
    await _scheduleDailyTasks();
  }

  Future<void> _scheduleDailyTasks() async {
    try {
      final elderId = InMemoryFaceStorage().getElderId();
      if (elderId == null) return;

      final tasks = await ApiService().getElderTasks(
        elderId,
        date: DateTime.now(),
      );

      for (var task in tasks) {
        if (task['reminderEnabled'] != true || task['isCompleted'] == true)
          continue;

        final taskTime = task['time'] as String; // HH:mm
        final taskDate = DateTime.parse(task['date']);
        final parts = taskTime.split(':');

        DateTime scheduledDate = DateTime(
          taskDate.year,
          taskDate.month,
          taskDate.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );

        // Heure réelle de la tâche
        final DateTime actualTaskTime = scheduledDate.add(
          const Duration(minutes: 15),
        );

        // On garde le label par défaut (15 min avant)
        String label = "${task['title']} (dans 15 min)";

        if (scheduledDate.isBefore(DateTime.now())) {
          // Si l'alerte des 15 min est passée, mais que l'heure réelle est future
          if (actualTaskTime.isAfter(DateTime.now())) {
            scheduledDate = actualTaskTime;
            label = "${task['title']} (Maintenant)";
          } else {
            continue; // Les deux sont passés
          }
        }

        final id = task['_id'].toString();
        const channel = MethodChannel('fall_channel');
        await channel.invokeMethod('scheduleTask', {
          'id': id,
          'title': label,
          'description': task['description'] ?? '',
          'timestamp': scheduledDate.millisecondsSinceEpoch,
        });
      }
      debugPrint("Scheduled ${tasks.length} tasks from Home");
    } catch (e) {
      debugPrint("Error scheduling tasks from Home: $e");
    }
  }

  Future<void> _scheduleMedications() async {
    try {
      final elderId = InMemoryFaceStorage().getElderId();
      if (elderId == null) return;

      final data = await ApiService().getMedications(elderId);
      final allMeds = data.map((json) => Medication.fromJson(json)).toList();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final todayMeds = allMeds.where((med) {
        if (!med.active) return false;

        final start = DateTime(
          med.startDate.year,
          med.startDate.month,
          med.startDate.day,
        );
        if (start.isAfter(today)) return false;

        if (med.endDate != null) {
          final end = DateTime(
            med.endDate!.year,
            med.endDate!.month,
            med.endDate!.day,
          );
          if (end.isBefore(today)) return false;
        }

        if (med.frequency == 'Hebdomadaire' && med.days.isNotEmpty) {
          if (!med.days.contains(now.weekday)) return false;
        }

        return true;
      }).toList();

      await MedicationReminderService.scheduleForMedications(todayMeds);
      debugPrint("Scheduled ${todayMeds.length} medications from Home");
    } catch (e) {
      debugPrint("Error scheduling medications from Home: $e");
    }
  }

  Future<void> _fetchCaregiverPhone() async {
    final elderId = InMemoryFaceStorage().getElderId();
    if (elderId == null) return;

    // Si on a déjà le téléphone, pas besoin de re-fetcher
    if (InMemoryFaceStorage().getCaregiverPhone() != null) return;

    try {
      final data = await ApiService().getElderCaregiver(elderId);
      if (data['caregiver'] != null && data['caregiver']['phone'] != null) {
        await InMemoryFaceStorage().setCaregiverPhone(
          data['caregiver']['phone'],
        );
        debugPrint(
          "Téléphone de l'aidant récupéré: ${data['caregiver']['phone']}",
        );
      }
    } catch (e) {
      debugPrint("Erreur récupération téléphone aidant pour SMS SOS: $e");
    }
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

      // Try to get current position with a reasonable timeout
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 15),
        );
      } catch (e) {
        // If current position fails or timeouts, fallback to last known position
        position = await Geolocator.getLastKnownPosition();
        // debugPrint("Timeout getCurrentPosition, using last known: $position");
      }

      if (position != null) {
        if (mounted) {
          setState(() {
            _lastKnownPosition = position;
          });
        } else {
          _lastKnownPosition = position;
        }
      }
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
    _sosTimer?.cancel(); // Cancel any existing timer to avoid double triggers
    setState(() => _sosPressed = true);
    _sosTimer = Timer(const Duration(seconds: 2), () {
      if (_sosPressed) {
        _sendSOS();
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
    await InMemoryFaceStorage().setRole(''); // Clear role on logout

    // Ping le service pour rafraîchir la config (désactiver capteurs)
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

  Future<void> _initNotifications() async {
    tz_data.initializeTimeZones();

    // Demander la permission sur Android 13+
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (status.isDenied) {
        await Permission.notification.request();
      }
    }
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

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<void> _sendSMSFallback(String lat, String lon) async {
    // Try to get caregiver phone from storage first
    String recipient =
        InMemoryFaceStorage().getCaregiverPhone() ?? smsRecipient;

    if (recipient.isEmpty) {
      debugPrint("SMS Fallback: No recipient configured");
      return;
    }

    try {
      final status = await Permission.sms.request();
      if (status.isGranted) {
        final message =
            "ALERTE SOS - CareLink\n"
            "Position: https://www.google.com/maps?q=$lat,$lon\n"
            "Lat: $lat, Lon: $lon";

        await _fallChannel.invokeMethod('sendSMS', {
          'phone': recipient,
          'message': message,
        });
        debugPrint("SOS SMS envoyé à $recipient");
      } else {
        debugPrint("Permission SMS refusée");
      }
    } catch (e) {
      debugPrint("Erreur envoi SMS fallback: $e");
    }
  }

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

      // --- CHECK INTERNET ---
      bool hasNet = await _hasInternet();

      if (!hasNet) {
        debugPrint("Mode Hors Ligne détecté - Envoi SMS Fallback");
        await _sendSMSFallback(lat, lon);
        if (showDialog) {
          await _showMessage('SOS envoyé par SMS (Pas d\'internet)');
        }
        return true;
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
      debugPrint("Erreur SOS (Email/API): $e - Tentative SMS Fallback");
      // Fallback SMS si l'email/API échoue (peut-être internet instable)
      String lat = _lastKnownPosition?.latitude.toStringAsFixed(6) ?? '0.0';
      String lon = _lastKnownPosition?.longitude.toStringAsFixed(6) ?? '0.0';
      await _sendSMSFallback(lat, lon);

      if (showDialog) {
        await _showMessage('SOS envoyé par SMS (Erreur Internet)');
      }
      return true;
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
      backgroundColor: const Color(
        0xFFF0F9F9,
      ), // Teal très très clair (Teal 50)
      appBar: CustomAppBar(
        title: 'Accueil',
        showBackButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () => _logout(),
          ),
        ],
      ),
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
                    icon: FontAwesomeIcons.pills,
                    gradientColors: const [
                      Color(0xFF7E57C2),
                      Color(0xFF5E35B1),
                    ],
                    onTap: () => widget.onNavigate('medications'),
                  ),
                  QuickActionCard(
                    title: 'Mes Tâches',
                    subtitle: 'Quotidien',
                    icon: FontAwesomeIcons.listCheck,
                    gradientColors: const [
                      Color(0xFF42A5F5),
                      Color(0xFF1E88E5),
                    ],
                    onTap: () => widget.onNavigate('daily_tasks'),
                  ),
                  QuickActionCard(
                    title: 'Contacts',
                    subtitle: 'Appel rapide',
                    icon: FontAwesomeIcons.phone,
                    gradientColors: const [
                      Color(0xFF66BB6A),
                      Color(0xFF43A047),
                    ],
                    onTap: () => widget.onNavigate('contacts'),
                  ),
                  QuickActionCard(
                    title: 'Assistance',
                    subtitle: 'Outils vocaux',
                    icon: FontAwesomeIcons.volumeHigh,
                    gradientColors: const [
                      Color(0xFF26A69A),
                      Color(0xFF00897B),
                    ],
                    onTap: () => widget.onNavigate('accessibility'),
                  ),
                  QuickActionCard(
                    title: 'Alertes',
                    subtitle: 'Historique',
                    icon: FontAwesomeIcons.triangleExclamation,
                    gradientColors: const [
                      Color(0xFFFFA726),
                      Color(0xFFFB8C00),
                    ],
                    onTap: () => widget.onNavigate('alerts'),
                  ),
                  QuickActionCard(
                    title: 'Mémoire',
                    subtitle: 'Jeu de couleurs',
                    icon: FontAwesomeIcons.brain,
                    gradientColors: const [
                      Color(0xFFEF5350),
                      Color(0xFFE53935),
                    ],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ColorMemoryGame(),
                        ),
                      );
                    },
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
