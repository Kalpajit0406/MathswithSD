package com.example.mathswithsd.models

data class AnnouncementResponse(
    val _id: String,
    val title: String,
    val message: String,
    val image: String?,
    val targetClass: String,
    val createdAt: String
)

data class CreateAnnouncementRequest(
    val title: String,
    val message: String,
    val image: String?,
    val targetClass: String
)

data class FcmTokenRequest(
    val token: String
)
