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

        // Démarrer le service immédiatement
        val serviceIntent = Intent(this, FallDetectionService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun scheduleAlarm(id: String, name: String, dosage: String, timestamp: Long) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        val intent = Intent(this, MedicationAlarmReceiver::class.java).apply {
            putExtra("medicationName", name)
            putExtra("dosage", dosage)
            data = android.net.Uri.parse("medication://$id") // Unique per medication
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
        android.util.Log.d("DEBUG_SERVICE", "Alarme programmée pour $name à $timestamp (ID: $id)")
    }

    private fun cancelAlarm(id: String) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        val intent = Intent(this, MedicationAlarmReceiver::class.java).apply {
            data = android.net.Uri.parse("medication://$id")
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
                } else if (call.method == "scheduleMedication") {
                    val id = call.argument<String>("id")
                    val name = call.argument<String>("name")
                    val dosage = call.argument<String>("dosage")
                    val timestamp = call.argument<Long>("timestamp")

                    if (id != null && name != null && timestamp != null) {
                        scheduleAlarm(id, name, dosage ?: "", timestamp)
                        result.success("Alarm scheduled")
                    } else {
                        result.error("INVALID_ARGS", "Missing arguments", null)
                    }
                } else if (call.method == "cancelMedication") {
                    val id = call.argument<String>("id")
                    if (id != null) {
                        cancelAlarm(id)
                        result.success("Alarm cancelled")
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