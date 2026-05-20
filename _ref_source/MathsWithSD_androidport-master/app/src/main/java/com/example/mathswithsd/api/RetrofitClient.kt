package com.example.mathswithsd.api

import android.content.Context
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.Response
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.io.IOException

object RetrofitClient {

    // Use 10.0.2.2 for Android Emulator to connect to localhost. 
    // If using a physical phone over Wi-Fi, replace this with your computer's IPv4 address (e.g. "http://192.168.1.5:5000/")
    private const val BASE_URL = "https://visa-boasting-desolate.ngrok-free.dev/"

    fun create(context: Context): ApiService {
        val authManager = AuthManager(context)

        val logging = HttpLoggingInterceptor { message ->
            android.util.Log.d("API_LOG", message)
        }.apply {
            level = HttpLoggingInterceptor.Level.BODY
        }

        val retryInterceptor = Interceptor { chain ->
            var request = chain.request()
            var response: Response? = null
            var exception: IOException? = null
            var tryCount = 0
            val maxLimit = 3

            while (tryCount < maxLimit && (response == null || !response.isSuccessful)) {
                try {
                    response?.close() // Ensure we close the previous response body before retrying
                    response = chain.proceed(request)
                    if (response.isSuccessful) break
                } catch (e: IOException) {
                    exception = e
                }
                tryCount++
                if (tryCount < maxLimit) {
                    Thread.sleep((1000 * Math.pow(2.0, tryCount.toDouble())).toLong()) // Exponential backoff
                }
            }

            response ?: throw exception ?: IOException("Unknown network error")
        }

        val httpClient = OkHttpClient.Builder()
            .addInterceptor(logging)
            .addInterceptor(retryInterceptor)
            .addInterceptor { chain ->
                val requestBuilder = chain.request().newBuilder()
                    .addHeader("ngrok-skip-browser-warning", "true")

                authManager.getToken()?.let { token ->
                    requestBuilder.addHeader("Authorization", "Bearer $token")
                }

                val request = requestBuilder.build()
                chain.proceed(request)
            }
            .build()

        return Retrofit.Builder()
            .baseUrl(BASE_URL)
            .client(httpClient)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(ApiService::class.java)
    }

    // Overloaded instance for use without context (less ideal)
    val instance: ApiService by lazy {
        throw IllegalStateException("RetrofitClient.instance should not be used. Use RetrofitClient.create(context) instead.")
    }
}
