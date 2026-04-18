import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:care_link/services/api_service.dart';
import 'package:care_link/services/auth/face_storage.dart';
import 'package:care_link/services/medication_reminder_service.dart';
import 'package:care_link/models/medication.dart';

class HomeService {
  final ApiService _apiService = ApiService();

  Future<void> scheduleDailyTasks() async {
    try {
      final elderId = InMemoryFaceStorage().getElderId();
      if (elderId == null) return;

      final tasks = await _apiService.getElderTasks(
        elderId,
        date: DateTime.now(),
      );

      for (var task in tasks) {
        if (task['reminderEnabled'] != true || task['isCompleted'] == true) {
          continue;
        }

        final taskTime = task['time'] as String;
        final taskDate = DateTime.parse(task['date']);
        final parts = taskTime.split(':');

        DateTime scheduledDate = DateTime(
          taskDate.year,
          taskDate.month,
          taskDate.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );

        final DateTime actualTaskTime = scheduledDate.add(
          const Duration(minutes: 15),
        );

        String label = "${task['title']} (dans 15 min)";

        final now = DateTime.now();
        if (scheduledDate.isBefore(now)) {
          if (actualTaskTime.isAfter(now)) {
            scheduledDate = actualTaskTime;
            label = "${task['title']} (Maintenant)";
          } else {
            continue;
          }
        }

        final id = task['_id'].toString();
        const channel = MethodChannel('fall_channel');
        await channel.invokeMethod('scheduleTask', {
          'id': id,
          'title': label,
          'description': task['description'] ?? '',
          'timestamp': scheduledDate.millisecondsSinceEpoch,
        });
      }
    } catch (e) {
      debugPrint("Error scheduling tasks: $e");
    }
  }

  Future<void> scheduleMedications() async {
    try {
      final elderId = InMemoryFaceStorage().getElderId();
      if (elderId == null) return;

      final data = await _apiService.getMedications(elderId);
      final allMeds = data.map((json) => Medication.fromJson(json)).toList();

      final historyToday = await _apiService.getElderMedicationHistoryToday(
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

      final untakenMeds = todayMeds
          .where((m) => !takenTodayIds.contains(m.id))
          .toList();
      await MedicationReminderService.scheduleForMedications(untakenMeds);

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
      debugPrint("Error scheduling medications: $e");
    }
  }

  Future<void> fetchCaregiverPhone() async {
    final elderId = InMemoryFaceStorage().getElderId();
    if (elderId == null) return;
    if (InMemoryFaceStorage().getCaregiverPhone() != null) return;

    try {
      final data = await _apiService.getElderCaregiver(elderId);
      if (data['caregiver'] != null && data['caregiver']['phone'] != null) {
        await InMemoryFaceStorage().setCaregiverPhone(
          data['caregiver']['phone'],
        );
      }
    } catch (e) {
      debugPrint("Error fetching caregiver phone: $e");
    }
  }
}
