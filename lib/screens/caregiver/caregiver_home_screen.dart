import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:care_link/widgets/common/quick_action_card.dart';
import 'package:care_link/services/auth/face_storage.dart';
import 'package:care_link/services/api_service.dart';
import 'package:care_link/services/presence_service.dart';
import 'medications/caregiver_medications_screen.dart';
import 'caregiver_contacts_screen.dart';
import 'caregiver_alerts_screen.dart';
import 'caregiver_tasks_screen.dart';
import 'elder_profile_edit_screen.dart';
import 'dart:async';

class CaregiverHomeScreen extends StatefulWidget {
  const CaregiverHomeScreen({super.key});

  @override
  State<CaregiverHomeScreen> createState() => _CaregiverHomeScreenState();
}

class _CaregiverHomeScreenState extends State<CaregiverHomeScreen> {
  final PresenceService _presenceService = PresenceService();
  final ApiService _apiService = ApiService();

  Map<String, dynamic>? _elderProfile;
  bool _loading = false;
  String? _elderId;
  bool? _elderOnline;
  String? _elderLastActiveAt;
  Timer? _statusTimer;
  String? _statusError;
  StreamSubscription? _presenceSubscription;

  @override
  void initState() {
    super.initState();
    _loadElderInfo();
    _presenceService.initSocket('aidant');

    _presenceSubscription = _presenceService.presenceStream.listen((data) {
      if (!mounted) return;
      setState(() {
        _elderOnline = data['online'] == true;
        final last = data['lastActiveAt'];
        _elderLastActiveAt = last?.toString();
        _statusError = null;
      });
    });

    _statusTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final caregiverId = InMemoryFaceStorage().getCaregiverId();
      if (caregiverId != null) {
        _presenceService.refreshPresenceViaHttp(caregiverId).catchError((e) {
          if (mounted && _statusError == null) {
            setState(() => _statusError = 'Erreur de connexion');
          }
        });
      }
    });
  }

  Future<void> _loadElderInfo() async {
    final id = InMemoryFaceStorage().getElderId();
    if (id == null) return;

    setState(() {
      _elderId = id;
      _loading = true;
    });

    try {
      final data = await _apiService.getElderProfile(id);
      if (mounted) {
        setState(() {
          _elderProfile = data['profile'];
          _elderOnline = data['online'] == true;
          final last = data['lastActiveAt'];
          _elderLastActiveAt = last?.toString();
        });
      }
    } catch (e) {
      debugPrint('Error loading elder info: $e');
      if (mounted) {
        setState(() => _statusError = 'Erreur de chargement');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _presenceSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 24),
                  const Text(
                    "Actions rapides",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildActionGrid(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: Colors.blue[700],
      flexibleSpace: FlexibleSpaceBar(
        title: const Text("Tableau de bord"),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[700]!, Colors.blue[500]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            _buildElderAvatar(),
            const SizedBox(width: 16),
            Expanded(child: _buildElderInfo()),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () {
                if (_elderId != null && _elderProfile != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ElderProfileEditScreen(
                        elderId: _elderId!,
                        initialProfile: _elderProfile!,
                      ),
                    ),
                  ).then((_) => _loadElderInfo());
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profil non chargé')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildElderAvatar() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.blue[100],
          child: const Icon(Icons.person, size: 40, color: Colors.blue),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: _elderOnline == true ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildElderInfo() {
    if (_loading) return const LinearProgressIndicator();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _elderProfile != null
              ? "${_elderProfile!['firstName']} ${_elderProfile!['lastName']}"
              : "Chargement...",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          _elderOnline == true ? "En ligne" : "Hors ligne",
          style: TextStyle(
            color: _elderOnline == true ? Colors.green : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (_elderOnline != true && _elderLastActiveAt != null)
          Text(
            "Vu à ${_elderLastActiveAt!}",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
      ],
    );
  }

  Widget _buildActionGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        QuickActionCard(
          title: "Médicaments",
          subtitle: "Gérer les rappels",
          icon: FontAwesomeIcons.pills,
          gradientColors: [Colors.orange, Colors.deepOrange],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CaregiverMedicationsScreen(
                elderId: _elderId ?? '',
                elderName: _elderProfile?['firstName'] ?? '',
              ),
            ),
          ),
        ),
        QuickActionCard(
          title: "Contacts",
          subtitle: "Contacts d'urgence",
          icon: FontAwesomeIcons.addressBook,
          gradientColors: [Colors.green, Colors.teal],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CaregiverContactsScreen(
                elderId: _elderId ?? '',
                elderName: _elderProfile?['firstName'] ?? '',
              ),
            ),
          ),
        ),
        QuickActionCard(
          title: "Alertes",
          subtitle: "Historique des alertes",
          icon: FontAwesomeIcons.bell,
          gradientColors: [Colors.red, Colors.pink],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CaregiverAlertsScreen()),
          ),
        ),
        QuickActionCard(
          title: "Tâches",
          subtitle: "Suivi quotidien",
          icon: FontAwesomeIcons.tasks,
          gradientColors: [Colors.blue, Colors.indigo],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CaregiverTasksScreen(
                elderId: _elderId ?? '',
                elderName: _elderProfile?['firstName'] ?? '',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
