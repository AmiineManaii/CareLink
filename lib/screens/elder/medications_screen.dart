// ignore_for_file: deprecated_member_use

import 'package:care_link/features/face_auth/face_storage.dart';
import 'package:care_link/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../widgets/custom_app_bar.dart';
import '../../models/medication.dart';
import '../../widgets/medication_reminder_card.dart';
import 'package:intl/intl.dart';
import 'package:care_link/services/medication_reminder_service.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  List<Medication> _medications = [];
  bool _isLoading = true;
  String? _error;

  // Local state to track taken meds for the current session (since we lack a full backend log)
  final Set<String> _takenMedications = {};

  @override
  void initState() {
    super.initState();
    _fetchMedications();
  }

  Future<void> _fetchMedications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final elderId = InMemoryFaceStorage().getElderId();
      if (elderId == null) {
        throw Exception("ID Senior introuvable");
      }

      final data = await ApiService().getMedications(elderId);
      final allMeds = data.map((json) => Medication.fromJson(json)).toList();

      // Filter for active medications today
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final todayMeds = allMeds.where((med) {
        if (!med.active) return false;

        // Use only date parts for comparison
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

        // If frequency is weekly, check if today is one of the days
        if (med.frequency == 'Hebdomadaire' && med.days.isNotEmpty) {
          if (!med.days.contains(now.weekday)) return false;
        }

        return true;
      }).toList();

      // Sort by first time of day
      todayMeds.sort((a, b) {
        if (a.times.isEmpty) return 1;
        if (b.times.isEmpty) return -1;
        return a.times.first.compareTo(b.times.first);
      });

      setState(() {
        _medications = todayMeds;
        _isLoading = false;
      });

      // Schedule reminders for fetched medications
      await MedicationReminderService.scheduleForMedications(todayMeds);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _toggleMedication(String id) {
    setState(() {
      if (_takenMedications.contains(id)) {
        _takenMedications.remove(id);
      } else {
        _takenMedications.add(id);
      }
    });
  }

  void _speakMedication(Medication med) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔊 LECTURE VOCALE'),
        content: Text(
          '"${med.name}, ${med.dosage}\nÀ prendre à ${med.times.join(", ")}\n${med.frequency}"',
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

  Medication? _getNextMedication() {
    if (_medications.isEmpty) return null;

    final now = DateTime.now();
    final currentTimeStr = DateFormat('HH:mm').format(now);

    for (var med in _medications) {
      for (var time in med.times) {
        if (time.compareTo(currentTimeStr) > 0) {
          return med;
        }
      }
    }
    // If all passed, return first one (maybe it's the next day's first)
    return _medications.first;
  }

  String _getNextTime(Medication med) {
    final now = DateTime.now();
    final currentTimeStr = DateFormat('HH:mm').format(now);

    for (var time in med.times) {
      if (time.compareTo(currentTimeStr) > 0) {
        return time;
      }
    }
    return med.times.isNotEmpty ? med.times.first : '--:--';
  }

  @override
  Widget build(BuildContext context) {
    final nextMed = _getNextMedication();

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Mes médicaments',
        showBackButton: true,
        // No actions (Add button removed for Elder)
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Erreur: $_error'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Upcoming Reminder
                  if (nextMed != null)
                    MedicationReminderCard(
                      time: _getNextTime(nextMed),
                      medicationName: nextMed.name,
                      dosage: nextMed.dosage,
                      onListen: () => _speakMedication(nextMed),
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
                  if (_medications.isEmpty)
                    const Center(
                      child: Text("Aucun médicament pour aujourd'hui"),
                    ),
                  ..._medications.map((med) => _buildMedicationCard(med)),

                  const SizedBox(height: 24),
                  // ... (Weekly overview kept as static/mock for now as it requires complex logic)
                ],
              ),
            ),
    );
  }

  Widget _buildMedicationCard(Medication med) {
    final isTaken = _takenMedications.contains(med.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isTaken ? Colors.green[200]! : Colors.grey[200]!,
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
                    color: isTaken ? Colors.green[500] : Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isTaken ? FontAwesomeIcons.check : FontAwesomeIcons.xmark,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              if (med.photoUrl != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: NetworkImage(
                          '${ApiService().baseUrl}${med.photoUrl}',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
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
                        Expanded(
                          child: Text(
                            med.times.join(", "),
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[500],
                            ),
                            overflow: TextOverflow.ellipsis,
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
        ],
      ),
    );
  }
}
