import 'package:care_link/features/face_auth/face_storage.dart';
import 'package:care_link/models/medication.dart';
import 'package:care_link/screens/caregiver/medications/add_medication_screen.dart';
import 'package:care_link/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

class CaregiverMedicationsScreen extends StatefulWidget {
  const CaregiverMedicationsScreen({super.key});

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
      final elderId = InMemoryFaceStorage().getElderId();
      if (elderId == null) {
        throw Exception("Aucun senior lié");
      }

      final data = await ApiService().getMedications(elderId);
      final meds = data.map((json) => Medication.fromJson(json)).toList();

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
        title: const Text('Confirmer la suppression'),
        content: const Text(
            'Êtes-vous sûr de vouloir supprimer ce médicament ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService().deleteMedication(id);
        _fetchMedications(); // Refresh list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Médicament supprimé')),
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
      appBar: AppBar(
        title: const Text('Médicaments du senior'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddMedicationScreen(),
            ),
          );
          if (result == true) {
            _fetchMedications();
          }
        },
        label: const Text('Ajouter'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blue[600],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Erreur: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchMedications,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : _medications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(FontAwesomeIcons.pills,
                              size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun médicament ajouté',
                            style: TextStyle(
                                fontSize: 18, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _medications.length,
                      itemBuilder: (context, index) {
                        final med = _medications[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                                image: med.photoUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(
                                            '${ApiService().baseUrl}${med.photoUrl}'),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: med.photoUrl == null
                                  ? Icon(FontAwesomeIcons.pills,
                                      color: Colors.blue[600])
                                  : null,
                            ),
                            title: Text(
                              med.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('${med.dosage} • ${med.frequency}'),
                                Text(
                                  'Heures: ${med.times.join(", ")}',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                if (med.endDate != null)
                                  Text(
                                    'Jusqu\'au ${DateFormat('dd/MM/yyyy').format(med.endDate!)}',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.orange),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            AddMedicationScreen(medication: med),
                                      ),
                                    );
                                    if (result == true) {
                                      _fetchMedications();
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red),
                                  onPressed: () => _deleteMedication(med.id),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
    );
  }
}
