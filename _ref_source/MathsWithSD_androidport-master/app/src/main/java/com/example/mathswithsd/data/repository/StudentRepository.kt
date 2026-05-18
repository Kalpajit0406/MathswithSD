package com.example.mathswithsd.data.repository

import com.example.mathswithsd.api.ApiService
import com.example.mathswithsd.models.User
import okhttp3.ResponseBody
import retrofit2.Response

class StudentRepository(private val apiService: ApiService) {

    suspend fun getAllStudents(): Result<Triple<List<User>, List<User>, List<User>>> {
        return try {
            val response = apiService.getAllStudents()
            if (response.success) {
                Result.Success(Triple(
                    response.unverified ?: emptyList(),
                    response.verified ?: emptyList(),
                    response.rejected ?: emptyList()
                ))
            } else {
                Result.Error(response.message ?: "Failed to fetch students")
            }
        } catch (e: Exception) {
            Result.Error(e.message ?: "Failed to fetch students")
        }
    }

    suspend fun acceptStudent(id: String): Result<String> {
        return try {
            val response = apiService.acceptStudent(id)
            if (response.isSuccessful) {
                Result.Success("Student accepted successfully")
            } else {
                Result.Error("Failed to accept student: ${response.code()}")
            }
        } catch (e: Exception) {
            Result.Error(e.message ?: "Error accepting student")
        }
    }

    suspend fun rejectStudent(id: String): Result<String> {
        return try {
            val response = apiService.rejectStudent(id)
            if (response.isSuccessful) {
                Result.Success("Student rejected successfully")
            } else {
                Result.Error("Failed to reject student: ${response.code()}")
            }
        } catch (e: Exception) {
            Result.Error(e.message ?: "Error rejecting student")
        }
    }
}
