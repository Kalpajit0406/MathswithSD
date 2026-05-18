package com.example.mathswithsd.data.room

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "announcements")
data class AnnouncementEntity(
    @PrimaryKey val id: String,
    val title: String,
    val message: String,
    val image: String?, // Changed from imageUrl to match repository mappers
    val targetClass: String,
    val createdAt: Long, // Changed to Long for better sorting
    val isRead: Boolean = false
)
