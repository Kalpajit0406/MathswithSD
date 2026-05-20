package com.example.mathswithsd.data.repository

import com.example.mathswithsd.api.ApiService
import com.example.mathswithsd.api.AuthManager
import com.example.mathswithsd.models.LoginRequest
import retrofit2.HttpException

class AuthRepository(
    private val apiService: ApiService,
    private val authManager: AuthManager
) {
    suspend fun login(mobile: String, password: String): Result<String> {
        return try {
            val response = apiService.login(LoginRequest(mobile, password))
            if (response.data != null) {
                authManager.saveToken(response.data.accessToken)
                
                val isAdmin = response.data.role.lowercase() == "admin" || response.data.role.lowercase() == "teacher"
                authManager.saveUserRole(isAdmin)
                authManager.saveUserPhone(response.data.user.studentPhone ?: mobile)
                authManager.saveUserClass(response.data.user.classNo ?: 0)
                
                Result.Success("Login successful")
            } else {
                Result.Error("Login failed: Invalid response from server")
            }
        } catch (e: HttpException) {
            val errorBody = e.response()?.errorBody()?.string()
            Result.Error("Login failed: ${e.message()} ($errorBody)")
        } catch (e: Exception) {
            Result.Error("Connection error: ${e.message ?: "Unknown error"}. Ensure backend is running.")
        }
    }
}
