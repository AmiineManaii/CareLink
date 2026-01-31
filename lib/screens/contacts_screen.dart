import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/info_card.dart';
import '../models/contact.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Contact> contacts = [
    Contact(
      id: 1,
      name: 'Marie Dupont',
      relation: 'Fille',
      phone: '06 12 34 56 78',
      photo: '👩',
      favorite: true,
    ),
    Contact(
      id: 2,
      name: 'Dr. Martin',
      relation: 'Médecin',
      phone: '01 23 45 67 89',
      photo: '👨‍⚕️',
      favorite: true,
    ),
    Contact(
      id: 3,
      name: 'Jean Dupont',
      relation: 'Fils',
      phone: '06 98 76 54 32',
      photo: '👨',
      favorite: true,
    ),
    Contact(
      id: 4,
      name: 'Sophie Bernard',
      relation: 'Amie',
      phone: '06 11 22 33 44',
      photo: '👩',
      favorite: false,
    ),
    Contact(
      id: 5,
      name: 'Pharmacie Centrale',
      relation: 'Pharmacie',
      phone: '01 44 55 66 77',
      photo: '💊',
      favorite: true,
    ),
    Contact(
      id: 6,
      name: 'Pierre Moreau',
      relation: 'Voisin',
      phone: '06 55 44 33 22',
      photo: '👴',
      favorite: false,
    ),
  ];

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

  List<Contact> get favorites => contacts.where((c) => c.favorite).toList();
  List<Contact> get otherContacts =>
      contacts.where((c) => !c.favorite).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Mes contacts', showBackButton: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Voice Command
            InfoCard(
              icon: FontAwesomeIcons.volumeHigh,
              title: 'Commande vocale',
              subtitle: 'Dites "Appeler [nom]"',
              gradientColors: [Colors.blue[500]!, Colors.blue[600]!],
              onTap: _handleVoiceCommand,
            ),

            const SizedBox(height: 24),

            // Emergency Contacts
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      FontAwesomeIcons.heart,
                      color: Colors.red[500],
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Contacts favoris',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...favorites
                    .map((contact) => _buildFavoriteContact(contact))
                    
              ],
            ),

            const SizedBox(height: 24),

            // Other Contacts
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      FontAwesomeIcons.user,
                      color: Colors.grey[500],
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Autres contacts',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...otherContacts
                    .map((contact) => _buildOtherContact(contact))
                   
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
                      _buildEmergencyNumber('🚑', 'SAMU 15'),
                      _buildEmergencyNumber('🚓', 'Police 17'),
                      _buildEmergencyNumber('🚒', 'Pompiers 18'),
                      _buildEmergencyNumber('🆘', 'Urgences 112'),
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

  Widget _buildFavoriteContact(Contact contact) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    contact.photo,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      contact.relation,
                      style: const TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    Text(
                      contact.phone,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.blue[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleCall(contact),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[500],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(FontAwesomeIcons.phone),
                  label: const Text('Appeler'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleVideoCall(contact),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[500],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(FontAwesomeIcons.video),
                  label: const Text('Vidéo'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleVoiceMessage(contact),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _recordingVoice
                        ? Colors.red[500]!
                        : Colors.purple[500]!,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(FontAwesomeIcons.volumeHigh),
                  label: Text(_recordingVoice ? '...' : 'Vocal'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOtherContact(Contact contact) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(contact.photo, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  contact.relation,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => _handleCall(contact),
            borderRadius: BorderRadius.circular(28),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.green[500],
                shape: BoxShape.circle,
              ),
              child: Icon(
                FontAwesomeIcons.phone,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyNumber(String emoji, String text) {
    return Container(
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
