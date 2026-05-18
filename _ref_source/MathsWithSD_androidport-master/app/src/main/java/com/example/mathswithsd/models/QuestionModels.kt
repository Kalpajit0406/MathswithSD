package com.example.mathswithsd.models

data class Question(
    val _id: String? = null,
    val question: String,
    val options: List<String>,
    val correctAnswer: String,
    val classNo: Int,
    val language: String,
    val chapter: String,
    val diagram: String? = null
)

data class QuestionResponse(
    val statusCode: Int,
    val success: Boolean,
    val message: String,
    val data: List<Question>
)

data class SingleQuestionResponse(
    val statusCode: Int,
    val success: Boolean,
    val message: String,
    val data: Question
)

data class ImageUploadResponse(
    val statusCode: Int,
    val success: Boolean,
    val message: String,
    val data: ImageData
)

data class ImageData(val url: String)

data class ScanResponse(
    val statusCode: Int,
    val success: Boolean,
    val message: String,
    val data: List<ScanData>
)

data class ScanData(
    val questionText: String,
    val options: List<String>,
    val correctAnswer: String?,
    val latex: String? = null,
    val rawText: String? = null
)
