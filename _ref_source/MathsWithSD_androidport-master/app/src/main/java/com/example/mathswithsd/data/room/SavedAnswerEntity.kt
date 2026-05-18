package com.example.mathswithsd.data.room

import androidx.room.Entity

@Entity(tableName = "saved_answers", primaryKeys = ["testSessionId", "questionId"])
data class SavedAnswerEntity(
    val testSessionId: String,
    val questionId: String,
    val selectedOptionIndex: Int,
    val markedForReview: Boolean,
    val timestamp: Long
)
