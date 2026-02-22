package com.example.care_link

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.app.KeyguardManager
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
        val intent = Intent(this, FallDetectionService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
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