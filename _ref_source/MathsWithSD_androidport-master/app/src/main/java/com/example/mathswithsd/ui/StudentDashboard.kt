package com.example.mathswithsd.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StudentDashboard(
    onLogout: () -> Unit,
    onNavigateToAdminDashboard: () -> Unit,
    onNavigateToScheduledExams: () -> Unit,
    onNavigateToAnnouncements: () -> Unit
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Student Dashboard", fontWeight = FontWeight.Bold) },
                actions = {
                    IconButton(onClick = onNavigateToAdminDashboard) {
                        Icon(Icons.Default.SwapHoriz, contentDescription = "Switch to Teacher View")
                    }
                    IconButton(onClick = onLogout) {
                        Icon(Icons.Default.Logout, contentDescription = "Logout")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color(0xFFF3E5F5), // Light Purple
                    titleContentColor = Color(0xFF4A148C) // Dark Purple
                )
            )
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    brush = Brush.verticalGradient(
                        colors = listOf(Color(0xFFF3E5F5), Color(0xFFFFFFFF))
                    )
                )
                .padding(padding)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                // Welcome Banner
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 32.dp),
                    shape = RoundedCornerShape(24.dp),
                    colors = CardDefaults.cardColors(containerColor = Color(0xFF9C27B0)), // Purple
                    elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
                ) {
                    Column(
                        modifier = Modifier
                            .padding(24.dp)
                            .fillMaxWidth(),
                        horizontalAlignment = Alignment.Start
                    ) {
                        Text(
                            text = "Welcome, Student!",
                            style = MaterialTheme.typography.headlineMedium,
                            color = Color.White,
                            fontWeight = FontWeight.ExtraBold
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "Your account is verified. Ready to ace your exams?",
                            style = MaterialTheme.typography.bodyLarge,
                            color = Color(0xFFF3E5F5)
                        )
                    }
                }

                Text(
                    text = "My Learning",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFF4A148C),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 16.dp)
                )

                // Grid of actions
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    StudentActionCard(
                        title = "Announcements",
                        icon = Icons.Default.Campaign,
                        color = Color(0xFFFF5722), // Deep Orange
                        modifier = Modifier.weight(1f),
                        onClick = onNavigateToAnnouncements
                    )
                    StudentActionCard(
                        title = "Scheduled Exams",
                        icon = Icons.Default.EventNote,
                        color = Color(0xFF03A9F4), // Light Blue
                        modifier = Modifier.weight(1f),
                        onClick = onNavigateToScheduledExams
                    )
                }

                Spacer(modifier = Modifier.height(16.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    StudentActionCard(
                        title = "Take Exam",
                        icon = Icons.Default.PlayCircleFilled,
                        color = Color(0xFF4CAF50), // Green
                        modifier = Modifier.weight(1f),
                        onClick = { /* TODO: Navigate to Take Exam */ }
                    )
                    StudentActionCard(
                        title = "My Results",
                        icon = Icons.Default.Score,
                        color = Color(0xFFFFC107), // Amber
                        modifier = Modifier.weight(1f),
                        onClick = { /* TODO: Navigate to Results */ }
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StudentActionCard(title: String, icon: ImageVector, color: Color, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Card(
        modifier = modifier.height(140.dp),
        shape = RoundedCornerShape(20.dp),
        onClick = onClick,
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 6.dp, pressedElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Surface(
                shape = RoundedCornerShape(16.dp),
                color = color.copy(alpha = 0.1f),
                modifier = Modifier.size(56.dp)
            ) {
                Box(contentAlignment = Alignment.Center, modifier = Modifier.fillMaxSize()) {
                    Icon(
                        imageVector = icon,
                        contentDescription = title,
                        modifier = Modifier.size(32.dp),
                        tint = color
                    )
                }
            }
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = Color.DarkGray,
                maxLines = 1
            )
        }
    }
}
