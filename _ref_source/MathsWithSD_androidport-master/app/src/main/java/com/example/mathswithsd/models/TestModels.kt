package com.example.mathswithsd.models

data class CreateTestRequest(
    val date: String,
    val time: String,
    val classNo: Int,
    val language: String,
    val totalQuestions: Int,
    val totalTime: Int
)

data class TestConfigResponse(
    val _id: String,
    val date: String,
    val time: String,
    val classNo: Int,
    val language: String,
    val totalQuestions: Int,
    val totalTime: Int
)
