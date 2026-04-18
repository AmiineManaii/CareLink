import 'package:flutter/material.dart';
import 'package:care_link/services/auth/face_storage.dart';
import 'package:care_link/services/api_service.dart';
import 'package:care_link/widgets/common/sos_mini_map.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CaregiverAlertsScreen extends StatefulWidget {
  const CaregiverAlertsScreen({super.key});

  @override
  State<CaregiverAlertsScreen> createState() => _CaregiverAlertsScreenState();
}

class _CaregiverAlertsScreenState extends State<CaregiverAlertsScreen> {
  bool _loading = false;
  List<dynamic> _alerts = [];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    final caregiverId = InMemoryFaceStorage().getCaregiverId();
    if (caregiverId == null) return;
    setState(() => _loading = true);
    try {
      final data = await ApiService().getCaregiverAlerts(caregiverId);
      if (mounted) {
        setState(() {
          _alerts = data;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement alertes: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _markAsRead(String alertId) async {
    try {
      await ApiService().markAlertAsRead(alertId);
      if (mounted) {
        setState(() {
          _alerts = _alerts.map((a) {
            if (a['_id'] == alertId) {
              a['read'] = true;
            }
            return a;
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur mise à jour alerte: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alertes')),
      body: RefreshIndicator(
        onRefresh: _loadAlerts,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _alerts.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(child: Text('Aucune alerte pour le moment')),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _alerts.length,
                itemBuilder: (context, index) {
                  final alert = _alerts[index];
                  final read = alert['read'] == true;
                  final date = DateTime.parse(alert['createdAt']).toLocal();
                  final dateStr = DateFormat('dd/MM/yyyy').format(date);
                  final timeStr = DateFormat('HH:mm').format(date);
                  final latStr = alert['latitude'] ?? 'N/A';
                  final lonStr = alert['longitude'] ?? 'N/A';

                  double? lat = double.tryParse(latStr.toString());
                  double? lon = double.tryParse(lonStr.toString());

                  bool hasValidLocation =
                      lat != null && lon != null && lat != 0 && lon != 0;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    FontAwesomeIcons.triangleExclamation,
                                    color: read ? Colors.grey : Colors.red,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'SOS Déclenché',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: read
                                          ? Colors.grey[700]
                                          : Colors.red[700],
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                timeStr,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Date: $dateStr',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 18,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Latitude: $latStr',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    Text(
                                      'Longitude: $lonStr',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (hasValidLocation) ...[
                            const SizedBox(height: 16),
                            SosMiniMap(latitude: lat, longitude: lon),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: read
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Alerte traitée',
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  )
                                : ElevatedButton.icon(
                                    onPressed: () => _markAsRead(alert['_id']),
                                    icon: const Icon(Icons.check),
                                    label: const Text('Marquer comme lu'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red[700],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
