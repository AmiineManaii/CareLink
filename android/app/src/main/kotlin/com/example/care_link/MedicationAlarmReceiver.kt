package com.example.care_link

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class MedicationAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val medicationName = intent.getStringExtra("medicationName")
        val dosage = intent.getStringExtra("dosage")
        
        android.util.Log.d("DEBUG_SERVICE", "MedicationAlarmReceiver: Alarme reçue pour $medicationName")

        // Transmettre au service FallDetectionService pour affichage/audio
        val serviceIntent = Intent(context, FallDetectionService::class.java).apply {
            action = "com.example.care_link.ACTION_MEDICATION_REMINDER"
            putExtra("medicationName", medicationName)
            putExtra("dosage", dosage)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
