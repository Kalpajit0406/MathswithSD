package com.example.mathswithsd.models

import android.os.Parcelable
import kotlinx.parcelize.Parcelize

@Parcelize
data class Question(
    val _id: String? = null,
    val question: String,
    val options: List<String>,
    val correctAnswer: String,
    val classNo: Int,
    val language: String,
    val chapter: String,
    val diagram: String? = null
) : Parcelable

@Parcelize
data class QuestionResponse(
    val statusCode: Int,
    val success: Boolean,
    val message: String,
    val data: List<Question>
) : Parcelable

@Parcelize
data class SingleQuestionResponse(
    val statusCode: Int,
    val success: Boolean,
    val message: String,
    val data: Question
) : Parcelable

@Parcelize
data class ImageUploadResponse(
    val statusCode: Int,
    val success: Boolean,
    val message: String,
    val data: ImageData
) : Parcelable

@Parcelize
data class ImageData(val url: String) : Parcelable

@Parcelize
data class ScanResponse(
    val statusCode: Int,
    val success: Boolean,
    val message: String,
    val data: List<ScanData>
) : Parcelable

@Parcelize
data class ScanData(
    val questionText: String,
    val options: List<String>,
    val correctAnswer: String?,
    val latex: String? = null,
    val rawText: String? = null
) : Parcelable
