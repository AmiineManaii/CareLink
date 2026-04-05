import 'package:care_link/features/face_auth/face_storage.dart';
import 'package:care_link/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../widgets/custom_app_bar.dart';
import '../../models/medication.dart';
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
    final textToSpeak =
        "Il est l'heure de prendre ${med.name}, ${med.dosage}. ${med.instructions}";
    // TTS logic here
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lecture vocale'),
        content: Text(textToSpeak),
      ),
    );
  }

  Medication? _getNextMedication() {
    if (_medications.isEmpty) return null;

    final now = DateTime.now();
    final currentTimeStr = DateFormat('HH:mm').format(now);

    for (var med in _medications) {
      for (var time in med.times) {
        if (time.compareTo(currentTimeStr) > 0 &&
            !_takenMedications.contains(med.id)) {
          return med;
        }
      }
    }
    // Fallback to the first untaken medication of the day
    return _medications.firstWhere(
      (med) => !_takenMedications.contains(med.id),
      orElse: () => _medications.first,
    );
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
          ? Center(child: Text('Erreur: $_error'))
          : RefreshIndicator(
              onRefresh: _fetchMedications,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (nextMed != null) ...[
                      const Text(
                        'Prochain médicament',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildNextMedicationCard(nextMed),
                      const SizedBox(height: 36),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Aujourd’hui',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_medications.length} total',
                          style: TextStyle(
                            fontSize: 19,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (_medications.isEmpty)
                      _buildEmptyState()
                    else
                      ..._medications.map((med) => _buildMedicationCard(med)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildNextMedicationCard(Medication med) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[50]!, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.purple[200]!, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.alarm, size: 40, color: Colors.purple[700]),
              const SizedBox(width: 16),
              Text(
                _getNextTime(med),
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.purple[100]!, width: 4),
                  image: med.photoUrl != null
                      ? DecorationImage(
                          image: NetworkImage(
                            '${ApiService().baseUrl}${med.photoUrl}',
                          ),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: med.photoUrl == null
                    ? Icon(
                        FontAwesomeIcons.pills,
                        size: 36,
                        color: Colors.purple[600],
                      )
                    : null,
              ),
              const SizedBox(width: 20),
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
                    const SizedBox(height: 6),
                    Text(
                      med.dosage,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _speakMedication(med),
            icon: const Icon(
              FontAwesomeIcons.volumeHigh,
              color: Colors.white,
              size: 22,
            ),
            label: const Text(
              'ÉCOUTER',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[600],
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(Medication med) {
    final bool isTaken = _takenMedications.contains(med.id);
    return Opacity(
      opacity: isTaken ? 0.6 : 1.0,
      child: Card(
        margin: const EdgeInsets.only(bottom: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: isTaken ? 2 : 8,
        shadowColor: isTaken
            ? Colors.grey.withOpacity(0.1)
            : Colors.purple.withOpacity(0.15),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _toggleMedication(med.id),
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: isTaken ? Colors.green[600] : Colors.grey[200],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Icon(
                    isTaken ? FontAwesomeIcons.check : FontAwesomeIcons.clock,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      med.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isTaken ? Colors.grey[700] : Colors.black87,
                        decoration: isTaken ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          med.times.join(" • "),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isTaken ? Colors.grey[600] : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _speakMedication(med),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    FontAwesomeIcons.volumeHigh,
                    color: Colors.purple[700],
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          children: [
            Icon(FontAwesomeIcons.pills, size: 100, color: Colors.grey[300]),
            const SizedBox(height: 24),
            const Text(
              'Aucun médicament aujourd’hui',
              style: TextStyle(fontSize: 22, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
