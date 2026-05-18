package com.example.mathswithsd.models

data class StudentListResponse(
    val success: Boolean,
    val verified: List<User>?,
    val unverified: List<User>?,
    val rejected: List<User>?,
    val message: String? = null
)
