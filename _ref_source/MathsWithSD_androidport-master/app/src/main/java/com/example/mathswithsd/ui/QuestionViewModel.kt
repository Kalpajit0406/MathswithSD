package com.example.mathswithsd.ui

import android.app.Application
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.mathswithsd.api.RetrofitClient
import com.example.mathswithsd.data.repository.QuestionRepository
import com.example.mathswithsd.data.repository.Result
import com.example.mathswithsd.models.Question
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.asRequestBody
import java.io.File

class QuestionViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = QuestionRepository(RetrofitClient.create(application))

    private val _isUploading = MutableStateFlow(false)
    val isUploading = _isUploading.asStateFlow()

    private val _isScanning = MutableStateFlow(false)
    val isScanning = _isScanning.asStateFlow()

    private val _scanResult = MutableStateFlow<com.example.mathswithsd.models.ScanData?>(null)
    val scanResult = _scanResult.asStateFlow()

    private val _questionQueue = MutableStateFlow<List<com.example.mathswithsd.models.ScanData>>(emptyList())
    val questionQueue = _questionQueue.asStateFlow()

    fun nextQuestion() {
        if (_questionQueue.value.isNotEmpty()) {
            val newList = _questionQueue.value.toMutableList()
            newList.removeAt(0)
            _questionQueue.value = newList
            _scanResult.value = newList.firstOrNull()
        } else {
            _scanResult.value = null
        }
    }

    private val _diagramUrl = MutableStateFlow<String?>(null)
    val diagramUrl = _diagramUrl.asStateFlow()

    private val _creationStatus = MutableStateFlow<Result<Question>?>(null)
    val creationStatus = _creationStatus.asStateFlow()

    fun uploadImage(file: File) {
        viewModelScope.launch {
            _isUploading.value = true
            val requestFile = file.asRequestBody("image/*".toMediaTypeOrNull())
            val body = MultipartBody.Part.createFormData("file", file.name, requestFile)
            
            when (val result = repository.uploadImage(body)) {
                is Result.Success -> _diagramUrl.value = result.data
                is Result.Error -> { /* Handle Error */ }
                is Result.Loading -> {}
            }
            _isUploading.value = false
        }
    }

    fun scanQuestion(bitmap: android.graphics.Bitmap) {
        viewModelScope.launch {
            _isScanning.value = true
            _scanResult.value = null // Reset previous result
            
            android.util.Log.d("OCR_DEBUG", "Starting local OCR...")
            // 1. Local OCR with ML Kit
            val rawText = com.example.mathswithsd.util.OcrManager.extractTextFromBitmap(bitmap)
            
            android.util.Log.d("OCR_DEBUG", "Raw Text Extracted: $rawText")
            
            if (rawText.isBlank()) {
                android.util.Log.e("OCR_DEBUG", "No text found in image")
                android.widget.Toast.makeText(getApplication(), "Could not find any text in image. Try a clearer photo.", android.widget.Toast.LENGTH_LONG).show()
                _isScanning.value = false
                return@launch
            }

            // 2. Process with Gemini via Backend
            android.util.Log.d("OCR_DEBUG", "Sending to backend for Gemini processing...")
            when (val result = repository.processOcrText(rawText)) {
                is Result.Success -> {
                    android.util.Log.d("OCR_DEBUG", "Success! Found ${result.data.size} questions")
                    _questionQueue.value = result.data
                    _scanResult.value = result.data.firstOrNull()
                }
                is Result.Error -> {
                    android.util.Log.e("OCR_DEBUG", "Backend Error: ${result.message}")
                }
                is Result.Loading -> {}
            }
            _isScanning.value = false
        }
    }

    fun createQuestion(
        questionText: String,
        options: List<String>,
        correctAnswer: String,
        classNo: Int,
        language: String,
        chapter: String
    ) {
        viewModelScope.launch {
            _creationStatus.value = Result.Loading
            val question = Question(
                question = questionText,
                options = options,
                correctAnswer = correctAnswer,
                classNo = classNo,
                language = language,
                chapter = chapter,
                diagram = _diagramUrl.value
            )
            _creationStatus.value = repository.createQuestion(question)
        }
    }

    fun resetStatus() {
        _creationStatus.value = null
        _scanResult.value = null
    }
}
