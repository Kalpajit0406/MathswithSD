package com.example.mathswithsd

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.MotionEvent
import android.view.WindowManager
import android.widget.Toast
import java.io.File

class OverlayDetector(private val activity: Activity) {

    companion object {
        private const val OVERLAY_PERMISSION_REQ_CODE = 5469
    }

    /**
     * Checks if the touch event is obscured by another window (Tapjacking).
     * Discards the touch and terminates the app if tapjacking is detected.
     */
    fun checkTouchEventForOverlay(event: MotionEvent): Boolean {
        val isObscured = (event.flags and MotionEvent.FLAG_WINDOW_IS_OBSCURED) != 0
        val isPartiallyObscured = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            (event.flags and MotionEvent.FLAG_WINDOW_IS_PARTIALLY_OBSCURED) != 0
        } else {
            false
        }

        if (isObscured || isPartiallyObscured) {
            terminateApp("Security Violation: Screen overlay detected. App is closing.")
            return true
        }
        return false
    }

    /**
     * Modern Android 12+ (API 31) overlay security feature.
     * Tells the system to hide all non-system overlay windows when this app is in the foreground.
     */
    fun applyModernOverlayProtection() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                activity.window.setHideOverlayWindows(true)
            } catch (e: Exception) {
                // Logging / fail-safe
            }
        }
    }

    /**
     * Checks if the app has permission to draw overlays (useful if the app itself
     * needs to check overlay statuses or guide the user).
     */
    fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(activity)
        } else {
            true
        }
    }

    /**
     * Guides the user to the system "Draw over other apps" settings page
     * if the permission is required but not granted.
     */
    fun launchOverlaySettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${activity.packageName}")
            )
            activity.startActivityForResult(intent, OVERLAY_PERMISSION_REQ_CODE)
        }
    }

    /**
     * Safe termination logic: finishes the active activity and kills the application process
     * cleanly when an overlay is detected to prevent further UI exposure.
     */
    fun terminateApp(reason: String) {
        activity.runOnUiThread {
            Toast.makeText(activity, reason, Toast.LENGTH_LONG).show()
            
            // Clean exit
            activity.finishAffinity() // Closes all activities in the stack
            
            // Kill process after short delay to let Toast display
            android.os.Handler(activity.mainLooper).postDelayed({
                android.os.Process.killProcess(android.os.Process.myPid())
                System.exit(0)
            }, 1000)
        }
    }
}
