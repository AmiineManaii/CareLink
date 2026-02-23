import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../widgets/quick_action_card.dart';
import '../../features/face_auth/face_storage.dart';
import '../../services/api_service.dart';
import 'medications/caregiver_medications_screen.dart';
import 'caregiver_alerts_screen.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

class CaregiverHomeScreen extends StatefulWidget {
  const CaregiverHomeScreen({super.key});

  @override
  State<CaregiverHomeScreen> createState() => _CaregiverHomeScreenState();
}

class _CaregiverHomeScreenState extends State<CaregiverHomeScreen> {
  Map<String, dynamic>? _elderProfile;
  bool _loading = false;
  String? _elderId;
  IO.Socket? _socket;
  Timer? _heartbeatTimer;
  bool? _elderOnline;
  String? _elderLastActiveAt;
  Timer? _statusTimer;
  String? _statusError;

  @override
  void initState() {
    super.initState();
    _loadElderInfo();
    _initSocket();
    _statusTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      _refreshPresenceViaHttp();
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
      final data = await ApiService().getElderProfile(id);
      //print("data: ${data['online']}");
      if (mounted) {
        setState(() {
          //print("data: ${data['online']}");
          _elderProfile = data['profile'];
          if (data['online'] == true) {
            //print("data2: ${data['online']}");
            _elderOnline = true;
          } else {
            //print("data2: ${data['online']}");
            _elderOnline = false;
          }
          final last = data['lastActiveAt'];
          _elderLastActiveAt = last != null ? last.toString() : null;
          //print(_elderLastActiveAt);
        });
      }
    } catch (e) {
      debugPrint('Error loading elder info: $e');
      if (mounted) {
        setState(() {
          _statusError = 'Impossible de charger le statut de connexion';
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_statusError!)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _initSocket() async {
    final caregiverId = InMemoryFaceStorage().getCaregiverId();
    if (caregiverId == null) return;
    final baseUrl = ApiService().baseUrl;
    try {
      _socket = IO.io(
        baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .build(),
      );
      _socket!.onConnect((_) {
        _socket!.emit('registerCaregiver', {'caregiverId': caregiverId});
        _heartbeatTimer?.cancel();
        _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
          _socket!.emit('caregiverHeartbeat');
        });
      });
      _socket!.on('elderPresence', (data) {
        if (!mounted) return;
        setState(() {
          //print("data: ${data['online']}");
          _elderOnline = data['online'] == true;
          final last = data['lastActiveAt'];
          _elderLastActiveAt = last != null ? last.toString() : null;
          _statusError = null;
        });
      });
      _socket!.onError((error) {
        if (!mounted) return;
        setState(() {
          _statusError = 'Erreur de connexion temps réel';
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_statusError!)));
      });
      _socket!.onDisconnect((_) {
        _heartbeatTimer?.cancel();
      });
      _socket!.connect();
    } catch (e) {
      debugPrint('Socket error: $e');
    }
  }

