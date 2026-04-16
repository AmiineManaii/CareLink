import 'package:care_link/models/medication.dart';
import 'package:care_link/screens/caregiver/medications/add_medication_screen.dart';
import 'package:care_link/screens/caregiver/medications/caregiver_medication_history_screen.dart';
import 'package:care_link/features/face_auth/face_storage.dart';
import 'package:care_link/services/api_service.dart';
import 'package:care_link/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

class CaregiverMedicationsScreen extends StatefulWidget {
  final String elderId;
  final String elderName;

  const CaregiverMedicationsScreen({
    super.key,
    required this.elderId,
    required this.elderName,
  });

  @override
  State<CaregiverMedicationsScreen> createState() =>
      _CaregiverMedicationsScreenState();
}

class _CaregiverMedicationsScreenState
    extends State<CaregiverMedicationsScreen> {
  List<Medication> _medications = [];
  bool _isLoading = true;
  String? _error;

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
      final data = await ApiService().getMedications(widget.elderId);
      final meds = data.map((json) => Medication.fromJson(json)).toList();

      // Trier : actifs d'abord, puis par nom
      meds.sort((a, b) {
        if (a.active && !b.active) return -1;
        if (!a.active && b.active) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      setState(() {
        _medications = meds;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteMedication(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Confirmer la suppression'),
        content:
            const Text('Êtes-vous sûr de vouloir supprimer ce médicament ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService().deleteMedication(id);
        _fetchMedications();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Médicament supprimé'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Médicaments de ${widget.elderName}',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              final caregiverId = InMemoryFaceStorage().getCaregiverId();
              if (caregiverId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CaregiverMedicationHistoryScreen(
                      caregiverId: caregiverId,
                    ),
                  ),
                );
              }
            },
            tooltip: 'Historique des prises',
          ),
        ],
      ),
      backgroundColor: Colors.grey[50],
      floatingActionButton: FloatingActionButton.large(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddMedicationScreen(elderId: widget.elderId),
            ),
          );
          if (result == true) {
            _fetchMedications();
          }
        },
        backgroundColor: Colors.purple[600],
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: const Icon(Icons.add_rounded, size: 48, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: RefreshIndicator(
        onRefresh: _fetchMedications,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 5))
            : _error != null
                ? _buildErrorWidget()
                : _medications.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: _medications.length,
                        itemBuilder: (context, index) {
                          final med = _medications[index];
                          return _buildMedicationCard(med);
                        },
                      ),
      ),
    );
  }

  Widget _buildMedicationCard(Medication med) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      shadowColor: Colors.purple.withOpacity(0.15),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image or Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(18),
                    image: med.photoUrl != null
                        ? DecorationImage(
                            image: NetworkImage('${ApiService().baseUrl}${med.photoUrl}'),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: med.photoUrl == null
                      ? Icon(FontAwesomeIcons.pills, color: Colors.purple[600], size: 36)
                      : null,
                ),
                const SizedBox(width: 16),
                // Name and Dosage
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        med.dosage,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Active Status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: med.active ? Colors.green[100] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    med.active ? 'Actif' : 'Inactif',
                    style: TextStyle(
                      color: med.active ? Colors.green[800] : Colors.grey[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            // Schedule Info
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildInfoChip(
                  icon: Icons.repeat,
                  text: med.frequency,
                  color: Colors.blue,
                ),
                _buildInfoChip(
                  icon: Icons.access_time_filled,
                  text: med.times.join(', '),
                  color: Colors.orange,
                ),
              ],
            ),
            if (med.instructions != null) ...[
              const SizedBox(height: 16),
              Text(
                'Instructions:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800]),
              ),
              const SizedBox(height: 4),
              Text(
                med.instructions ?? '',
                style: TextStyle(color: Colors.grey[600], fontSize: 15, height: 1.4),
              ),
            ],
            const SizedBox(height: 20),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddMedicationScreen(
                            medication: med,
                            elderId: widget.elderId,
                          ),
                        ),
                      );
                      if (result == true) {
                        _fetchMedications();
                      }
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Modifier'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _deleteMedication(med.id),
                    icon: const Icon(Icons.delete_forever, size: 18),
                    label: const Text('Supprimer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color.withOpacity(0.9),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FontAwesomeIcons.pills, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 24),
          Text(
            'Aucun médicament ajouté',
            style: TextStyle(fontSize: 22, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Appuyez sur + pour commencer',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.red),
          const SizedBox(height: 16),
          Text('Erreur: $_error', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchMedications,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
