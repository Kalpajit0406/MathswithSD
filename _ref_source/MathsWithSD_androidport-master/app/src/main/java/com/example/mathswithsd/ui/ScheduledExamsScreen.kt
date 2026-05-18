package com.example.mathswithsd.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Event
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.util.*

data class ScheduledTest(val title: String, val date: String, val time: String, val className: String, val medium: String, val timestampMs: Long)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScheduledExamsScreen(onBack: () -> Unit) {
    // Current time for reference
    val currentTime = System.currentTimeMillis()
    val threeDaysMs = 3L * 24 * 60 * 60 * 1000

    // Dummy exams
    val allExams = remember {
        listOf(
            ScheduledTest("Algebra Midterm", "Tomorrow", "10:00 AM", "Class 10", "English", currentTime - 86400000), // Created 1 day ago
            ScheduledTest("Geometry Quiz", "Next Monday", "02:00 PM", "Class 9", "Bengali", currentTime - (4L * 24 * 60 * 60 * 1000)), // Created 4 days ago
            ScheduledTest("Calculus Final", "15/05/2026", "09:00 AM", "Class 12", "Both", currentTime - 10000) // Created recently
        )
    }

    // Filter out notifications older than 3 days
    val upcomingExams = allExams.filter { (currentTime - it.timestampMs) <= threeDaysMs }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Scheduled Exams", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color(0xFF03A9F4), // Light Blue
                    titleContentColor = Color.White,
                    navigationIconContentColor = Color.White
                )
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(bottom = 16.dp)
            ) {
                Icon(Icons.Default.NotificationsActive, contentDescription = null, tint = Color(0xFFFF9800))
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "Upcoming Test Notifications",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFF0277BD)
                )
            }

            if (upcomingExams.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text("No upcoming exams right now.", color = Color.Gray)
                }
            } else {
                LazyColumn(
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(upcomingExams) { exam ->
                        ExamNotificationCard(exam)
                    }
                }
            }
        }
    }
}

@Composable
fun ExamNotificationCard(exam: ScheduledTest) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0xFFE1F5FE))
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Surface(
                shape = RoundedCornerShape(50),
                color = Color(0xFFB3E5FC),
                modifier = Modifier.size(48.dp)
            ) {
                Icon(
                    Icons.Default.Event,
                    contentDescription = null,
                    tint = Color(0xFF0288D1),
                    modifier = Modifier.padding(12.dp)
                )
            }
            Spacer(modifier = Modifier.width(16.dp))
            Column {
                Text(
                    text = exam.title,
                    fontWeight = FontWeight.Bold,
                    fontSize = 18.sp,
                    color = Color(0xFF01579B)
                )
                Text(
                    text = "Date: ${exam.date} | Time: ${exam.time}",
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color.DarkGray
                )
                Text(
                    text = "${exam.className} • ${exam.medium} Medium",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color(0xFF0277BD),
                    fontWeight = FontWeight.SemiBold
                )
            }
        }
    }
}
