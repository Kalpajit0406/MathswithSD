package com.example.mathswithsd.data.worker

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.example.mathswithsd.api.RetrofitClient
import com.example.mathswithsd.data.room.ExamDatabase
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class TestSubmitWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val testId = inputData.getString("TEST_ID") ?: return@withContext Result.failure()
        val sessionToken = inputData.getString("SESSION_TOKEN") ?: return@withContext Result.failure()
        val studentId = inputData.getString("STUDENT_ID") ?: return@withContext Result.failure()

        // Because we don't have dependency injection setup yet, we manually get the DB
        // You'll need to pass the Database Builder instance or setup Dagger/Hilt
        // For now, this is a placeholder structural representation:
        /*
        val db = Room.databaseBuilder(
            applicationContext,
            ExamDatabase::class.java, "exam-database"
        ).build()
        
        val dao = db.examDao()
        val cachedAnswers = dao.getAnswers(testId)
        
        if (cachedAnswers.isEmpty()) return@withContext Result.success()

        val responsePayload = cachedAnswers.map {
            mapOf(
                "questionId" to it.questionId,
                "selectedOption" to it.selectedOptionIndex
            )
        }

        try {
            val api = RetrofitClient.create(applicationContext)
            val response = api.saveStudentTest(
                mapOf(
                    "testId" to testId,
                    "studentMobile" to studentId,
                    "sessionToken" to sessionToken,
                    "responses" to responsePayload,
                    "date" to "TODO",
                    "time" to "TODO"
                )
            ).execute()

            if (response.isSuccessful) {
                dao.clearAnswers(testId)
                dao.clearOngoingTest(testId)
                return@withContext Result.success()
            } else {
                return@withContext Result.retry() // Retry if server returns 500
            }
        } catch (e: Exception) {
            return@withContext Result.retry() // Retry if no internet
        }
        */
        Result.success()
    }
}
