package com.fitverse.app

import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * FitVerse main activity.
 *
 * Extends FlutterFragmentActivity (not FlutterActivity) so that plugins
 * using Android's ActivityResultContracts API — including the health
 * package's Health Connect permission launcher — can register their
 * ActivityResultLauncher in onAttachedToActivity().
 *
 * Also hosts MethodChannels for:
 *   • Starting/stopping the StepCounterService foreground service
 *   • Reading background step data from SharedPreferences
 */
class MainActivity : FlutterFragmentActivity() {

    private val STEP_SERVICE_CHANNEL = "com.fitverse.app/step_service"
    private val PREFS_CHANNEL        = "com.fitverse.app/shared_prefs"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Step service control ────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STEP_SERVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        val intent = Intent(this, StepCounterService::class.java).apply {
                            action = StepCounterService.ACTION_START
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }
                    "stopService" -> {
                        val intent = Intent(this, StepCounterService::class.java).apply {
                            action = StepCounterService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── SharedPreferences reader ────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PREFS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getStepData" -> {
                        val prefs = getSharedPreferences(
                            StepCounterService.PREFS_NAME, Context.MODE_PRIVATE)
                        val steps = prefs.getInt(StepCounterService.KEY_STEPS, 0)
                        val cals  = prefs.getFloat(StepCounterService.KEY_CALS, 0f)
                        result.success(mapOf("steps" to steps, "cals" to cals.toDouble()))
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
