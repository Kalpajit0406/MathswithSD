package com.example.mathswithsd.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
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
fun AdminDashboard(
    onLogout: () -> Unit,
    onNavigateToManageStudents: () -> Unit,
    onNavigateToStudentDashboard: () -> Unit,
    onNavigateToCreateTest: () -> Unit,
    onNavigateToYourTests: () -> Unit,
    onNavigateToAnnouncements: () -> Unit
) {
    var selectedTab by androidx.compose.runtime.saveable.rememberSaveable { mutableStateOf(0) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { 
                    Text(
                        if (selectedTab == 0) "Teacher Dashboard" else "Create Question", 
                        fontWeight = FontWeight.Bold 
                    ) 
                },
                actions = {
                    if (selectedTab == 0) {
                        IconButton(onClick = onNavigateToStudentDashboard) {
                            Icon(Icons.Default.SwapHoriz, contentDescription = "Switch to Student View")
                        }
                        IconButton(onClick = onLogout) {
                            Icon(Icons.Default.Logout, contentDescription = "Logout")
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color(0xFFE0F7FA),
                    titleContentColor = Color(0xFF006064)
                )
            )
        },
        bottomBar = {
            NavigationBar(
                containerColor = Color.White,
                tonalElevation = 8.dp
            ) {
                NavigationBarItem(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    icon = { Icon(Icons.Default.Dashboard, contentDescription = "Home") },
                    label = { Text("Overview") },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = Color(0xFF006064),
                        selectedTextColor = Color(0xFF006064),
                        indicatorColor = Color(0xFFE0F7FA)
                    )
                )
                NavigationBarItem(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    icon = { Icon(Icons.Default.AddCircle, contentDescription = "Create") },
                    label = { Text("Create") },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = Color(0xFF673AB7),
                        selectedTextColor = Color(0xFF673AB7),
                        indicatorColor = Color(0xFFEDE7F6)
                    )
                )
            }
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            if (selectedTab == 0) {
                AdminOverviewContent(
                    onNavigateToManageStudents = onNavigateToManageStudents,
                    onNavigateToCreateTest = onNavigateToCreateTest,
                    onNavigateToYourTests = onNavigateToYourTests,
                    onNavigateToAnnouncements = onNavigateToAnnouncements
                )
            } else {
                CreateQuestionTab()
            }
        }
    }
}

@Composable
fun AdminOverviewContent(
    onNavigateToManageStudents: () -> Unit,
    onNavigateToCreateTest: () -> Unit,
    onNavigateToYourTests: () -> Unit,
    onNavigateToAnnouncements: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                brush = Brush.verticalGradient(
                    colors = listOf(Color(0xFFE0F7FA), Color(0xFFFFFFFF))
                )
            )
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
                colors = CardDefaults.cardColors(containerColor = Color(0xFF00BCD4)),
                elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
            ) {
                Column(
                    modifier = Modifier
                        .padding(24.dp)
                        .fillMaxWidth(),
                    horizontalAlignment = Alignment.Start
                ) {
                    Text(
                        text = "Welcome, Teacher!",
                        style = MaterialTheme.typography.headlineMedium,
                        color = Color.White,
                        fontWeight = FontWeight.ExtraBold
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "Manage your students, create tests, and organize questions all in one place.",
                        style = MaterialTheme.typography.bodyLarge,
                        color = Color(0xFFE0F7FA)
                    )
                }
            }

            Text(
                text = "Quick Actions",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF006064),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 16.dp)
            )

            // Grid of actions
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                AdminActionCard(
                    title = "Manage Students",
                    icon = Icons.Default.PeopleAlt,
                    color = Color(0xFF009688), // Teal
                    modifier = Modifier.weight(1f),
                    onClick = onNavigateToManageStudents
                )
                AdminActionCard(
                    title = "Make Tests",
                    icon = Icons.Default.Quiz,
                    color = Color(0xFF673AB7), // Deep Purple
                    modifier = Modifier.weight(1f),
                    onClick = onNavigateToCreateTest
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                AdminActionCard(
                    title = "Saved Questions",
                    icon = Icons.Default.LibraryBooks,
                    color = Color(0xFFFF9800), // Orange
                    modifier = Modifier.weight(1f),
                    onClick = { /* Navigate via Tab */ }
                )
                AdminActionCard(
                    title = "Your Tests",
                    icon = Icons.Default.FactCheck,
                    color = Color(0xFFE91E63), // Pink
                    modifier = Modifier.weight(1f),
                    onClick = onNavigateToYourTests
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                AdminActionCard(
                    title = "Announcements",
                    icon = Icons.Default.Campaign,
                    color = Color(0xFF1565C0), // Blue
                    modifier = Modifier.weight(1f),
                    onClick = onNavigateToAnnouncements
                )
                Spacer(modifier = Modifier.weight(1f))
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminActionCard(title: String, icon: ImageVector, color: Color, modifier: Modifier = Modifier, onClick: () -> Unit) {
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
