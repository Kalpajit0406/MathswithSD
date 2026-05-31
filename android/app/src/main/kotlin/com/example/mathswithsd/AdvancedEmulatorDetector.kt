package com.example.mathswithsd

import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorManager
import android.os.Build
import java.io.File

class AdvancedEmulatorDetector(private val context: Context) {

    fun getRiskEvaluation(): Map<String, Any> {
        val buildRisk = checkBuildProperties()
        val sensorRisk = checkPhysicalSensors()
        val envRisk = checkSystemEnvironment()

        // Weighted Risk Model: Build Properties (40%), System Environment/Files (35%), Physical Sensors (25%)
        val cumulativeRisk = (buildRisk * 0.40f) + (envRisk * 0.35f) + (sensorRisk * 0.25f)

        val details = mapOf(
            "buildRisk" to buildRisk,
            "sensorRisk" to sensorRisk,
            "envRisk" to envRisk,
            "fingerprint" to (Build.FINGERPRINT ?: ""),
            "hardware" to (Build.HARDWARE ?: ""),
            "model" to (Build.MODEL ?: "")
        )

        return mapOf(
            "cumulativeRisk" to cumulativeRisk.toDouble(),
            "details" to details
        )
    }

    /**
     * Layer 1: Hardware & Build Properties (Max Risk: 1.0)
     */
    private fun checkBuildProperties(): Float {
        var score = 0.0f
        val fingerprint = Build.FINGERPRINT ?: ""
        val model = Build.MODEL ?: ""
        val hardware = Build.HARDWARE ?: ""
        val board = Build.BOARD ?: ""
        val brand = Build.BRAND ?: ""
        val device = Build.DEVICE ?: ""
        val product = Build.PRODUCT ?: ""

        // Critical emulator signatures (100% risk)
        if (hardware.contains("goldfish") || 
            hardware.contains("ranchu") || 
            hardware.contains("vbox86") || 
            product.contains("sdk_gphone") || 
            model.contains("google_sdk") || 
            model.contains("emulator")
        ) {
            score += 1.0f
        }

        // Suspicious values
        if (brand.startsWith("generic") && device.startsWith("generic")) score += 0.6f
        if (model.contains("bluestacks") || product.contains("bluestacks")) score += 0.8f
        if (board.lowercase().contains("nox") || hardware.lowercase().contains("nox") || product.lowercase().contains("nox")) score += 0.8f
        if (fingerprint.startsWith("generic") || fingerprint.startsWith("unknown")) score += 0.5f

        // Bootloader check - we only check for qemu to avoid false positives with "unknown"
        val bootloader = Build.BOOTLOADER ?: ""
        if (bootloader.lowercase().contains("qemu")) score += 0.8f

        return score.coerceAtMost(1.0f)
    }

    /**
     * Layer 2: Sensor & OS Capability Validation (Max Risk: 1.0)
     */
    private fun checkPhysicalSensors(): Float {
        var score = 0.0f
        val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager

        if (sensorManager == null) {
            return 1.0f
        }

        val hasLight = sensorManager.getDefaultSensor(Sensor.TYPE_LIGHT) != null
        val hasGyro = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE) != null
        val hasAccel = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null

        // Accelerometer missing is a major anomaly for physical phones
        if (!hasAccel) {
            score += 0.7f
        }
        
        // Emulators typically do not map ambient light or gyroscope hardware
        if (!hasLight && !hasGyro) {
            score += 0.4f
        }

        // Check for Multitouch support (emulators often only support single-touch mouse events)
        val hasMultitouch = context.packageManager.hasSystemFeature(PackageManager.FEATURE_TOUCHSCREEN_MULTITOUCH_DISTINCT)
        if (!hasMultitouch) {
            score += 0.3f
        }

        return score.coerceAtMost(1.0f)
    }

    /**
     * Layer 3: System Environment & Path Scanning (Max Risk: 1.0)
     */
    private fun checkSystemEnvironment(): Float {
        var score = 0.0f

        val criticalPaths = arrayOf(
            "/dev/socket/qemud",
            "/dev/qemu_pipe"
        )
        for (path in criticalPaths) {
            if (File(path).exists()) score += 0.9f
        }

        val emulatorFiles = arrayOf(
            "system/lib/libc_malloc_debug_qemu.so",
            "sys/qemu_trace",
            "system/bin/nox-prop",
            "system/bin/noxd"
        )
        for (path in emulatorFiles) {
            if (File(path).exists()) score += 0.4f
        }

        return score.coerceAtMost(1.0f)
    }
}
