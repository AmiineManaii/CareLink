package com.example.care_link

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.app.KeyguardManager
import android.telephony.SmsManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "fall_channel"
    private val EVENT_CHANNEL = "fall_events"
    private var pendingFallEvent = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        android.util.Log.d("DEBUG_SERVICE", "MainActivity.onCreate() appelé")

        // Code pour réveiller l'écran et passer par-dessus le verrouillage (Lock Screen)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }

        // Vérifier si l'activité a été lancée par une chute
        if (intent.getBooleanExtra("TRIGGER_SOS", false)) {
             android.util.Log.d("DEBUG_SERVICE", "Lancement via TRIGGER_SOS détecté !")
             pendingFallEvent = true
        }

        // Démarrer le service de fond (toujours démarré pour les rappels/notifications)
        val serviceIntent = Intent(this, FallDetectionService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
        android.util.Log.d("DEBUG_SERVICE", "Service de fond démarré")
    }

    private fun scheduleAlarm(id: String, name: String, dosage: String, timestamp: Long, isTask: Boolean = false) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        val receiverClass = if (isTask) TaskAlarmReceiver::class.java else MedicationAlarmReceiver::class.java
        
        val intent = Intent(this, receiverClass).apply {
            if (isTask) {
                putExtra("taskTitle", name)
                putExtra("taskDescription", dosage) // Reuse dosage field for description
            } else {
                putExtra("medicationName", name)
                putExtra("dosage", dosage)
            }
            data = android.net.Uri.parse("carelink://$id") // Unique per notification
        }
        val pendingIntent = android.app.PendingIntent.getBroadcast(
            this,
            id.hashCode(),
            intent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(android.app.AlarmManager.RTC_WAKEUP, timestamp, pendingIntent)
        } else {
            alarmManager.setExact(android.app.AlarmManager.RTC_WAKEUP, timestamp, pendingIntent)
        }
        val type = if (isTask) "Tâche" else "Médicament"
        android.util.Log.d("DEBUG_SERVICE", "$type programmée : $name à $timestamp (ID: $id)")
    }

    private fun cancelAlarm(id: String, isTask: Boolean = false) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        val receiverClass = if (isTask) TaskAlarmReceiver::class.java else MedicationAlarmReceiver::class.java
        
        val intent = Intent(this, receiverClass).apply {
            data = android.net.Uri.parse("carelink://$id")
        }
        val pendingIntent = android.app.PendingIntent.getBroadcast(
            this,
            id.hashCode(),
            intent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
        android.util.Log.d("DEBUG_SERVICE", "Alarme annulée pour ID: $id")
    }

    private fun sendSMS(phoneNumber: String, message: String) {
        try {
            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(android.telephony.SmsManager::class.java)
            } else {
                android.telephony.SmsManager.getDefault()
            }
            smsManager.sendTextMessage(phoneNumber, null, message, null, null)
            android.util.Log.d("DEBUG_SERVICE", "SMS envoyé avec succès à $phoneNumber")
        } catch (e: Exception) {
            android.util.Log.e("DEBUG_SERVICE", "Erreur lors de l'envoi du SMS: ${e.message}")
        }
    }
    private fun showSOSNotification(alertId: String, message: String, latitude: Double?, longitude: Double?) {
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = android.app.NotificationChannel(
                    "sos_channel",
                    "Alertes SOS",
                    android.app.NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Notifications d'alertes SOS"
                    enableVibration(true)
                    enableLights(true)
                }
                notificationManager.createNotificationChannel(channel)
            }
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("alertId", alertId)
                putExtra("isSOS", true)
            }
            val pendingIntent = android.app.PendingIntent.getActivity(
                this,
                alertId.hashCode(),
                intent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            val builder = android.app.Notification.Builder(this, "sos_channel")
                .setSmallIcon(android.R.drawable.ic_dialog_alert)
                .setContentTitle("⚠️ ALERTE SOS")
                .setContentText(message)
                .setStyle(android.app.Notification.BigTextStyle().bigText(message))
                .setPriority(android.app.Notification.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setVibrate(longArrayOf(0, 500, 200, 500))
            if (latitude != null && longitude != null) {
                val googleMapsUrl = "https://maps.google.com/?q=$latitude,$longitude"
                val mapIntent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse(googleMapsUrl))
                val mapPendingIntent = android.app.PendingIntent.getActivity(
                    this,
                    0,
                    mapIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                builder.addAction(
                    android.R.drawable.ic_menu_mapmode,
                    "Voir sur la carte",
                    mapPendingIntent
                )
            }
            notificationManager.notify(alertId.hashCode(), builder.build())
            android.util.Log.d("DEBUG_SERVICE", "Notification SOS affichée: $message")
        } catch (e: Exception) {
            android.util.Log.e("DEBUG_SERVICE", "Erreur lors de l'affichage de la notification SOS: ${e.message}")
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // MODIFICATION: Ne plus traiter TRIGGER_SOS ici car c'est redondant avec l'EventChannel du service
        // Le service envoie déjà un broadcast "com.example.care_link.FALL_DETECTED" directement à Flutter
        /*
        if (intent.getBooleanExtra("TRIGGER_SOS", false)) {
             android.util.Log.d("DEBUG_SERVICE", "onNewIntent: TRIGGER_SOS détecté !")
             pendingFallEvent = true
             // Si le receiver est déjà actif, on peut tenter d'envoyer l'événement tout de suite
             // Mais on attendra que Flutter le demande via onListen idéalement, ou on utilise le broadcast
             val broadcastIntent = Intent("com.example.care_link.FALL_DETECTED")
             broadcastIntent.setPackage(packageName)
             sendBroadcast(broadcastIntent)
        }
        */
    }

    // Variable pour stocker le receiver et le désinscrire proprement
    private var fallEventReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // MethodChannel (optionnel)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "startService") {
                    val intent = Intent(this, FallDetectionService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success("Service démarré")
                } else if (call.method == "stopService") {
                    val intent = Intent(this, FallDetectionService::class.java)
                    stopService(intent)
                    result.success("Service arrêté")
                } else if (call.method == "scheduleMedication") {
                    val id = call.argument<String>("id")
                    val name = call.argument<String>("name")
                    val dosage = call.argument<String>("dosage")
                    val timestamp = call.argument<Long>("timestamp")

                    if (id != null && name != null && timestamp != null) {
                        scheduleAlarm(id, name, dosage ?: "", timestamp, false)
                        result.success("Alarm scheduled")
                    } else {
                        result.error("INVALID_ARGS", "Missing arguments", null)
                    }
                } else if (call.method == "cancelMedication") {
                    val id = call.argument<String>("id")
                    if (id != null) {
                        cancelAlarm(id, false)
                        result.success("Alarm cancelled")
                    } else {
                        result.error("INVALID_ARGS", "Missing id", null)
                    }
                } else if (call.method == "scheduleTask") {
                    val id = call.argument<String>("id")
                    val title = call.argument<String>("title")
                    val description = call.argument<String>("description")
                    val timestamp = call.argument<Long>("timestamp")

                    if (id != null && title != null && timestamp != null) {
                        scheduleAlarm(id, title, description ?: "", timestamp, true)
                        result.success("Task scheduled")
                    } else {
                        result.error("INVALID_ARGS", "Missing arguments", null)
                    }
                } else if (call.method == "cancelTask") {
                    val id = call.argument<String>("id")
                    if (id != null) {
                        cancelAlarm(id, true)
                        result.success("Task cancelled")
                    } else {
                        result.error("INVALID_ARGS", "Missing id", null)
                    }
                } else if (call.method == "sendSMS") {
                    val phone = call.argument<String>("phone")
                    val message = call.argument<String>("message")
                    if (phone != null && message != null) {
                        sendSMS(phone, message)
                        result.success("SMS sent")
                    } else {
                        result.error("INVALID_ARGS", "Missing phone or message", null)
                    }
                } else if (call.method == "showSOSNotification") {
                    val alertId = call.argument<String>("alertId")
                    val message = call.argument<String>("message")
                    
                    // Récupération sécurisée de la latitude et longitude (peut être String ou Double depuis Flutter)
                    val latRaw = call.argument<Any>("latitude")
                    val lonRaw = call.argument<Any>("longitude")
                    
                    val latitude = when (latRaw) {
                        is Double -> latRaw
                        is String -> latRaw.toDoubleOrNull()
                        else -> null
                    }
                    val longitude = when (lonRaw) {
                        is Double -> lonRaw
                        is String -> lonRaw.toDoubleOrNull()
                        else -> null
                    }
                    
                    if (alertId != null && message != null) {
                        showSOSNotification(alertId, message, latitude, longitude)
                        result.success("SOS Notification shown")
                    } else {
                        result.error("INVALID_ARGS", "Missing alertId or message", null)
                    } 
                } else {
                    result.notImplemented()
                }
            }

        // EventChannel pour écouter les événements
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    android.util.Log.d("DEBUG_SERVICE", "EventChannel onListen appelé. pendingFallEvent=$pendingFallEvent")
                    if (pendingFallEvent) {
                        events?.success("fall_detected")
                        pendingFallEvent = false
                    }
                    if (fallEventReceiver == null) {
                        fallEventReceiver = object : BroadcastReceiver() {
                            override fun onReceive(context: Context?, intent: Intent?) {
                                if (intent?.action == "com.example.care_link.FALL_DETECTED") {
                                    events?.success("fall_detected")
                                }
                            }
                        }
                        val filter = IntentFilter("com.example.care_link.FALL_DETECTED")
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            registerReceiver(fallEventReceiver, filter, Context.RECEIVER_EXPORTED)
                        } else {
                            registerReceiver(fallEventReceiver, filter)
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    // Nettoyage lors de l'annulation du stream Flutter
                    fallEventReceiver?.let {
                        unregisterReceiver(it)
                        fallEventReceiver = null
                    }
                }
            })
    }
    
    override fun onDestroy() {
        super.onDestroy()
        // Désinscrire le receiver pour éviter les fuites de mémoire
        fallEventReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
                // Ignore si déjà désinscrit
            }
        }
        android.util.Log.d("DEBUG_SERVICE", "MainActivity.onDestroy()")
    }
}