package com.example.mathswithsd

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.MotionEvent
import android.view.WindowManager
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val METHOD_CHANNEL   = "com.mathswithsd.exam_security"
        private const val EVENT_CHANNEL    = "com.mathswithsd.exam_window_events"
    }

    private lateinit var overlayDetector: OverlayDetector
    private var insetsController: WindowInsetsControllerCompat? = null

    // EventChannel sink — non-null only while Flutter is listening
    private var windowEventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        overlayDetector = OverlayDetector(this)
        overlayDetector.applyModernOverlayProtection()
    }

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        // Discard touch and terminate app if touch is obscured (Tapjacking/Screen Overlay protection)
        if (overlayDetector.checkTouchEventForOverlay(event)) {
            return false
        }
        return super.dispatchTouchEvent(event)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        insetsController = WindowInsetsControllerCompat(window, window.decorView)

        // ── EventChannel: window-mode changes ────────────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    windowEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    windowEventSink = null
                }
            })

        // ── MethodChannel: kiosk commands ─────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // ── Kiosk Mode ───────────────────────────────────────────
                    "enableKioskMode" -> {
                        try {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            runOnUiThread {
                                insetsController?.let { ctrl ->
                                    ctrl.hide(WindowInsetsCompat.Type.systemBars())
                                    ctrl.systemBarsBehavior =
                                        WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                                }
                            }
                            try { startLockTask() } catch (_: Exception) {}
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("KIOSK_ERROR", "Failed to enable kiosk: ${e.message}", null)
                        }
                    }

                    "disableKioskMode" -> {
                        try {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            runOnUiThread { insetsController?.show(WindowInsetsCompat.Type.systemBars()) }
                            try { stopLockTask() } catch (_: Exception) {}
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("KIOSK_ERROR", "Failed to disable kiosk: ${e.message}", null)
                        }
                    }

                    // ── Foreground Service ────────────────────────────────────
                    "startForegroundMonitor" -> {
                        try {
                            val intent = Intent(this, ExamMonitorService::class.java)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SERVICE_ERROR", "Failed to start monitor: ${e.message}", null)
                        }
                    }

                    "stopForegroundMonitor" -> {
                        try {
                            stopService(Intent(this, ExamMonitorService::class.java))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SERVICE_ERROR", "Failed to stop monitor: ${e.message}", null)
                        }
                    }

                    // ── Instant multi-window poll ─────────────────────────────
                    "isInMultiWindowMode" -> {
                        val inMultiWindow = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            isInMultiWindowMode
                        } else {
                            false
                        }
                        result.success(inMultiWindow)
                    }

                    // ── Platform Integrity Checks ─────────────────────────────
                    "isRooted" -> {
                        result.success(isDeviceRooted())
                    }

                    "isEmulator" -> {
                        result.success(isEmulator())
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun isDeviceRooted(): Boolean {
        val buildTags = android.os.Build.TAGS
        if (buildTags != null && buildTags.contains("test-keys")) {
            return true
        }
        val paths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su"
        )
        for (path in paths) {
            if (java.io.File(path).exists()) return true
        }
        var process: Process? = null
        try {
            process = Runtime.getRuntime().exec(arrayOf("/system/xbin/which", "su"))
            val inStream = java.io.BufferedReader(java.io.InputStreamReader(process.inputStream))
            if (inStream.readLine() != null) return true
        } catch (_: Throwable) {
        } finally {
            process?.destroy()
        }
        return false
    }

    private fun isEmulator(): Boolean {
        val fingerprint = Build.FINGERPRINT ?: ""
        val model = Build.MODEL ?: ""
        val manufacturer = Build.MANUFACTURER ?: ""
        val host = Build.HOST ?: ""
        val brand = Build.BRAND ?: ""
        val device = Build.DEVICE ?: ""
        val product = Build.PRODUCT ?: ""
        val hardware = Build.HARDWARE ?: ""

        return (fingerprint.startsWith("generic")
                || fingerprint.startsWith("unknown")
                || model.contains("google_sdk")
                || model.contains("Emulator")
                || model.contains("Android SDK built for x86")
                || manufacturer.contains("Genymotion")
                || host.startsWith("Build")
                || (brand.startsWith("generic") && device.startsWith("generic"))
                || "google_sdk" == product
                || hardware.contains("goldfish")
                || hardware.contains("ranchu")
                || hardware.contains("vbox86")
                || product.contains("sdk_gphone")
                || product.contains("emulator"))
    }

    // ── Window mode change callbacks ──────────────────────────────────────────

    /**
     * Fires on Android 7+ whenever the user enters/exits split-screen or
     * floating-window mode (Samsung DeX, Xiaomi floating apps, etc.)
     */
    override fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean) {
        super.onMultiWindowModeChanged(isInMultiWindowMode)
        if (isInMultiWindowMode) {
            sendWindowEvent("multiWindow")
        }
    }

    /**
     * Secondary safety net: check multi-window state every time the activity
     * regains focus (e.g. user dismisses a panel and comes back).
     */
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && isInMultiWindowMode) {
            sendWindowEvent("multiWindow")
        }
    }

    /**
     * Check again on resume — catches edge cases on MIUI, OneUI, ColorOS etc.
     * where onMultiWindowModeChanged is not always fired reliably.
     */
    override fun onResume() {
        super.onResume()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && isInMultiWindowMode) {
            sendWindowEvent("multiWindow")
        }
    }

    // ── Helper ────────────────────────────────────────────────────────────────

    private fun sendWindowEvent(type: String) {
        runOnUiThread {
            windowEventSink?.success(type)
        }
    }
}
