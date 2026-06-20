package com.fitverse.app

import android.app.*
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import kotlin.math.sqrt

/**
 * FitVerse Step Counter Foreground Service
 *
 * Keeps the accelerometer-based pedometer alive when the app is in the background.
 * Steps are accumulated in shared preferences so HealthProvider can read them on resume.
 * The service is started from Dart via a MethodChannel call in HealthProvider.
 */
class StepCounterService : Service(), SensorEventListener {

    companion object {
        const val ACTION_START = "com.fitverse.app.START_STEP_COUNTER"
        const val ACTION_STOP  = "com.fitverse.app.STOP_STEP_COUNTER"
        const val CHANNEL_ID   = "fitverse_step_counter"
        const val NOTIF_ID     = 1001
        const val PREFS_NAME   = "fitverse_steps"
        const val KEY_STEPS    = "background_steps"
        const val KEY_CALS     = "background_cals"
    }

    private lateinit var sensorManager: SensorManager

    // Low-pass filter state
    private var lpX = 0.0; private var lpY = 9.8; private var lpZ = 0.0
    private var inPeak = false
    private var lastStepMs = 0L
    private var steps = 0
    private val LP_ALPHA          = 0.8
    private val STEP_THRESHOLD    = 1.3
    private val STEP_DROP         = 0.55
    private val MIN_STEP_MS       = 350L
    private val CALS_PER_STEP     = 0.04

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        // Restore any previously saved step count so we don't reset on restart
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        steps = prefs.getInt(KEY_STEPS, 0)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        startForeground(NOTIF_ID, buildNotification())
        registerAccelerometer()
        return START_STICKY
    }

    private fun registerAccelerometer() {
        val accel = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) ?: return
        sensorManager.registerListener(this, accel, SensorManager.SENSOR_DELAY_GAME)
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type != Sensor.TYPE_ACCELEROMETER) return
        val ex = event.values[0].toDouble()
        val ey = event.values[1].toDouble()
        val ez = event.values[2].toDouble()

        lpX = LP_ALPHA * lpX + (1 - LP_ALPHA) * ex
        lpY = LP_ALPHA * lpY + (1 - LP_ALPHA) * ey
        lpZ = LP_ALPHA * lpZ + (1 - LP_ALPHA) * ez

        val hpX = ex - lpX; val hpY = ey - lpY; val hpZ = ez - lpZ
        val magnitude = sqrt(hpX * hpX + hpY * hpY + hpZ * hpZ)

        val now = System.currentTimeMillis()
        if (magnitude > STEP_THRESHOLD && !inPeak) {
            inPeak = true
            if (now - lastStepMs >= MIN_STEP_MS) {
                lastStepMs = now
                steps++
                persistSteps()
            }
        } else if (magnitude < STEP_DROP) {
            inPeak = false
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun persistSteps() {
        val cals = steps * CALS_PER_STEP
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
            .putInt(KEY_STEPS, steps)
            .putFloat(KEY_CALS, cals.toFloat())
            .apply()
    }

    override fun onDestroy() {
        sensorManager.unregisterListener(this)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "Step Counter",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Counts steps in the background"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val openIntent = PendingIntent.getActivity(
            this, 0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("FitVerse")
            .setContentText("Counting your steps")
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setContentIntent(openIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}
