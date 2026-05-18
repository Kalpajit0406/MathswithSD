package com.example.mathswithsd.data.repository

import com.example.mathswithsd.api.ApiService
import com.example.mathswithsd.data.room.ExamDao
import com.example.mathswithsd.data.room.OngoingTestEntity
import com.example.mathswithsd.data.room.SavedAnswerEntity
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow

class TestRepository(
    private val apiService: ApiService,
    private val examDao: ExamDao
) {

    suspend fun getOrCreateTestSession(
        testId: String,
        sessionId: String,
        studentId: String,
        durationMins: Int
    ): OngoingTestEntity {
        var ongoing = examDao.getOngoingTest(sessionId)
        if (ongoing == null) {
            ongoing = OngoingTestEntity(
                testSessionId = sessionId,
                testId = testId,
                studentMobile = studentId,
                testStartTimeMillis = System.currentTimeMillis(),
                testDurationMillis = durationMins * 60 * 1000L
            )
            examDao.saveOngoingTest(ongoing)
        }
        return ongoing
    }

    suspend fun getSavedAnswers(sessionId: String): List<SavedAnswerEntity> {
        return examDao.getAnswers(sessionId)
    }

    suspend fun saveAnswer(answer: SavedAnswerEntity) {
        examDao.saveAnswer(answer)
    }

    suspend fun markTestAsSubmitted(sessionId: String) {
        examDao.markTestAsSubmitted(sessionId)
    }

    suspend fun getAllTests(): Result<List<com.example.mathswithsd.models.TestConfigResponse>> {
        return try {
            val tests = apiService.getAllTests()
            Result.Success(tests)
        } catch (e: Exception) {
            Result.Error("Failed to fetch tests: ${e.message}")
        }
    }
}
