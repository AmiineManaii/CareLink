// ignore_for_file: deprecated_member_use

import 'package:care_link/features/face_auth/face_storage.dart';
import 'package:care_link/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../widgets/custom_app_bar.dart';
import '../../models/medication.dart';
import 'package:intl/intl.dart';
import 'package:care_link/services/medication_reminder_service.dart';

// ==================== MEDICATION REMINDER CARD (NOUVEAU DESIGN) ====================
class MedicationReminderCard extends StatelessWidget {
  final String time;
  final String medicationName;
  final String dosage;
  final VoidCallback onListen;

  const MedicationReminderCard({
    super.key,
    required this.time,
    required this.medicationName,
    required this.dosage,
    required this.onListen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[50]!, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.blue[200]!, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Heure principale
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.access_time_rounded, size: 46, color: Colors.blue[700]),
              const SizedBox(width: 16),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 58,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Icône pilule + Nom + Dosage
          Row(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue[100]!, width: 7),
                  boxShadow: [
                    BoxShadow(color: Colors.blue.withOpacity(0.25), blurRadius: 15),
                  ],
                ),
                child: Icon(
                  Icons.medical_services_rounded,
                  size: 58,
                  color: Colors.blue[700],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicationName,
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dosage,
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Bouton Écouter
          GestureDetector(
            onTap: onListen,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 36),
              decoration: BoxDecoration(
                color: Colors.blue[700],
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    FontAwesomeIcons.volumeHigh,
                    color: Colors.white,
                    size: 30,
                  ),
                  SizedBox(width: 16),
                  Flexible(                    // ← Important
          child: Text(
            'ÉCOUTER LES INSTRUCTIONS',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 2,                    // 1 ligne
            overflow: TextOverflow.ellipsis, // texte trop long → ...
            softWrap: false,
          ),
        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ====================== MAIN SCREEN ======================
class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  List<Medication> _medications = [];
  bool _isLoading = true;
  String? _error;

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
      if (elderId == null) throw Exception("ID Senior introuvable");

      final data = await ApiService().getMedications(elderId);
      final allMeds = data.map((json) => Medication.fromJson(json)).toList();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final todayMeds = allMeds.where((med) {
        if (!med.active) return false;

        final start = DateTime(med.startDate.year, med.startDate.month, med.startDate.day);
        if (start.isAfter(today)) return false;

        if (med.endDate != null) {
          final end = DateTime(med.endDate!.year, med.endDate!.month, med.endDate!.day);
          if (end.isBefore(today)) return false;
        }

        if (med.frequency == 'Hebdomadaire' && med.days.isNotEmpty) {
          if (!med.days.contains(now.weekday)) return false;
        }

        return true;
      }).toList();

      todayMeds.sort((a, b) {
        if (a.times.isEmpty) return 1;
        if (b.times.isEmpty) return -1;
        return a.times.first.compareTo(b.times.first);
      });

      setState(() {
        _medications = todayMeds;
        _isLoading = false;
      });

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('🔊 Lecture vocale', style: TextStyle(fontSize: 24)),
        content: Text(
          '"${med.name}, ${med.dosage}\nÀ prendre à ${med.times.join(", ")}\n${med.frequency}"',
          style: const TextStyle(fontSize: 20, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', style: TextStyle(fontSize: 20)),
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
    return _medications.first;
  }

  String _getNextTime(Medication med) {
    final now = DateTime.now();
    final currentTimeStr = DateFormat('HH:mm').format(now);

    for (var time in med.times) {
      if (time.compareTo(currentTimeStr) > 0) return time;
    }
    return med.times.isNotEmpty ? med.times.first : '--:--';
  }

  @override
  Widget build(BuildContext context) {
    final nextMed = _getNextMedication();

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Mes Médicaments',
        showBackButton: true,
      ),
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 6))
          : _error != null
              ? Center(
                  child: Text(
                    'Erreur: $_error',
                    style: const TextStyle(fontSize: 18, color: Colors.red),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchMedications,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Prochain médicament
                        if (nextMed != null) ...[
                          const Text(
                            'Prochain médicament',
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey,
                            ),
                          ),
                          const SizedBox(height: 14),
                          MedicationReminderCard(
                            time: _getNextTime(nextMed),
                            medicationName: nextMed.name,
                            dosage: nextMed.dosage,
                            onListen: () => _speakMedication(nextMed),
                          ),
                          const SizedBox(height: 36),
                        ],

                        // Médicaments du jour
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Aujourd’hui',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${_medications.length} médicament${_medications.length > 1 ? 's' : ''}',
                              style: TextStyle(fontSize: 19, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        if (_medications.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 80),
                              child: Column(
                                children: [
                                  Icon(Icons.medical_services_outlined,
                                      size: 130, color: Colors.grey[300]),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Aucun médicament prévu aujourd’hui',
                                    style: TextStyle(fontSize: 24, color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ..._medications.map((med) => _buildMedicationCard(med)),
                      ],
                    ),
                  ),
                ),
    );
  }

  // ====================== CARTE MÉDICAMENT ======================
  Widget _buildMedicationCard(Medication med) {
    final bool isTaken = _takenMedications.contains(med.id);
    final Color cardColor = isTaken ? Colors.green[50]! : Colors.white;
    final Color borderColor = isTaken ? Colors.green[300]! : Colors.grey[200]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: isTaken
                ? Colors.green.withOpacity(0.15)
                : Colors.grey.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bouton "Pris / Non pris"
            GestureDetector(
              onTap: () => _toggleMedication(med.id),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: isTaken ? Colors.green[600] : Colors.grey[200],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 5),
                ),
                child: Icon(
                  isTaken ? FontAwesomeIcons.check : FontAwesomeIcons.clock,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ),

            const SizedBox(width: 20),

            // Informations
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    med.name,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: isTaken ? Colors.green[900] : Colors.black87,
                      decoration: isTaken ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    med.dosage,
                    style: TextStyle(
                      fontSize: 21,
                      color: isTaken ? Colors.green[700] : Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 28, color: Colors.blueGrey),
                      const SizedBox(width: 12),
                      Text(
                        med.times.join(" • "),
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                          color: isTaken ? Colors.green[700] : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Bouton écoute
            GestureDetector(
              onTap: () => _speakMedication(med),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  FontAwesomeIcons.volumeHigh,
                  color: Colors.blue[700],
                  size: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}