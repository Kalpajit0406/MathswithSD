package com.example.mathswithsd.data.room

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query

@Dao
interface ExamDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun saveAnswer(answer: SavedAnswerEntity)

    @Query("SELECT * FROM saved_answers WHERE testSessionId = :sessionId")
    suspend fun getAnswers(sessionId: String): List<SavedAnswerEntity>

    @Query("DELETE FROM saved_answers WHERE testSessionId = :sessionId")
    suspend fun clearAnswers(sessionId: String)
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun saveOngoingTest(test: OngoingTestEntity)
    
    @Query("SELECT * FROM ongoing_tests WHERE testSessionId = :sessionId LIMIT 1")
    suspend fun getOngoingTest(sessionId: String): OngoingTestEntity?
    
    @Query("DELETE FROM ongoing_tests WHERE testSessionId = :sessionId")
    suspend fun clearOngoingTest(sessionId: String)
    
    @Query("UPDATE ongoing_tests SET isSubmitted = 1 WHERE testSessionId = :sessionId")
    suspend fun markTestAsSubmitted(sessionId: String)
}
