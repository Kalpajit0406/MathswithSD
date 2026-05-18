package com.example.mathswithsd.data.repository

import com.example.mathswithsd.api.ApiService
import com.example.mathswithsd.models.Question
import okhttp3.MultipartBody

class QuestionRepository(private val apiService: ApiService) {

    suspend fun getQuestions(classNo: Int?, language: String?): Result<List<Question>> {
        return try {
            val response = apiService.getQuestions(classNo, language)
            if (response.success) {
                Result.Success(response.data)
            } else {
                Result.Error(response.message)
            }
        } catch (e: Exception) {
            Result.Error(e.message ?: "Failed to fetch questions")
        }
    }

    suspend fun createQuestion(question: Question): Result<Question> {
        return try {
            val response = apiService.createQuestion(question)
            if (response.success) {
                Result.Success(response.data)
            } else {
                Result.Error(response.message)
            }
        } catch (e: Exception) {
            Result.Error(e.message ?: "Failed to create question")
        }
    }

    suspend fun uploadImage(file: MultipartBody.Part): Result<String> {
        return try {
            val response = apiService.uploadImage(file)
            if (response.success) {
                Result.Success(response.data.url)
            } else {
                Result.Error(response.message)
            }
        } catch (e: Exception) {
            Result.Error(e.message ?: "Image upload failed")
        }
    }

    suspend fun processOcrText(rawText: String): Result<List<com.example.mathswithsd.models.ScanData>> {
        return try {
            val response = apiService.processOcrText(mapOf("rawText" to rawText))
            if (response.success) {
                Result.Success(response.data)
            } else {
                Result.Error(response.message)
            }
        } catch (e: Exception) {
            Result.Error(e.message ?: "Processing failed")
        }
    }
}
