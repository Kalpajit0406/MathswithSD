package com.example.mathswithsd.ui

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.mathswithsd.data.repository.TestRepository
import com.example.mathswithsd.data.room.SavedAnswerEntity
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class TestViewModel(
    private val testRepository: TestRepository,
    private val savedStateHandle: SavedStateHandle
) : ViewModel() {

    // Automatically survive process death
    private val _currentQuestionIndex = MutableStateFlow(savedStateHandle.get<Int>("current_index") ?: 0)
    val currentQuestionIndex = _currentQuestionIndex.asStateFlow()

    // Assuming a local data class for UI representation
    data class QuestionUI(val id: String, val text: String, val options: List<String>, val diagram: String? = null)
    private val _questions = MutableStateFlow<List<QuestionUI>>(emptyList())
    val questions = _questions.asStateFlow()

    private val _answers = MutableStateFlow<Map<String, SavedAnswerEntity>>(emptyMap())
    val answers = _answers.asStateFlow()

    private val _timeLeft = MutableStateFlow(0L)
    val timeLeft = _timeLeft.asStateFlow()
    
    private val _isSubmitting = MutableStateFlow(false)
    val isSubmitting = _isSubmitting.asStateFlow()
    
    private var timerJob: Job? = null
    var currentSessionId: String = ""
    var currentTestId: String = ""

    fun startOrResumeTest(testId: String, sessionId: String, studentId: String, durationMins: Int, fetchedQuestions: List<QuestionUI>) {
        currentSessionId = sessionId
        currentTestId = testId
        viewModelScope.launch {
            _questions.value = fetchedQuestions
            
            // Check for crashed session
            val ongoing = testRepository.getOrCreateTestSession(testId, sessionId, studentId, durationMins)
            
            val cachedAnswers = testRepository.getSavedAnswers(sessionId)
            _answers.value = cachedAnswers.associateBy { it.questionId }
            
            startAccurateTimer(ongoing.testStartTimeMillis, ongoing.testDurationMillis)
        }
    }

    private fun startAccurateTimer(startTime: Long, duration: Long) {
        timerJob = viewModelScope.launch {
            while (true) {
                val now = System.currentTimeMillis()
                val elapsed = now - startTime
                val remaining = duration - elapsed

                if (remaining <= 0) {
                    _timeLeft.value = 0
                    if (!_isSubmitting.value) submitTest()
                    break
                } else {
                    _timeLeft.value = remaining
                    delay(1000)
                }
            }
        }
    }

    fun selectAnswer(questionId: String, optionIndex: Int) {
        viewModelScope.launch {
            val answer = SavedAnswerEntity(currentSessionId, questionId, optionIndex, false, System.currentTimeMillis())
            _answers.value += (questionId to answer)
            testRepository.saveAnswer(answer)
        }
    }

    fun markForReview(questionId: String) {
        viewModelScope.launch {
            val existing = _answers.value[questionId]
            val reviewAnswer = existing?.copy(markedForReview = true) ?: SavedAnswerEntity(currentSessionId, questionId, -1, true, System.currentTimeMillis())
            _answers.value += (questionId to reviewAnswer)
            testRepository.saveAnswer(reviewAnswer)
        }
    }

    fun nextQuestion() {
        if (_currentQuestionIndex.value < _questions.value.lastIndex) {
            _currentQuestionIndex.value += 1
            savedStateHandle["current_index"] = _currentQuestionIndex.value
        }
    }

    fun previousQuestion() {
        if (_currentQuestionIndex.value > 0) {
            _currentQuestionIndex.value -= 1
            savedStateHandle["current_index"] = _currentQuestionIndex.value
        }
    }

    fun jumpTo(index: Int) {
        if (index in _questions.value.indices) {
            _currentQuestionIndex.value = index
            savedStateHandle["current_index"] = _currentQuestionIndex.value
        }
    }

    private val _violationCount = MutableStateFlow(0)
    val violationCount = _violationCount.asStateFlow()

    private val _showSecurityWarning = MutableStateFlow(false)
    val showSecurityWarning = _showSecurityWarning.asStateFlow()

    private val _isSecurityLocked = MutableStateFlow(false)
    val isSecurityLocked = _isSecurityLocked.asStateFlow()

    fun onViolationDetected() {
        if (_isSecurityLocked.value || _isSubmitting.value) return

        viewModelScope.launch {
            val current = _violationCount.value
            _violationCount.value = current + 1

            if (current == 0) {
                // First violation -> Show warning
                _showSecurityWarning.value = true
            } else {
                // Second violation -> Auto-submit
                _isSecurityLocked.value = true
                _showSecurityWarning.value = false
                submitTest(isSecurityViolation = true)
            }
        }
    }

    fun dismissWarning() {
        _showSecurityWarning.value = false
    }

    fun submitTest(isSecurityViolation: Boolean = false) {
        if (_isSubmitting.value) return
        timerJob?.cancel()
        
        viewModelScope.launch {
            _isSubmitting.value = true
            
            // 1. Log violation if applicable
            if (isSecurityViolation) {
                android.util.Log.w("TEST_SECURITY", "AUTO-SUBMITTING: Security Violation Detected")
            }

            // 2. Mark in Room
            testRepository.markTestAsSubmitted(currentSessionId)
            
            // 3. API Submission (Simulated)
            delay(1500) 
            _isSubmitting.value = false
        }
    }
}
