package com.example.care_link

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import kotlin.math.sqrt
import kotlin.math.acos
import android.os.CountDownTimer

import android.provider.Settings
import android.net.Uri
import android.hardware.camera2.CameraManager
import android.os.Handler
import android.os.Looper

class FallDetectionService : Service(), SensorEventListener {

    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null
    private var gyroscope: Sensor? = null // Ajout Gyroscope
    private var lastFallTime: Long = 0
    private var wakeLock: PowerManager.WakeLock? = null
    private var mediaPlayer: MediaPlayer? = null

    // Variables pour l'algorithme de chute amélioré
    private var lastFreeFallTime: Long = 0
    private val FREE_FALL_THRESHOLD = 2.5 
    private val IMPACT_THRESHOLD = 25.0   
    private val IMPACT_WINDOW = 1000L     
    private val STABILIZATION_WINDOW = 5000L 
    private var impactTime: Long = 0
    private var isWaitingForStabilization = false
    private var stabilitySumAcceleration = 0.0 // Somme pour la moyenne
    private var stabilityCount = 0 // Compteur pour la moyenne
    private var stabilitySumSquareAcceleration = 0.0 // Somme des carrés pour la variance
    
    // Variables Gyroscope / Orientation
    private var currentOrientation = FloatArray(3)
    private var preFallGravity = FloatArray(3) // Gravité avant la chute
    private var postFallGravity = FloatArray(3) // Gravité après la chute
    private var isOrientationCaptured = false
    private val ORIENTATION_CHANGE_THRESHOLD = 30.0 // 30 degrés pour changement de posture (assis -> couché)

    // Timer pour annulation
    private var countdownTimer: android.os.CountDownTimer? = null
    private val ACTION_CANCEL_SOS = "com.example.care_link.ACTION_CANCEL_SOS"
    private val ACTION_MEDICATION_REMINDER = "com.example.care_link.ACTION_MEDICATION_REMINDER"
    private val ACTION_TASK_REMINDER = "com.example.care_link.ACTION_TASK_REMINDER"

    private var tts: android.speech.tts.TextToSpeech? = null
    private val lastNotificationTimes = mutableMapOf<String, Long>()
    private var isFallDetectionRegistered = false

