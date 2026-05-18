package com.example.mathswithsd.data.room

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "ongoing_tests")
data class OngoingTestEntity(
    @PrimaryKey val testSessionId: String,
    val testId: String,
    val studentMobile: String,
    val testStartTimeMillis: Long,
    val testDurationMillis: Long,
    val isSubmitted: Boolean = false
)
