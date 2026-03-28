package com.example.care_link

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class TaskAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val taskTitle = intent.getStringExtra("taskTitle")
        val taskDescription = intent.getStringExtra("taskDescription")
        
        android.util.Log.d("DEBUG_SERVICE", "TaskAlarmReceiver: Alarme reçue pour $taskTitle")

        // Transmettre au service FallDetectionService pour affichage/audio
        val serviceIntent = Intent(context, FallDetectionService::class.java).apply {
            action = "com.example.care_link.ACTION_TASK_REMINDER"
            putExtra("taskTitle", taskTitle)
            putExtra("taskDescription", taskDescription)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
