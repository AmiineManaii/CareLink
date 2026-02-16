import 'package:flutter/material.dart';
import 'package:care_link/features/face_auth/face_storage.dart';
import 'package:care_link/services/api_service.dart';

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
      appBar: AppBar(
        title: const Text('Alertes'),
      ),
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
                    itemCount: _alerts.length,
                    itemBuilder: (context, index) {
                      final alert = _alerts[index];
                      final read = alert['read'] == true;
                      final createdAt = alert['createdAt'] as String?;
                      DateTime? dt;
                      if (createdAt != null) {
                        dt = DateTime.tryParse(createdAt)?.toLocal();
                      }
                      final subtitle = [
                        if (alert['message'] != null) alert['message'],
                        if (dt != null)
                          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                      ].join(' • ');

                      return Card(
                        margin:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: Icon(
                            Icons.warning_amber_rounded,
                            color: read ? Colors.grey : Colors.red,
                          ),
                          title: const Text('Alerte SOS'),
                          subtitle: Text(subtitle),
                          trailing: read
                              ? const Icon(Icons.check, color: Colors.green)
                              : TextButton(
                                  onPressed: () => _markAsRead(alert['_id']),
                                  child: const Text('Marquer lu'),
                                ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

