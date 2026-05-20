package com.example.mathswithsd.api

import com.example.mathswithsd.models.AnnouncementResponse
import com.example.mathswithsd.models.CreateAnnouncementRequest
import com.example.mathswithsd.models.FcmTokenRequest
import com.example.mathswithsd.models.LoginRequest
import com.example.mathswithsd.models.LoginResponse
import com.example.mathswithsd.models.RegisterRequest
import okhttp3.ResponseBody
import retrofit2.Call
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Query

interface ApiService {

    @POST("api/v1/student/register")
    suspend fun register(@Body request: RegisterRequest): Response<ResponseBody>

    @POST("api/v1/student/login")
    suspend fun login(@Body request: LoginRequest): LoginResponse

    @GET("api/v1/question/questions")
    fun getQuestions(): Call<List<Any>>

    @POST("api/v1/tests")
    suspend fun createTest(@Body request: com.example.mathswithsd.models.CreateTestRequest): okhttp3.ResponseBody

    @GET("api/v1/tests")
    suspend fun getAllTests(): List<com.example.mathswithsd.models.TestConfigResponse>

    // Announcements
    @GET("api/v1/announcements")
    suspend fun getAnnouncements(@Query("targetClass") targetClass: String? = null): List<AnnouncementResponse>

    @POST("api/v1/announcements/admin")
    suspend fun createAnnouncement(@Body request: CreateAnnouncementRequest): AnnouncementResponse

    // FCM Token registration
    @POST("api/v1/student/save-token")
    suspend fun registerFcmToken(@Body request: FcmTokenRequest): Response<ResponseBody>

    // Question Bank
    @GET("api/v1/question/questions")
    suspend fun getQuestions(
        @Query("classNo") classNo: Int?,
        @Query("language") language: String?
    ): com.example.mathswithsd.models.QuestionResponse

    @POST("api/v1/question/create")
    suspend fun createQuestion(@Body question: com.example.mathswithsd.models.Question): com.example.mathswithsd.models.SingleQuestionResponse

    @retrofit2.http.Multipart
    @POST("api/v1/upload")
    suspend fun uploadImage(@retrofit2.http.Part file: okhttp3.MultipartBody.Part): com.example.mathswithsd.models.ImageUploadResponse

    @POST("api/v1/ocr/process-text")
    suspend fun processOcrText(@Body request: Map<String, String>): com.example.mathswithsd.models.ScanResponse

    // Student Management
    @GET("api/v1/student/students")
    suspend fun getAllStudents(): com.example.mathswithsd.models.StudentListResponse

    @retrofit2.http.PUT("api/v1/student/accept/{id}")
    suspend fun acceptStudent(@retrofit2.http.Path("id") id: String): Response<ResponseBody>

    @retrofit2.http.DELETE("api/v1/student/reject/{id}")
    suspend fun rejectStudent(@retrofit2.http.Path("id") id: String): Response<ResponseBody>
}

