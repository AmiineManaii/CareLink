// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../widgets/custom_app_bar.dart';
import '../models/medication.dart';
import '../widgets/medication_reminder_card.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  List<Medication> _medications = [
    Medication(
      id: 1,
      name: 'Aspirine',
      dosage: '100mg',
      time: '08:00',
      taken: true,
      frequency: 'Matin',
    ),
    Medication(
      id: 2,
      name: 'Doliprane',
      dosage: '1000mg',
      time: '14:00',
      taken: true,
      frequency: 'Après-midi',
    ),
    Medication(
      id: 3,
      name: 'Vitamine D',
      dosage: '1 comprimé',
      time: '20:00',
      taken: false,
      frequency: 'Soir',
    ),
    Medication(
      id: 4,
      name: 'Oméprazole',
      dosage: '20mg',
      time: '08:00',
      taken: true,
      frequency: 'Matin',
    ),
  ];

  bool _showAddForm = false;

  void _toggleMedication(int id) {
    setState(() {
      _medications = _medications.map((med) {
        if (med.id == id) {
          return Medication(
            id: med.id,
            name: med.name,
            dosage: med.dosage,
            time: med.time,
            taken: !med.taken,
            frequency: med.frequency,
          );
        }
        return med;
      }).toList();
    });
  }

  void _speakMedication(Medication med) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔊 LECTURE VOCALE'),
        content: Text(
          '"${med.name}, ${med.dosage}\nÀ prendre à ${med.time}\n${med.frequency}"',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Mes médicaments',
        showBackButton: true,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _showAddForm = !_showAddForm;
              });
            },
            icon: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue[600],
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                FontAwesomeIcons.plus,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upcoming Reminder
            MedicationReminderCard(
              time: '20:00',
              medicationName: 'Vitamine D',
              dosage: '1 comprimé',
              onListen: () {},
            ),

            const SizedBox(height: 24),

            // Today's Medications
            Text(
              'Aujourd\'hui',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            ..._medications.map((med) => _buildMedicationCard(med)),

            const SizedBox(height: 24),

            // Weekly Overview
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
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
                    'Cette semaine',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['L', 'M', 'M', 'J', 'V', 'S', 'D'].map((day) {
                      final index = [
                        'L',
                        'M',
                        'M',
                        'J',
                        'V',
                        'S',
                        'D',
                      ].indexOf(day);
                      return Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: index < 3
                              ? Colors.green[100]
                              : index == 3
                              ? Colors.blue[100]
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: index < 3
                                  ? Colors.green[600]
                                  : index == 3
                                  ? Colors.blue[600]
                                  : Colors.grey[400],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '12',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[600],
                                ),
                              ),
                              Text(
                                'Médicaments pris',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '2',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[600],
                                ),
                              ),
                              Text(
                                'Rappels manqués',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Settings
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
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
                    'Paramètres des rappels',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSettingItem('Notification sonore', true),
                  _buildSettingItem('Vibration', true),
                  _buildSettingItem('Lecture vocale auto', true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationCard(Medication med) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: med.taken ? Colors.green[200]! : Colors.grey[200]!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
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
              // Status Button
              InkWell(
                onTap: () => _toggleMedication(med.id),
                borderRadius: BorderRadius.circular(32),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: med.taken ? Colors.green[500] : Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    med.taken ? FontAwesomeIcons.check : FontAwesomeIcons.xmark,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Medication Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      med.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      med.dosage,
                      style: const TextStyle(fontSize: 20, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          FontAwesomeIcons.clock,
                          size: 16,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          med.time,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '• ${med.frequency}',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Voice Button
              InkWell(
                onTap: () => _speakMedication(med),
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    FontAwesomeIcons.volumeHigh,
                    color: Colors.blue[600],
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          if (!med.taken) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _toggleMedication(med.id),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[500],
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Marquer comme pris',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingItem(String label, bool value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 18, color: Colors.grey[700])),
          Switch(value: value, onChanged: (_) {}),
        ],
      ),
    );
  }
}
