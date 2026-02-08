// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../widgets/stat_card.dart';

class FamilyDashboardScreen extends StatelessWidget {
  final VoidCallback onBack;

  const FamilyDashboardScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final senior = {'name': 'Marie Dubois', 'age': 78, 'photo': '👵'};

    final activities = [
      {
        'type': 'medication',
        'text': 'Médicament pris: Aspirine',
        'time': '14:00',
        'status': 'success',
      },
      {
        'type': 'call',
        'text': 'Appel reçu de Jean Dupont',
        'time': '12:30',
        'status': 'success',
      },
      {
        'type': 'alert',
        'text': 'Rappel médicament manqué',
        'time': '11:00',
        'status': 'warning',
      },
      {
        'type': 'location',
        'text': 'Sortie détectée',
        'time': '09:15',
        'status': 'info',
      },
      {
        'type': 'medication',
        'text': 'Médicament pris: Doliprane',
        'time': '08:00',
        'status': 'success',
      },
    ];

    final medications = [
      {'name': 'Aspirine', 'time': '08:00', 'taken': true},
      {'name': 'Doliprane', 'time': '14:00', 'taken': true},
      {'name': 'Vitamine D', 'time': '20:00', 'taken': false},
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue[600],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(FontAwesomeIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tableau de bord familial',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Senior Info Header
            Container(
              padding: const EdgeInsets.all(24),
              color: Colors.blue[600],
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        senior['photo'] as String,
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        senior['name'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${senior['age']} ans • Suivi actif',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Quick Stats
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          icon: FontAwesomeIcons.circleCheck,
                          iconColor: Colors.green[500]!,
                          title: 'Aujourd\'hui',
                          value: '2/3',
                          valueColor: Colors.green[600]!,
                          subtitle: 'Médicaments pris',
                          borderColor: Colors.green[200]!,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          icon: FontAwesomeIcons.chartLine,
                          iconColor: Colors.blue[500]!,
                          title: 'Statut',
                          value: '✓',
                          valueColor: Colors.blue[600]!,
                          subtitle: 'Tout va bien',
                          borderColor: Colors.blue[200]!,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Quick Actions
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
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
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[500],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(FontAwesomeIcons.locationDot),
                          label: const Text('Position'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[500],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(FontAwesomeIcons.bell),
                          label: const Text('Rappeler'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Medications Today
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              FontAwesomeIcons.bell,
                              color: Colors.purple[500],
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Médicaments du jour',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...medications
                            .map(
                              (med) => _buildMedicationItem(
                                name: med['name']! as String,
                                time: med['time']! as String,
                                taken: med['taken'] as bool,
                              ),
                            )
                           
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Recent Activity
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              FontAwesomeIcons.chartLine,
                              color: Colors.blue[500],
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Activité récente',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...activities
                            .map(
                              (activity) => _buildActivityItem(
                                type: activity['type']!,
                                text: activity['text']!,
                                time: activity['time']!,
                                status: activity['status']!,
                              ),
                            )
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Alerts
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange[500]!, Colors.orange[600]!],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              FontAwesomeIcons.triangleExclamation,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Alertes importantes',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Rappel médicament manqué',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Vitamine D non pris à 20:00',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Weekly Summary
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Résumé de la semaine',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
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
                            _buildSummaryItem(
                              '95%',
                              'Médicaments pris',
                              Colors.green,
                            ),
                            _buildSummaryItem(
                              '12',
                              'Appels passés',
                              Colors.blue,
                            ),
                            _buildSummaryItem(
                              '2',
                              'Alertes SOS',
                              Colors.purple,
                            ),
                            _buildSummaryItem(
                              '3',
                              'Rappels manqués',
                              Colors.orange,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Emergency Contacts
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              FontAwesomeIcons.user,
                              color: Colors.grey[600],
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Contacts d\'urgence configurés',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildContactItem(
                          'Jean Dupont (Fils)',
                          '06 98 76 54 32',
                        ),
                        const SizedBox(height: 8),
                        _buildContactItem('Dr. Martin', '01 23 45 67 89'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Settings Button
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Configurer les paramètres de suivi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationItem({
    required String name,
    required String time,
    required bool taken,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: taken ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            taken ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.clock,
            color: taken ? Colors.green[500] : Colors.orange[500],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                Text(time, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: taken ? Colors.green[100] : Colors.orange[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              taken ? 'Pris' : 'En attente',
              style: TextStyle(
                color: taken ? Colors.green[700] : Colors.orange[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required String type,
    required String text,
    required String time,
    required String status,
  }) {
    IconData icon;
    Color color;

    switch (type) {
      case 'medication':
        icon = FontAwesomeIcons.circleCheck;
        color = status == 'success' ? Colors.green[600]! : Colors.orange[600]!;
        break;
      case 'call':
        icon = FontAwesomeIcons.phone;
        color = Colors.blue[600]!;
        break;
      case 'alert':
        icon = FontAwesomeIcons.triangleExclamation;
        color = Colors.orange[600]!;
        break;
      case 'location':
        icon = FontAwesomeIcons.locationDot;
        color = Colors.blue[600]!;
        break;
      default:
        icon = FontAwesomeIcons.circleInfo;
        color = Colors.grey[600]!;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                Text(time, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildContactItem(String name, String phone) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          Text(phone, style: TextStyle(color: Colors.blue[600], fontSize: 14)),
        ],
      ),
    );
  }
}
