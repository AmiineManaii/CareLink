import 'package:care_link/utils/face_storage.dart';
import 'package:care_link/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../models/medication.dart';
import 'package:intl/intl.dart';
import 'package:care_link/services/medication_reminder_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:record/record.dart';

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

  final stt.SpeechToText _speech = stt.SpeechToText();
  final AudioRecorder _recorder = AudioRecorder();
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _fetchMedications();
    _initSpeech();
  }

  @override
  void dispose() {
    _recorder.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    await _speech.initialize();
    await _flutterTts.setLanguage("fr-FR");
  }

  void _showConfirmationDialog(Medication med) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MedicationConfirmationDialog(
        medicationName: med.name,
        onConfirm: (note, audioPath) => _confirmTake(med, note, audioPath),
      ),
    );
  }

  Future<void> _confirmTake(
    Medication med,
    String note,
    String? audioPath,
  ) async {
    setState(() => _isLoading = true);
    try {
      final elderId = InMemoryFaceStorage().getElderId();
      if (elderId == null) return;

      await ApiService().confirmMedicationTake(
        medicationId: med.id,
        elderId: elderId,
        note: note,
        audioFile: audioPath != null ? File(audioPath) : null,
      );

      // Transformation auto du texte en parole (TTS) si une note est présente
      if (note.trim().isNotEmpty) {
        await _flutterTts.speak(note);
      }

      setState(() {
        _takenMedications.add(med.id);
        _isLoading = false;
      });

      // Annuler la notification programmée car le médicament a été pris
      await MedicationReminderService.cancelMedication(med);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Prise confirmée !")));
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erreur : $e")));
    }
  }

  Future<void> _fetchMedications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final elderId = InMemoryFaceStorage().getElderId();
      if (elderId == null) throw Exception("ID Senior introuvable");

      // Récupérer les médicaments programmés
      final data = await ApiService().getMedications(elderId);
      final allMeds = data.map((json) => Medication.fromJson(json)).toList();

      // Récupérer l'historique des prises d'aujourd'hui
      final historyToday = await ApiService().getElderMedicationHistoryToday(
        elderId,
      );
      final takenTodayIds = historyToday
          .map(
            (log) =>
                log['medicationId']['_id']?.toString() ??
                log['medicationId']?.toString(),
          )
          .where((id) => id != null)
          .cast<String>()
          .toSet();

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
        _takenMedications.clear();
        _takenMedications.addAll(takenTodayIds);
        _isLoading = false;
      });

      // Programmer les notifications uniquement pour les médicaments NON pris
      final untakenMeds = todayMeds
          .where((m) => !takenTodayIds.contains(m.id))
          .toList();
      await MedicationReminderService.scheduleForMedications(untakenMeds);

      // Annuler explicitement les notifications pour les médicaments pris aujourd'hui
      for (var medId in takenTodayIds) {
        final med = allMeds.firstWhere(
          (m) => m.id == medId,
          orElse: () => allMeds.first,
        );
        await MedicationReminderService.cancelMedicationById(
          medId,
          med.times.length,
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Medication? _getNextMedication() {
    if (_medications.isEmpty) return null;

    final now = DateTime.now();
    final currentTimeStr = DateFormat('HH:mm').format(now);

    // Trouver le prochain médicament non pris
    for (var med in _medications) {
      if (!_takenMedications.contains(med.id)) {
        for (var time in med.times) {
          if (time.compareTo(currentTimeStr) > 0) {
            return med;
          }
        }
      }
    }

    // Si aucun médicament n'est prévu plus tard, chercher le premier non pris de la journée
    try {
      return _medications.firstWhere(
        (med) => !_takenMedications.contains(med.id),
      );
    } catch (e) {
      // Tous les médicaments sont pris
      return null;
    }
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
                    const Text(
                      'Prochain médicament',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (nextMed != null)
                      _buildNextMedicationCard(nextMed)
                    else
                      _buildNoMoreMedicationsCard(),
                    const SizedBox(height: 36),
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
                            '${med.photoUrl}',
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
        ],
      ),
    );
  }

  Widget _buildNoMoreMedicationsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[50]!, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.green[200]!, width: 2),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline, size: 60, color: Colors.green[600]),
          const SizedBox(height: 16),
          const Text(
            'Bravo !',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tous vos médicaments pour aujourd’hui ont été pris.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
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
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Photo du médicament
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isTaken ? Colors.green[100]! : Colors.purple[100]!,
                    width: 2,
                  ),
                  image: med.photoUrl != null
                      ? DecorationImage(
                          image: NetworkImage(
                            '${med.photoUrl}',
                          ),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: med.photoUrl == null
                    ? Icon(
                        FontAwesomeIcons.pills,
                        size: 24,
                        color: isTaken ? Colors.green[600] : Colors.purple[600],
                      )
                    : null,
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
              // Bouton d'action (Prendre ou Déjà pris)
              GestureDetector(
                onTap: () {
                  if (!isTaken) {
                    _showConfirmationDialog(med);
                  }
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isTaken ? Colors.green[600] : Colors.blue[600],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isTaken ? Colors.green : Colors.blue)
                            .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    isTaken
                        ? FontAwesomeIcons.check
                        : FontAwesomeIcons.handHoldingMedical,
                    color: Colors.white,
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

class MedicationConfirmationDialog extends StatefulWidget {
  final String medicationName;
  final Function(String note, String? audioPath) onConfirm;

  const MedicationConfirmationDialog({
    super.key,
    required this.medicationName,
    required this.onConfirm,
  });

  @override
  State<MedicationConfirmationDialog> createState() =>
      _MedicationConfirmationDialogState();
}

class _MedicationConfirmationDialogState
    extends State<MedicationConfirmationDialog> {
  final TextEditingController _textController = TextEditingController();
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _audioPath;

  @override
  void dispose() {
    _textController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(
        "Confirmer : ${widget.medicationName}",
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Voulez-vous ajouter un message écrit ou vocal ?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _textController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Écrivez votre message ici...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
            const SizedBox(height: 20),
            Column(
              children: [
                IconButton(
                  iconSize: 56,
                  icon: Icon(
                    _isRecording ? Icons.stop_circle : Icons.mic,
                    color: _isRecording ? Colors.red : Colors.purple[700],
                  ),
                  onPressed: () async {
                    if (!_isRecording) {
                      if (await _recorder.hasPermission()) {
                        final dir = await getTemporaryDirectory();
                        final path =
                            '${dir.path}/med_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
                        await _recorder.start(const RecordConfig(), path: path);
                        setState(() {
                          _isRecording = true;
                          _audioPath = path;
                        });
                      }
                    } else {
                      await _recorder.stop();
                      setState(() => _isRecording = false);
                    }
                  },
                ),
                Text(
                  _isRecording ? "Arrêter" : "Enregistrer une voix",
                  style: TextStyle(
                    color: _isRecording ? Colors.red : Colors.grey[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("ANNULER"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            final note = _textController.text;
            Navigator.pop(context);
            widget.onConfirm(note, _audioPath);
          },
          child: const Text("CONFIRMER"),
        ),
      ],
    );
  }
}
