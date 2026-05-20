package com.example.mathswithsd.fcm

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.example.mathswithsd.MainActivity
import com.example.mathswithsd.api.RetrofitClient
import com.example.mathswithsd.data.room.AnnouncementEntity
import com.example.mathswithsd.data.room.ExamDatabase
import com.example.mathswithsd.models.FcmTokenRequest
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class MyFirebaseMessagingService : FirebaseMessagingService() {

    private val job = SupervisorJob()
    private val scope = CoroutineScope(Dispatchers.IO + job)

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d("FCM", "New token generated: $token")
        // Send token to backend
        scope.launch {
            try {
                val api = RetrofitClient.create(applicationContext)
                api.registerFcmToken(FcmTokenRequest(token))
                Log.d("FCM", "Token successfully registered with backend")
            } catch (e: Exception) {
                Log.e("FCM", "Failed to register token: ${e.message}")
            }
        }
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)
        Log.d("FCM", "Message received from: ${message.from}")
        
        val title = message.notification?.title ?: message.data["title"] ?: "New Announcement"
        val body = message.notification?.body ?: message.data["message"] ?: ""
        val announcementId = message.data["id"]
        val image = message.data["image"]
        val targetClass = message.data["targetClass"] ?: "All"
        val createdAtStr = message.data["createdAt"]
        
        val createdAt = try {
            createdAtStr?.toLong() ?: System.currentTimeMillis()
        } catch (e: Exception) {
            System.currentTimeMillis()
        }

        // 1. Save to Room DB if we have an ID
        if (announcementId != null) {
            scope.launch {
                try {
                    val db = ExamDatabase.getDatabase(applicationContext)
                    db.announcementDao().insertAnnouncement(
                        AnnouncementEntity(
                            id = announcementId,
                            title = title,
                            message = body,
                            image = image,
                            targetClass = targetClass,
                            createdAt = createdAt
                        )
                    )
                    Log.d("FCM", "Announcement saved to Room DB")
                } catch (e: Exception) {
                    Log.e("FCM", "Error saving announcement to DB: ${e.message}")
                }
            }
        }

        // 2. Show actual notification
        showNotification(title, body)
    }

    private fun showNotification(title: String, body: String) {
        val channelId = "announcements_channel"
        val notifManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Announcements",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Class announcements and updates"
                enableLights(true)
                enableVibration(true)
            }
            notifManager.createNotificationChannel(channel)
        }

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("navigate_to", "ANNOUNCEMENTS")
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .build()

        notifManager.notify(System.currentTimeMillis().toInt(), notification)
    }

    override fun onDestroy() {
        job.cancel()
        super.onDestroy()
    }
}
