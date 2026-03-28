import 'package:flutter/services.dart';
import 'package:care_link/models/medication.dart';
import 'package:flutter/material.dart';

class MedicationReminderService {
  static const MethodChannel _channel = MethodChannel('fall_channel');

  // Schedule reminders for a list of medications
  static Future<void> scheduleForMedications(
    List<Medication> medications,
  ) async {
    // Cancel all existing (conceptually - in reality we overwrite by ID if we use consistent IDs)
    // But since IDs are unique per medication, we might need to cancel old ones if times changed.
    // For simplicity, we just schedule next occurrences.

    for (var med in medications) {
      await scheduleMedication(med);
    }
  }

  static Future<void> scheduleMedication(Medication med) async {
    // 1. Cancel existing alarms for this med (to be safe)
    // We need a way to generate consistent IDs for each time slot
    // med.id + timeIndex

    for (int i = 0; i < med.times.length; i++) {
      final timeStr = med.times[i];
      final timeParts = timeStr.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      DateTime now = DateTime.now();
      DateTime? nextTime;

      if (med.frequency == 'Quotidien') {
        nextTime = DateTime(now.year, now.month, now.day, hour, minute);
        if (nextTime.isBefore(now)) {
          nextTime = nextTime.add(const Duration(days: 1));
        }
      } else if (med.frequency == 'Hebdomadaire' ||
          med.frequency == 'Au besoin') {
        // Check if days are specified
        if (med.days.isEmpty) {
          continue; // No days specified, no reminder
        }

        // Find next matching day
        DateTime baseTime = DateTime(
          now.year,
          now.month,
          now.day,
          hour,
          minute,
        );

        // If today matches a day, check if time is future
        bool todayMatches = med.days.contains(baseTime.weekday);
        if (todayMatches && baseTime.isAfter(now)) {
          nextTime = baseTime;
        } else {
          // Search next days
          for (int d = 1; d <= 14; d++) {
            final candidate = baseTime.add(Duration(days: d));
            if (med.days.contains(candidate.weekday)) {
              nextTime = candidate;
              break;
            }
          }
        }
      }

      if (nextTime != null) {
        // Schedule notification 15 minutes before the medication time
        DateTime finalTime = nextTime.subtract(const Duration(minutes: 15));
        String label = "${med.name} (dans 15 min)";

        // If the 15-min warning is in the past, but the actual time is future, schedule for the actual time
        // This avoids repeating notifications immediately on every screen change,
        // as the alarm will be set for a future time (nextTime).
        if (finalTime.isBefore(DateTime.now())) {
          if (nextTime.isAfter(DateTime.now())) {
            finalTime = nextTime;
            label = "${med.name} (Maintenant)";
          } else {
            continue; // Both warning and actual time are in the past
          }
        }

        final alarmId = "${med.id}_$i";
        await _channel.invokeMethod('scheduleMedication', {
          'id': alarmId,
          'name': label,
          'dosage': med.dosage,
          'timestamp': finalTime.millisecondsSinceEpoch,
        });
        debugPrint(
          "Scheduled ${med.name} notification for $finalTime (15 min before)",
        );
      }
    }
  }

  static Future<void> cancelMedication(Medication med) async {
    for (int i = 0; i < med.times.length; i++) {
      final alarmId = "${med.id}_$i";
      await _channel.invokeMethod('cancelMedication', {'id': alarmId});
    }
  }
}
