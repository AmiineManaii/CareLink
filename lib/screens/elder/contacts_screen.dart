import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/info_card.dart';
import '../../widgets/contact_widgets.dart';
import '../../models/contact.dart';
import '../../features/face_auth/face_storage.dart';
import '../../services/api_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  String? _elderCode;
  Map<String, dynamic>? _caregiver;
  bool _loadingCaregiver = false;
  Timer? _relativeTimer;
  List<dynamic> _dynamicContacts = [];
  bool _loadingContacts = true;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchCaregiverInfo();
    _fetchDynamicContacts();
    _relativeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted &&
          _caregiver != null &&
          _caregiver!['lastActiveAt'] != null) {
        setState(() {});
      }
    });
  }

  Future<void> _fetchDynamicContacts() async {
    final elderId = InMemoryFaceStorage().getElderId();
    if (elderId == null) return;

    try {
      final data = await _apiService.getContacts(elderId);
      if (mounted) {
        setState(() {
          _dynamicContacts = data;
          _loadingContacts = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dynamic contacts: $e');
      if (mounted) setState(() => _loadingContacts = false);
    }
  }

  String _formatLastSeen(String iso) {
    try {
      final dt = DateTime.tryParse(iso)?.toLocal();
      if (dt == null) return 'Hors ligne';
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 2)
        return 'Vu il y a ${diff.inSeconds.clamp(0, 119)} s';
      if (diff.inHours < 1) return 'Vu il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Vu il y a ${diff.inHours} h';
      return 'Vu le ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'Hors ligne';
    }
  }

  Future<void> _fetchCaregiverInfo() async {
    final elderId = InMemoryFaceStorage().getElderId();
    if (elderId == null) return;

    setState(() {
      _loadingCaregiver = true;
    });

    try {
      final data = await ApiService().getElderCaregiver(elderId);
      if (mounted) {
        setState(() {
          _elderCode = data['code'];
          _caregiver = data['caregiver'];
        });
        // Save caregiver phone for SOS SMS
        if (_caregiver != null && _caregiver!['phone'] != null) {
          await InMemoryFaceStorage().setCaregiverPhone(_caregiver!['phone']);
        }
      }
    } catch (e) {
      debugPrint('Error fetching caregiver info: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingCaregiver = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _relativeTimer?.cancel();
    super.dispose();
  }

  List<Contact> get favorites => [];
  List<Contact> get otherContacts => [];
  List<Contact> contacts = [];
  bool _recordingVoice = false;

  void _handleCall(Contact contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('📞 Appel de ${contact.name}'),
        content: Text(
          '${contact.phone}\n\n(En production, cela lancerait un vrai appel)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleVideoCall(Contact contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('📹 Appel vidéo de ${contact.name}'),
        content: const Text('(En production, cela lancerait un appel vidéo)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleVoiceMessage(Contact contact) {
    if (!_recordingVoice) {
      setState(() {
        _recordingVoice = true;
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            '🎤 Enregistrement d\'un message vocal pour ${contact.name}',
          ),
          content: const Text('Parlez maintenant!'),
        ),
      );

      Future.delayed(const Duration(seconds: 3), () {
        setState(() {
          _recordingVoice = false;
        });
        // ignore: use_build_context_synchronously
        Navigator.pop(context);
        showDialog(
          // ignore: use_build_context_synchronously
          context: context,
          builder: (context) => AlertDialog(
            title: Text('✅ Message vocal envoyé à ${contact.name}!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
    }
  }

  void _handleVoiceCommand() {
    showDialog(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('🎤 COMMANDE VOCALE ACTIVÉE'),
        content: Text(
          'Exemples de commandes:\n• "Appeler Marie"\n• "Appeler mon médecin"\n• "Envoyer message à Jean"',
        ),
        actions: [TextButton(onPressed: null, child: Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Mes contacts', showBackButton: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Caregiver Link / Code
            if (_loadingCaregiver)
              const Padding(
                padding: EdgeInsets.only(bottom: 24.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_caregiver != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: InfoCard(
                  icon: FontAwesomeIcons.userNurse,
                  title:
                      '${_caregiver!['firstName'] ?? 'Mon'} ${_caregiver!['lastName'] ?? 'Aidant'}',
                  subtitle: _caregiver!['online'] == true
                      ? 'En ligne'
                      : (_caregiver!['lastActiveAt'] != null
                            ? _formatLastSeen(_caregiver!['lastActiveAt'])
                            : 'Hors ligne'),
                  gradientColors: [Colors.green[500]!, Colors.green[600]!],
                  onTap: () {
                    // Show details dialog
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(
                          '${_caregiver!['firstName'] ?? ''} ${_caregiver!['lastName'] ?? ''}',
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_caregiver!['phone'] != null)
                              Text('Tél: ${_caregiver!['phone']}'),
                            if (_caregiver!['email'] != null)
                              Text('Email: ${_caregiver!['email']}'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Fermer'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              )
            else if (_elderCode != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: InfoCard(
                  icon: FontAwesomeIcons.link,
                  title: 'Code de liaison: $_elderCode',
                  subtitle: 'Partagez ce code avec votre aidant',
                  gradientColors: [Colors.orange[500]!, Colors.orange[600]!],
                  onTap: () {},
                ),
              ),

            // Voice Command
            InfoCard(
      icon: FontAwesomeIcons.volumeHigh,
      title: 'Commande vocale',
      subtitle: 'Dites "Appeler [nom]"',
      gradientColors: [Colors.blue[500]!, Colors.blue[600]!],
      onTap: _handleVoiceCommand,
    ),

    const SizedBox(height: 24),

    if (_loadingContacts)
      const Center(child: CircularProgressIndicator())
    else if (_dynamicContacts.isEmpty)
      const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'Aucun contact enregistré par votre aidant.',
            style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
          ),
        ),
      )
    else
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                FontAwesomeIcons.addressBook,
                color: Colors.blue[500],
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Mes Contacts',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._dynamicContacts.map(
            (contactData) {
              final String? photoUrl = contactData['photoUrl'];
              final contact = Contact(
                id: contactData['_id'].hashCode,
                name: contactData['name'],
                relation: contactData['relation'],
                phone: contactData['phone'],
                photo: (photoUrl != null && photoUrl.isNotEmpty)
                    ? '${_apiService.baseUrl}$photoUrl'
                    : '👤',
                favorite: true,
              );
              return FavoriteContactCard(
                contact: contact,
                recordingVoice: _recordingVoice,
                onCall: () => _handleCall(contact),
                onVideoCall: () => _handleVideoCall(contact),
                onVoiceMessage: () => _handleVoiceMessage(contact),
              );
            },
          ),
        ],
      ),

    const SizedBox(height: 24),

    // Emergency Numbers
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red[500]!, Colors.red[600]!],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Numéros d\'urgence',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      const EmergencyNumberCard(emoji: '🚑', text: 'SAMU 15'),
                      const EmergencyNumberCard(emoji: '🚓', text: 'Police 17'),
                      const EmergencyNumberCard(
                        emoji: '🚒',
                        text: 'Pompiers 18',
                      ),
                      const EmergencyNumberCard(
                        emoji: '🆘',
                        text: 'Urgences 112',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