  Future<void> _refreshPresenceViaHttp() async {
    final caregiverId = InMemoryFaceStorage().getCaregiverId();
    if (caregiverId == null) return;
    try {
      final data = await ApiService().caregiverHeartbeat(caregiverId);
      if (!mounted) return;
      final elder = data['elder'];
      if (elder is Map<String, dynamic>) {
        setState(() {
          _elderOnline = elder['online'] == true;
          final last = elder['lastActiveAt'];
          _elderLastActiveAt = last != null ? last.toString() : null;
          _statusError = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (_statusError == null) {
        setState(() {
          _statusError = 'Perte de connexion au serveur de statut';
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_statusError!)));
      }
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _statusTimer?.cancel();
    _socket?.dispose();
    super.dispose();
  }

  void _showElderProfileDialog() {
    if (_elderProfile == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _elderOnline == true ? Colors.green : Colors.red,
                    width: 2,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Name
              Text(
                '${_elderProfile!['firstName'] ?? ''} ${_elderProfile!['lastName'] ?? ''}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Info Details
              _buildProfileDetailRow(
                Icons.wc_outlined,
                'Genre',
                _elderProfile!['gender'] ?? 'N/A',
              ),
              const SizedBox(height: 12),
              if (_elderProfile!['age'] != null)
                _buildProfileDetailRow(
                  Icons.cake_outlined,
                  'Âge',
                  '${_elderProfile!['age']} ans',
                ),
              if (_elderProfile!['age'] != null) const SizedBox(height: 12),
              if (_elderProfile!['phone'] != null)
                _buildProfileDetailRow(
                  Icons.phone_outlined,
                  'Téléphone',
                  _elderProfile!['phone'],
                ),
              if (_elderProfile!['phone'] != null) const SizedBox(height: 12),
              if (_elderProfile!['email'] != null)
                _buildProfileDetailRow(
                  Icons.email_outlined,
                  'Email',
                  _elderProfile!['email'],
                ),

              const SizedBox(height: 24),

              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Fermer',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatLastSeen(String iso) {
    try {
      final dt = DateTime.tryParse(iso)?.toLocal();
      if (dt == null) return 'Dernière activité inconnue';
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 2) {
        final seconds = diff.inSeconds.clamp(0, 119);
        return 'Vu il y a $seconds s';
      }
      if (diff.inHours < 1) {
        return 'Vu il y a ${diff.inMinutes} min';
      }
      if (diff.inHours < 24) {
        return 'Vu il y a ${diff.inHours} h';
      }
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return 'Vu le $d/$m à $hh:$mm';
    } catch (_) {
      return 'Dernière activité inconnue';
    }
  }

  Widget _buildElderStatusBar() {
    if (_elderId == null || _elderProfile == null) {
      return const ElderStatusIndicator(
        online: false,
        title: 'Aucun senior lié',
        subtitle: null,
        onTap: null,
      );
    }
    final name =
        '${_elderProfile!['firstName'] ?? ''} ${_elderProfile!['lastName'] ?? ''}'
            .trim();
    final online = _elderOnline == true;
    String statusText;
    String? subtitle;
    if (online) {
      statusText = 'En ligne';
      if (name.isNotEmpty) {
        subtitle = name;
      }
    } else {
      statusText = 'Hors ligne';
      if (_elderLastActiveAt != null) {
        subtitle = _formatLastSeen(_elderLastActiveAt!);
      } else if (name.isNotEmpty) {
        subtitle = name;
      }
    }
    return ElderStatusIndicator(
      online: online,
      title: statusText,
      subtitle: subtitle,
      onTap: _showElderProfileDialog,
    );
  }

  Widget _buildProfileDetailRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                title: _buildElderStatusBar(),
                centerTitle: false,
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade50, Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),

            // Content
            SliverPadding(
              padding: const EdgeInsets.all(20.0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_elderId != null && _elderProfile != null)
                    const CaregiverHomeConnectedContent()
                  else
                    const CaregiverNoElderCard(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Elder Profile Card
        //_buildElderProfileCard(),
        const SizedBox(height: 24),

        // Quick Actions Title
        Row(
          children: [
            Icon(Icons.flash_on, color: Colors.orange.shade600, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Actions rapides',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Quick Actions Grid
        _buildQuickActionsGrid(),
        const SizedBox(height: 24),

        // Additional Features
        _buildAdditionalFeatures(),
      ],
    );
  }

  Widget _buildElderProfileCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _showElderProfileDialog,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Avatar
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _elderOnline == true ? Colors.green : Colors.red,
                      width: 2,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.purple.shade300,
                          Colors.purple.shade500,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Senior lié',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '${_elderProfile!['firstName'] ?? ''} ${_elderProfile!['lastName'] ?? ''}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          _PresenceDot(online: _elderOnline == true),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Voir le profil complet',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey.shade400,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: QuickActionCard(
                title: 'Localisation',
                subtitle: 'Position GPS',
                icon: FontAwesomeIcons.locationDot,
                gradientColors: [
                  Colors.orange.shade400,
                  Colors.orange.shade600,
                ],
                onTap: () {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: QuickActionCard(
                title: 'Santé',
                subtitle: 'Constantes',
                icon: FontAwesomeIcons.heartPulse,
                gradientColors: [Colors.red.shade400, Colors.red.shade600],
                onTap: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: QuickActionCard(
                title: 'Alertes',
                subtitle: 'Notifications',
                icon: FontAwesomeIcons.bell,
                gradientColors: [Colors.amber.shade400, Colors.amber.shade600],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CaregiverAlertsScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: QuickActionCard(
                title: 'Historique',
                subtitle: 'Activités',
                icon: FontAwesomeIcons.clockRotateLeft,
                gradientColors: [Colors.teal.shade400, Colors.teal.shade600],
                onTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdditionalFeatures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.more_horiz, color: Colors.grey.shade700, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Plus de fonctionnalités',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildFeatureListTile(
          icon: Icons.calendar_today_outlined,
          title: 'Rendez-vous médicaux',
          subtitle: 'Gérer les consultations',
          onTap: () {},
        ),
        const SizedBox(height: 8),
        _buildFeatureListTile(
          icon: Icons.medication_outlined,
          title: 'Médicaments',
          subtitle: 'Rappels de prise',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CaregiverMedicationsScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildFeatureListTile(
          icon: Icons.phone_outlined,
          title: 'Appel d\'urgence',
          subtitle: 'Contacter rapidement',
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildFeatureListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.blue.shade600, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Colors.grey.shade400,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildNoElderCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 60,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun senior lié',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Veuillez vous reconnecter ou contacter le support pour lier un compte senior.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              // Contact support or retry
            },
            icon: const Icon(Icons.support_agent),
            label: const Text('Contacter le support'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Contenu principal de l’écran d’accueil aidant quand un senior est lié.
class CaregiverHomeConnectedContent extends StatelessWidget {
  const CaregiverHomeConnectedContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Row(
          children: [
            Icon(Icons.flash_on, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Text(
              'Actions rapides',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CaregiverQuickActionsSection(),
        const SizedBox(height: 24),
        CaregiverAdditionalFeaturesSection(
          onMedicationsTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CaregiverMedicationsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Grille des actions rapides accessibles depuis l’écran d’accueil aidant.
class CaregiverQuickActionsSection extends StatelessWidget {
  const CaregiverQuickActionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: QuickActionCard(
                title: 'Localisation',
                subtitle: 'Position GPS',
                icon: FontAwesomeIcons.locationDot,
                gradientColors: [
                  Colors.orange.shade400,
                  Colors.orange.shade600,
                ],
                onTap: () {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: QuickActionCard(
                title: 'Santé',
                subtitle: 'Constantes',
                icon: FontAwesomeIcons.heartPulse,
                gradientColors: [Colors.red.shade400, Colors.red.shade600],
                onTap: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: QuickActionCard(
                title: 'Alertes',
                subtitle: 'Notifications',
                icon: FontAwesomeIcons.bell,
                gradientColors: [Colors.amber.shade400, Colors.amber.shade600],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CaregiverAlertsScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: QuickActionCard(
                title: 'Historique',
                subtitle: 'Activités',
                icon: FontAwesomeIcons.clockRotateLeft,
                gradientColors: [Colors.teal.shade400, Colors.teal.shade600],
                onTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Liste des fonctionnalités additionnelles proposées à l’aidant.
class CaregiverAdditionalFeaturesSection extends StatelessWidget {
  final VoidCallback? onAppointmentsTap;
  final VoidCallback? onMedicationsTap;
  final VoidCallback? onEmergencyTap;

  const CaregiverAdditionalFeaturesSection({
    super.key,
    this.onAppointmentsTap,
    this.onMedicationsTap,
    this.onEmergencyTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.more_horiz, color: Colors.grey.shade700, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Plus de fonctionnalités',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _CaregiverFeatureListTile(
          icon: Icons.calendar_today_outlined,
          title: 'Rendez-vous médicaux',
          subtitle: 'Gérer les consultations',
          onTap: onAppointmentsTap,
        ),
        const SizedBox(height: 8),
        _CaregiverFeatureListTile(
          icon: Icons.medication_outlined,
          title: 'Médicaments',
          subtitle: 'Rappels de prise',
          onTap: onMedicationsTap,
        ),
        const SizedBox(height: 8),
        _CaregiverFeatureListTile(
          icon: Icons.phone_outlined,
          title: 'Appel d\'urgence',
          subtitle: 'Contacter rapidement',
          onTap: onEmergencyTap,
        ),
      ],
    );
  }
}

class _CaregiverFeatureListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _CaregiverFeatureListTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap ?? () {},
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.blue.shade600, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Colors.grey.shade400,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Carte affichée lorsque aucun senior n’est encore lié à l’aidant.
class CaregiverNoElderCard extends StatelessWidget {
  final VoidCallback? onSupportTap;

  const CaregiverNoElderCard({super.key, this.onSupportTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 60,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun senior lié',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Veuillez vous reconnecter ou contacter le support pour lier un compte senior.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onSupportTap ?? () {},
            icon: const Icon(Icons.support_agent),
            label: const Text('Contacter le support'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicateur de statut en ligne/hors ligne du senior dans la barre d’app.
class ElderStatusIndicator extends StatelessWidget {
  final bool online;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const ElderStatusIndicator({
    super.key,
    required this.online,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color cardColor = online ? Colors.green : Colors.red;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          key: const Key('elderStatusCircleTap'),
          onTap: onTap,
          child: Card(
            elevation: 2,
            shape: const CircleBorder(),
            margin: EdgeInsets.zero,
            child: AnimatedContainer(
              key: const Key('elderStatusCircleContainer'),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: cardColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
              ),
          ],
        ),
      ],
    );
  }
}

/// Petit point animé indiquant la présence en ligne du senior.
class _PresenceDot extends StatefulWidget {
  final bool online;

  const _PresenceDot({required this.online});

  @override
  State<_PresenceDot> createState() => _PresenceDotState();
}

class _PresenceDotState extends State<_PresenceDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      lowerBound: 0.9,
      upperBound: 1.1,
    );
    if (widget.online) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _PresenceDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.online && !oldWidget.online) {
      _controller.repeat(reverse: true);
    } else if (!widget.online && oldWidget.online) {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color = widget.online
        ? const Color(0xFF00FF00)
        : const Color(0xFFFF0000);
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = widget.online ? _controller.value : 1.0;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          );
        },
      ),
    );
  }
}
