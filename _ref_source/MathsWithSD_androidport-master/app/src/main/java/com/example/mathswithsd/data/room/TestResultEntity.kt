package com.example.mathswithsd.data.room

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "test_results")
data class TestResultEntity(
    @PrimaryKey val sessionId: String,
    val testId: String,
    val testTitle: String,
    val score: Int,
    val totalQuestions: Int,
    val timeTakenMillis: Long,
    val completedAt: Long = System.currentTimeMillis()
)
