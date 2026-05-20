package com.example.mathswithsd.models

data class RegisterRequest(
    val firstName: String,
    val lastName: String,
    val dateOfBirth: String,
    val gender: String,
    val classNo: Int,
    val language: String,
    val fatherName: String,
    val studentPhone: String,
    val guardianPhone: String,
    val password: String
)
