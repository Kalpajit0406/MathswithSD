package com.example.mathswithsd

import android.app.Activity
import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorManager
import android.os.Build
import android.util.Log
import java.io.File
import kotlin.system.exitProcess

class SandboxDetector(private val context: Context) {

    companion object {
        private const val TAG = "SandboxDetector"
    }

    /**
     * Runs all virtual environment and emulator detection layers.
     * Returns true if any virtualization indicator is detected.
     */
    fun isVirtualEnvironmentDetected(): Boolean {
        val buildCheck = checkBuildProperties()
        val sysPropCheck = checkSystemProperties()
        val sensorCheck = checkPhysicalSensors()
        val fileCheck = checkEmulatorFiles()

        Log.w(TAG, "Detection results -> Build: $buildCheck, SysProp: $sysPropCheck, Sensors: $sensorCheck, Files: $fileCheck")

        return buildCheck || sysPropCheck || sensorCheck || fileCheck
    }

    /**
     * Layer 1: Check Build Configuration and Hardware Properties
     */
    private fun checkBuildProperties(): Boolean {
        val fingerprint = Build.FINGERPRINT ?: ""
        val model = Build.MODEL ?: ""
        val hardware = Build.HARDWARE ?: ""
        val manufacturer = Build.MANUFACTURER ?: ""
        val product = Build.PRODUCT ?: ""
        val brand = Build.BRAND ?: ""
        val device = Build.DEVICE ?: ""
        val board = Build.BOARD ?: ""

        return (fingerprint.startsWith("generic")
                || fingerprint.startsWith("unknown")
                || model.contains("google_sdk")
                || model.contains("Emulator")
                || model.contains("Android SDK built for x86")
                || model.contains("BlueStacks")
                || manufacturer.contains("Genymotion")
                || manufacturer.contains("nox")
                || brand.startsWith("generic") && device.startsWith("generic")
                || "google_sdk" == product
                || product.contains("sdk_gphone")
                || product.contains("emulator")
                || product.contains("vbox86")
                || hardware.contains("goldfish")
                || hardware.contains("ranchu")
                || hardware.contains("vbox86")
                || board.lowercase().contains("nox")
                || board.lowercase().contains("android")
                || bootloaderMatchesEmulator())
    }

    private fun bootloaderMatchesEmulator(): Boolean {
        val bootloader = Build.BOOTLOADER ?: ""
        return bootloader.lowercase().contains("qemu")
    }

    /**
     * Layer 2: Reflection for Hidden System Properties
     */
    private fun checkSystemProperties(): Boolean {
        try {
            val systemPropertiesClass = Class.forName("android.os.SystemProperties")
            val getMethod = systemPropertiesClass.getMethod("get", String::class.java)

            val qemu = getMethod.invoke(null, "ro.kernel.qemu") as? String
            val qemuHw = getMethod.invoke(null, "ro.kernel.qemu.gles") as? String
            val hardware = getMethod.invoke(null, "ro.hardware") as? String

            if (qemu == "1" || qemuHw == "1") return true
            if (hardware != null && (hardware.contains("goldfish") || hardware.contains("ranchu") || hardware.contains("vbox86"))) {
                return true
            }
        } catch (e: Exception) {
            // Safe fallback if reflection is restricted
        }
        return false
    }

    /**
     * Layer 3: Check for absence of standard physical sensors
     * Emulators/VMs typically do not contain standard ambient light or gyroscope hardware sensors.
     */
    private fun checkPhysicalSensors(): Boolean {
        val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        if (sensorManager == null) {
            // If no sensor manager exists, likely a VM/emulator
            return true
        }

        val hasLightSensor = sensorManager.getDefaultSensor(Sensor.TYPE_LIGHT) != null
        val hasGyroscope = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE) != null
        val hasAccelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null

        // Most real physical phones have at least an accelerometer AND either a light sensor or gyroscope.
        // If neither is present, it's highly indicative of a virtualized runner.
        return !hasAccelerometer || (!hasLightSensor && !hasGyroscope)
    }

    /**
     * Layer 4: Check for virtual environment files and binaries
     */
    private fun checkEmulatorFiles(): Boolean {
        val pipes = arrayOf(
            "/dev/socket/qemud",
            "/dev/qemu_pipe",
            "system/lib/libc_malloc_debug_qemu.so",
            "sys/qemu_trace",
            "system/bin/nox-prop",
            "system/bin/noxd"
        )
        for (pipe in pipes) {
            if (File(pipe).exists()) {
                return true
            }
        }
        return false
    }

    /**
     * Triggers clean termination and removes the app from the device's recents screen.
     */
    fun selfDestruct(activity: Activity) {
        activity.runOnUiThread {
            try {
                // Closes all activities and removes the task from overview/recents list
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    activity.finishAndRemoveTask()
                } else {
                    activity.finishAffinity()
                }

                // Force terminate the OS process
                android.os.Handler(activity.mainLooper).postDelayed({
                    android.os.Process.killProcess(android.os.Process.myPid())
                    exitProcess(0)
                }, 500)
            } catch (e: Exception) {
                // Absolute fallback
                exitProcess(1)
            }
        }
    }
}
