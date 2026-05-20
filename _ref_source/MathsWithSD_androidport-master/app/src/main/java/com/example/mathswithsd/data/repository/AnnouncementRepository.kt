package com.example.mathswithsd.data.repository

import com.example.mathswithsd.api.ApiService
import com.example.mathswithsd.data.room.AnnouncementDao
import com.example.mathswithsd.data.room.AnnouncementEntity
import com.example.mathswithsd.models.AnnouncementResponse
import com.example.mathswithsd.models.CreateAnnouncementRequest
import com.example.mathswithsd.models.FcmTokenRequest

class AnnouncementRepository(
    private val apiService: ApiService,
    private val announcementDao: AnnouncementDao
) {

    /**
     * Fetches announcements from backend and caches them in Room.
     * Returns cached data immediately while refreshing, then the remote list.
     */
    suspend fun getAnnouncements(targetClass: String? = null): Result<List<AnnouncementResponse>> {
        return try {
            val remote = apiService.getAnnouncements(targetClass)
            // Refresh cache
            announcementDao.clearAnnouncements()
            announcementDao.insertAnnouncements(remote.map { it.toEntity() })
            Result.Success(remote)
        } catch (e: Exception) {
            // Serve from cache on error
            val cached = announcementDao.getAllAnnouncements()
            if (cached.isNotEmpty()) {
                Result.Success(cached.map { it.toResponse() })
            } else {
                Result.Error("Failed to load announcements: ${e.message}")
            }
        }
    }

    suspend fun createAnnouncement(
        title: String,
        message: String,
        image: String?,
        targetClass: String
    ): Result<AnnouncementResponse> {
        return try {
            val response = apiService.createAnnouncement(
                CreateAnnouncementRequest(title, message, image, targetClass)
            )
            Result.Success(response)
        } catch (e: Exception) {
            Result.Error("Failed to create announcement: ${e.message}")
        }
    }

    suspend fun registerFcmToken(token: String): Result<Unit> {
        return try {
            apiService.registerFcmToken(FcmTokenRequest(token))
            Result.Success(Unit)
        } catch (e: Exception) {
            Result.Error("Failed to register FCM token: ${e.message}")
        }
    }

    // --- Mappers ---

    private fun AnnouncementResponse.toEntity() = AnnouncementEntity(
        id = _id,
        title = title,
        message = message,
        image = image,
        targetClass = targetClass,
        createdAt = try { 
            if (createdAt != null) {
                java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US)
                    .parse(createdAt)?.time ?: System.currentTimeMillis()
            } else {
                System.currentTimeMillis()
            }
        } catch (e: Exception) { System.currentTimeMillis() }
    )

    private fun AnnouncementEntity.toResponse() = AnnouncementResponse(
        _id = id,
        title = title,
        message = message,
        image = image,
        targetClass = targetClass,
        createdAt = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.US)
            .format(java.util.Date(createdAt))
    )
}
