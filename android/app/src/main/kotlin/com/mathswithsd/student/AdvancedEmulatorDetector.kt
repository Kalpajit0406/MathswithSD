package com.mathswithsd.student

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

        val cumulativeRisk = if (buildRisk >= 1.0f || envRisk >= 0.9f) {
            1.0
        } else {
            (buildRisk * 0.5f + sensorRisk * 0.2f + envRisk * 0.3f).toDouble()
        }

        val details = mapOf(
            "buildRisk" to buildRisk,
            "sensorRisk" to sensorRisk,
            "envRisk" to envRisk,
            "fingerprint" to (Build.FINGERPRINT ?: ""),
            "hardware" to (Build.HARDWARE ?: ""),
            "model" to (Build.MODEL ?: "")
        )

        return mapOf(
            "cumulativeRisk" to cumulativeRisk,
            "details" to details
        )
    }

    private fun getSystemProperty(key: String): String {
        return try {
            val systemPropertiesClass = Class.forName("android.os.SystemProperties")
            val getMethod = systemPropertiesClass.getMethod("get", String::class.java)
            (getMethod.invoke(null, key) as? String) ?: ""
        } catch (e: Exception) {
            ""
        }
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
        val manufacturer = Build.MANUFACTURER ?: ""

        // Critical emulator signatures (100% risk)
        if (hardware.lowercase().contains("goldfish") || 
            hardware.lowercase().contains("ranchu") || 
            hardware.lowercase().contains("vbox86") || 
            product.lowercase().contains("sdk_gphone") || 
            product.lowercase().contains("emulator") ||
            model.lowercase().contains("google_sdk") || 
            model.lowercase().contains("emulator") ||
            model.lowercase().contains("bluestacks") ||
            product.lowercase().contains("bluestacks") ||
            manufacturer.lowercase().contains("bluestacks")
        ) {
            score += 1.0f
        }

        // Suspicious values
        if (brand.startsWith("generic") && device.startsWith("generic")) score += 0.6f
        if (board.lowercase().contains("nox") || hardware.lowercase().contains("nox") || product.lowercase().contains("nox")) score += 0.8f
        if (fingerprint.startsWith("generic") || fingerprint.startsWith("unknown")) score += 0.5f

        // Bootloader check
        val bootloader = Build.BOOTLOADER ?: ""
        if (bootloader.lowercase().contains("qemu") || bootloader.lowercase().contains("unknown")) score += 0.8f

        // Check system properties via reflection
        val roHardware = getSystemProperty("ro.hardware").lowercase()
        val roKernelQemu = getSystemProperty("ro.kernel.qemu")
        val roProductModel = getSystemProperty("ro.product.model").lowercase()
        
        if (roHardware.contains("goldfish") || roHardware.contains("ranchu") || roHardware.contains("vbox86")) score += 0.9f
        if (roKernelQemu == "1") score += 1.0f
        if (roProductModel.contains("bluestacks") || roProductModel.contains("nox")) score += 0.9f

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

        val hasAccel = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null

        // Accelerometer missing is a major anomaly for physical phones
        if (!hasAccel) {
            score += 0.7f
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
    private fun checkCpuInfo(): Boolean {
        try {
            val file = File("/proc/cpuinfo")
            if (file.exists()) {
                val content = file.readText().lowercase()
                if (content.contains("intel") || 
                    content.contains("amd") || 
                    content.contains("qemu") || 
                    content.contains("goldfish") ||
                    content.contains("virtual")
                ) {
                    return true
                }
            }
        } catch (e: Exception) {
            // ignore
        }
        return false
    }

    private fun checkProcVersion(): Boolean {
        try {
            val file = File("/proc/version")
            if (file.exists()) {
                val content = file.readText().lowercase()
                if (content.contains("virt") || 
                    content.contains("qemu") || 
                    content.contains("oracle") || 
                    content.contains("virtualbox") || 
                    content.contains("bluestacks") ||
                    content.contains("nox")
                ) {
                    return true
                }
            }
        } catch (e: Exception) {
            // ignore
        }
        return false
    }

    private fun checkSupportedAbis(): Boolean {
        for (abi in Build.SUPPORTED_ABIS) {
            val lower = abi.lowercase()
            if (lower.contains("x86") || 
                lower.contains("x86_64") || 
                lower.contains("i386") || 
                lower.contains("i686")
            ) {
                return true
            }
        }
        return false
    }

    private fun checkSystemEnvironment(): Float {
        var score = 0.0f

        if (checkCpuInfo() || checkProcVersion() || checkSupportedAbis()) {
            score += 1.0f
        }

        val criticalPaths = arrayOf(
            "/dev/socket/qemud",
            "/dev/qemu_pipe",
            "/mnt/windows/BstSharedFolder",
            "/sdcard/windows/BstSharedFolder",
            "/storage/emulated/0/windows/BstSharedFolder",
            "/data/media/0/windows/BstSharedFolder"
        )
        for (path in criticalPaths) {
            if (File(path).exists()) score += 0.9f
        }

        val emulatorFiles = arrayOf(
            "/system/lib/libc_malloc_debug_qemu.so",
            "/sys/qemu_trace",
            "/system/bin/nox-prop",
            "/system/bin/noxd",
            "/dev/socket/bsthald",
            "/dev/socket/bstplay",
            "/dev/socket/bst_channel",
            "/system/bin/bstfolder",
            "/system/bin/bstsync",
            "/data/bluestacks.prop",
            "/sys/module/bluestacks",
            "/data/system/bluestacks",
            "/sys/module/bstfolders"
        )
        for (path in emulatorFiles) {
            if (File(path).exists()) score += 0.9f
        }

        return score.coerceAtMost(1.0f)
    }
}
