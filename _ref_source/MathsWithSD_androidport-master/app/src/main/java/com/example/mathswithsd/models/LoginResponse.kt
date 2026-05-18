package com.example.mathswithsd.models

data class LoginResponse(
    val statusCode: Int,
    val success: Boolean,
    val message: String,
    val data: LoginData
)

data class LoginData(
    val user: User,
    val role: String,
    val accessToken: String,
    val refreshToken: String
)

data class User(
    val _id: String,
    val firstName: String,
    val lastName: String,
    val studentPhone: String?,
    val role: String?,
    val classNo: Int?,
    val verified: Boolean?,
    val isRejected: Boolean? = false,
    val isBlacklisted: Boolean? = false
)