    override fun onCreate() {
        super.onCreate()
        
        // Init TTS
        tts = android.speech.tts.TextToSpeech(this) { status ->
            if (status == android.speech.tts.TextToSpeech.SUCCESS) {
                tts?.language = java.util.Locale.FRENCH
            }
        }

        // Créer les canaux de notification
        createNotificationChannels()

        // 1. Démarrage immédiat en foreground
        startForeground(1, createNotification())

        // 2. Initialisation des capteurs (via refreshConfiguration)
        refreshConfiguration()

        // 3. Initialisation du lecteur audio silencieux (Astuce pour garder le service en vie)
        try {
            mediaPlayer = MediaPlayer.create(this, R.raw.silence)
            mediaPlayer?.isLooping = true
            mediaPlayer?.setVolume(0f, 0f) // Volume 0
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        android.util.Log.d("DEBUG_SERVICE", "FallDetectionService démarré et protégé")
    }

    private fun refreshConfiguration() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val role = prefs.getString("flutter.role", "")
        
        val sm = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        sensorManager = sm

        if (role == "personne_agee") {
            if (!isFallDetectionRegistered) {
                accelerometer = sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
                gyroscope = sm.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
                
                accelerometer?.let {
                    sm.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
                }
                gyroscope?.let {
                    sm.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
                }
                
                // Acquisition du WakeLock
                val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "FallDetectionService::WakeLock")
                wakeLock?.acquire()
                
                isFallDetectionRegistered = true
                android.util.Log.d("DEBUG_SERVICE", "Détection de chute ACTIVÉE (rôle: $role)")
            }
        } else {
            if (isFallDetectionRegistered) {
                sensorManager?.unregisterListener(this)
                wakeLock?.let {
                    if (it.isHeld) it.release()
                }
                isFallDetectionRegistered = false
                android.util.Log.d("DEBUG_SERVICE", "Détection de chute DÉSACTIVÉE (rôle: $role)")
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Rafraîchir la config à chaque fois que le service est "pingé" (ex: changement de rôle)
        refreshConfiguration()

        if (intent?.action == ACTION_CANCEL_SOS) {
            cancelFallCountdown()
        } else if (intent?.action == ACTION_MEDICATION_REMINDER) {
            val medName = intent.getStringExtra("medicationName") ?: "Médicament"
            val dosage = intent.getStringExtra("dosage") ?: ""
            handleMedicationReminder(medName, dosage)
        } else if (intent?.action == ACTION_TASK_REMINDER) {
            val taskTitle = intent.getStringExtra("taskTitle") ?: "Tâche"
            val taskDescription = intent.getStringExtra("taskDescription") ?: ""
            handleTaskReminder(taskTitle, taskDescription)
        }
        
        // Lancer la lecture silencieuse pour que le système considère cela comme de la lecture média
        try {
            if (mediaPlayer == null) {
                mediaPlayer = MediaPlayer.create(this, R.raw.silence)
                mediaPlayer?.isLooping = true
                mediaPlayer?.setVolume(0f, 0f)
            }
            if (mediaPlayer?.isPlaying == false) {
                mediaPlayer?.start()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return START_STICKY
    }

    private fun handleMedicationReminder(name: String, dosage: String) {
        val now = System.currentTimeMillis()
        val lastTime = lastNotificationTimes[name] ?: 0L
        if (now - lastTime < 60000) { // Anti-spam 60s
            android.util.Log.d("DEBUG_SERVICE", "Rappel médicament $name ignoré (déjà envoyé récemment)")
            return
        }
        lastNotificationTimes[name] = now

        // Check Visual Alert Setting
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val visualAlertEnabled = prefs.getBoolean("flutter.visualAlertEnabled", false)
        if (visualAlertEnabled) {
            blinkFlash()
        }

        // Notification
        val notification = NotificationCompat.Builder(this, "fall_alert_channel")
            .setContentTitle("Rappel Médicament")
            .setContentText("Il est l'heure de prendre : $name $dosage")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setSound(Settings.System.DEFAULT_ALARM_ALERT_URI)
            .build()

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        // Utiliser un ID stable basé sur le nom pour éviter les doublons
        manager.notify(name.hashCode(), notification)

        // Voice
        tts?.speak("Il est l'heure de prendre votre médicament : $name", android.speech.tts.TextToSpeech.QUEUE_FLUSH, null, null)
    }

    private fun handleTaskReminder(title: String, description: String) {
        val now = System.currentTimeMillis()
        val lastTime = lastNotificationTimes[title] ?: 0L
        if (now - lastTime < 60000) { // Anti-spam 60s
            android.util.Log.d("DEBUG_SERVICE", "Rappel tâche $title ignoré (déjà envoyé récemment)")
            return
        }
        lastNotificationTimes[title] = now

        // Check Visual Alert Setting
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val visualAlertEnabled = prefs.getBoolean("flutter.visualAlertEnabled", false)
        if (visualAlertEnabled) {
            blinkFlash()
        }

        // Notification
        val notification = NotificationCompat.Builder(this, "fall_alert_channel")
            .setContentTitle("Rappel de Tâche")
            .setContentText("N'oubliez pas : $title")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setSound(Settings.System.DEFAULT_ALARM_ALERT_URI)
            .build()

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        // Utiliser un ID stable basé sur le titre
        manager.notify(title.hashCode(), notification)

        // Voice
        tts?.speak("Rappel de tâche : $title", android.speech.tts.TextToSpeech.QUEUE_FLUSH, null, null)
    }

    private fun blinkFlash() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
                val cameraId = cameraManager.cameraIdList[0]
                val handler = Handler(Looper.getMainLooper())
                
                // Blink 3 times
                for (i in 0 until 6) {
                    handler.postDelayed({
                        try {
                            cameraManager.setTorchMode(cameraId, i % 1 == 0)
                        } catch (e: Exception) {
                            android.util.Log.e("DEBUG_SERVICE", "Flash error: ${e.message}")
                        }
                    }, (i * 300).toLong())
                }
            } catch (e: Exception) {
                android.util.Log.e("DEBUG_SERVICE", "Flash accessibility error: ${e.message}")
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        android.util.Log.d("DEBUG_SERVICE", "Swipe détecté, mais le service continue (Media Playback)")
        // On ne fait RIEN ici. Le service continue de tourner.
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            sensorManager?.unregisterListener(this)
            wakeLock?.let {
                if (it.isHeld) it.release()
            }
            mediaPlayer?.stop()
            mediaPlayer?.release()
            tts?.shutdown()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        android.util.Log.d("DEBUG_SERVICE", "FallDetectionService détruit")
    }

    override fun onSensorChanged(event: SensorEvent?) {
        event ?: return

        // Capture du Gyroscope pour l'orientation
        if (event.sensor.type == Sensor.TYPE_GYROSCOPE) {
            // Intégration simple pour suivre l'orientation (approx)
            // On utilise les valeurs brutes pour détecter une rotation brusque
            System.arraycopy(event.values, 0, currentOrientation, 0, 3)
            return
        }

        if (event.sensor.type == Sensor.TYPE_ACCELEROMETER) {
            val x = event.values[0]
            val y = event.values[1]
            val z = event.values[2]

            val acceleration = sqrt((x*x + y*y + z*z).toDouble())
            val currentTime = System.currentTimeMillis()

            // Mise à jour constante de la gravité avant chute (si on n'est pas en train de tomber)
            if (!isWaitingForStabilization && (currentTime - lastFreeFallTime > 2000)) {
                System.arraycopy(event.values, 0, preFallGravity, 0, 3)
            }

            // Phase 1: Détection Chute Libre (Free Fall)
            // L'accélération tend vers 0g (ici < 2.5 m/s²)
            if (acceleration < FREE_FALL_THRESHOLD) {
                lastFreeFallTime = currentTime
                // On capture l'orientation "avant" la chute potentielle (déjà fait via preFallGravity continu)
            }

            // Phase 2: Détection Impact violent juste après une chute libre
            if (acceleration > IMPACT_THRESHOLD && (currentTime - lastFreeFallTime) < IMPACT_WINDOW) {
                impactTime = currentTime
                isWaitingForStabilization = true
                stabilitySumAcceleration = 0.0 // Reset moyenne
                stabilitySumSquareAcceleration = 0.0
                stabilityCount = 0
                android.util.Log.d("DEBUG_SERVICE", "IMPACT DÉTECTÉ ! Accel: $acceleration. En attente de stabilisation...")
            }
            // Phase 3: Vérification de l'immobilité (Stabilisation) après l'impact
            if (isWaitingForStabilization) {
                if (currentTime - impactTime < 4000) {
                    return
                }
                // Accumulation pour la moyenne
                stabilitySumAcceleration += acceleration
                stabilitySumSquareAcceleration += (acceleration * acceleration)
                stabilityCount++
                // On attend que STABILIZATION_WINDOW soit passé
                //android.util.Log.d("DEBUG_SERVICE","current time $currentTime et impact time $impactTime")
                android.util.Log.d("DEBUG_SERVICE","current acceleration $acceleration")
                if ((currentTime - impactTime) > STABILIZATION_WINDOW) {
                    val averageAcceleration = stabilitySumAcceleration / stabilityCount
                    val variance = (stabilitySumSquareAcceleration / stabilityCount) - (averageAcceleration * averageAcceleration)
                    val stdDev = sqrt(variance)

                    android.util.Log.d("DEBUG_SERVICE","Fin stabilisation. Moyenne: $averageAcceleration, StdDev: $stdDev")
                    // La gravité terrestre est ~9.8. On accepte une marge.
                    val isStable = (averageAcceleration > 9.0 && averageAcceleration < 10.0) && (stdDev < 1.5)
                    if (isStable) {
                        // Capture de la gravité après chute
                        System.arraycopy(event.values, 0, postFallGravity, 0, 3)
                        
                        // Calcul du changement d'angle (Posture)
                        val angleChange = calculateAngleChange(preFallGravity, postFallGravity)
                        android.util.Log.d("DEBUG_SERVICE", "Angle change: $angleChange degrees")

                        if (angleChange > ORIENTATION_CHANGE_THRESHOLD) {
                            if (currentTime - lastFallTime > 60000) { // Anti-spam 60 secondes
                                lastFallTime = currentTime
                                android.util.Log.d("DEBUG_SERVICE", "CHUTE CONFIRMÉE ! (FreeFall + Impact + Stabilité + Orientation)")
                                startFallCountdown() // Lancer le compte à rebours au lieu d'envoyer direct
                            }
                        } else {
                            android.util.Log.d("DEBUG_SERVICE", "Chute annulée : Pas de changement de posture significatif ($angleChange deg)")
                        }
                    } else {
                         android.util.Log.d("DEBUG_SERVICE", "Chute annulée : Mouvement détecté après impact (Non stable)")
                    }
                    
                    isWaitingForStabilization = false // Reset
                    isOrientationCaptured = false
                }
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // Pas nécessaire
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // 1. Canal pour la détection en arrière-plan (Foreground Service)
             val detectionChannel = NotificationChannel(
                 "fall_detection_channel",
                 "Détection de Chute Active",
                 NotificationManager.IMPORTANCE_LOW
             ).apply {
                 description = "Surveille les chutes en arrière-plan"
                 lockscreenVisibility = Notification.VISIBILITY_PUBLIC
             }
             manager.createNotificationChannel(detectionChannel)
 
             // 2. Canal pour les alertes (Chutes, Médicaments)
             val audioAttributes = android.media.AudioAttributes.Builder()
                 .setUsage(android.media.AudioAttributes.USAGE_ALARM)
                 .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                 .build()

             val alertChannel = NotificationChannel(
                 "fall_alert_channel",
                 "Alertes de Santé",
                 NotificationManager.IMPORTANCE_HIGH
             ).apply {
                 description = "Notifications pour les chutes et les médicaments"
                 enableLights(true)
                 enableVibration(true)
                 lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                 setSound(Settings.System.DEFAULT_ALARM_ALERT_URI, audioAttributes)
             }
             manager.createNotificationChannel(alertChannel)
        }
    }

    private fun calculateAngleChange(v1: FloatArray, v2: FloatArray): Double {
        val dot = v1[0]*v2[0] + v1[1]*v2[1] + v1[2]*v2[2]
        val mag1 = sqrt((v1[0]*v1[0] + v1[1]*v1[1] + v1[2]*v1[2]).toDouble())
        val mag2 = sqrt((v2[0]*v2[0] + v2[1]*v2[1] + v2[2]*v2[2]).toDouble())
        val cosTheta = dot / (mag1 * mag2)
        val clamped = Math.max(-1.0, Math.min(1.0, cosTheta))
        return Math.toDegrees(acos(clamped))
    }

    private fun startFallCountdown() {
        android.util.Log.d("DEBUG_SERVICE", "Démarrage du compte à rebours SOS")
        
        createNotificationChannels() // Assurer que les canaux existent

        // 1. Préparer l'intent d'annulation
        val cancelIntent = Intent(this, FallDetectionService::class.java).apply {
            action = ACTION_CANCEL_SOS
        }
        val cancelPendingIntent = PendingIntent.getService(
            this, 0, cancelIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 2. Préparer l'intent pour ouvrir l'app (FullScreen)
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        var fullScreenIntent: PendingIntent? = null
        
        if (launchIntent != null) {
            launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            fullScreenIntent = PendingIntent.getActivity(
                this, 9999, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        // 3. Afficher la notification avec compte à rebours et bouton Annuler
        val notificationBuilder = NotificationCompat.Builder(this, "fall_alert_channel")
            .setContentTitle("CHUTE DÉTECTÉE !")
            .setContentText("Envoi SOS dans 10s... APPUYEZ POUR ANNULER")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setSound(Settings.System.DEFAULT_ALARM_ALERT_URI)
            .setVibrate(longArrayOf(0, 500, 200, 500))
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "ANNULER LE SOS", cancelPendingIntent)

        if (fullScreenIntent != null) {
            notificationBuilder.setFullScreenIntent(fullScreenIntent, true)
        }

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(999, notificationBuilder.build())

        // 4. Lancer l'application immédiatement pour montrer l'UI (si possible)
        if (launchIntent != null) {
             try {
                  startActivity(launchIntent)
             } catch (e: Exception) {
                  // Fallback PendingIntent
                  try { fullScreenIntent?.send() } catch (ex: Exception) {}
             }
        }

        // 5. Démarrer le Timer
        countdownTimer?.cancel()
        countdownTimer = object : CountDownTimer(10000, 1000) {
            override fun onTick(millisUntilFinished: Long) {
                // Update notification text every 5s
                if (millisUntilFinished % 5000 < 1000) {
                     notificationBuilder.setContentText("Envoi SOS dans ${millisUntilFinished/1000}s... APPUYEZ POUR ANNULER")
                     notificationManager.notify(999, notificationBuilder.build())
                }
            }
            override fun onFinish() {
                sendFallEvent() // VRAI envoi du SOS
            }
        }.start()
    }

    private fun cancelFallCountdown() {
        countdownTimer?.cancel()
        android.util.Log.d("DEBUG_SERVICE", "Alerte chute annulée par l'utilisateur")
        
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(999) // Supprimer la notification d'alerte
        
        // Reset variables
        isWaitingForStabilization = false
        lastFreeFallTime = 0
    }

    private fun sendFallEvent() {
        android.util.Log.d("DEBUG_SERVICE", "Envoi final du SOS (Broadcast)")
        
        // 1. Envoyer le Broadcast à Flutter
        val intent = Intent("com.example.care_link.FALL_DETECTED")
        intent.setPackage(packageName)
        sendBroadcast(intent)

        // 2. Mettre à jour la notification pour dire que c'est envoyé
        val notification = NotificationCompat.Builder(this, "fall_alert_channel")
            .setContentTitle("SOS ENVOYÉ")
            .setContentText("L'alerte a été transmise aux contacts d'urgence.")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()
            
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(999, notification)
    }

    private fun createNotification(): Notification {
        val channelId = "fall_detection_channel"
        
        val pendingIntent = PendingIntent.getActivity(
            this, 0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("Protection Active")
            .setContentText("CareLink veille sur vous.")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }
}