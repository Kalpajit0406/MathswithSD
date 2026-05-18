package com.example.mathswithsd.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

data class LeaderboardEntry(val name: String, val score: Int, val timeTaken: String)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LeaderboardScreen(onBack: () -> Unit) {
    // Dummy Data for now
    val leaderboard = listOf(
        LeaderboardEntry("Kalpajit Bepary", 95, "12:45"),
        LeaderboardEntry("Alice Smith", 92, "14:20"),
        LeaderboardEntry("John Doe", 88, "13:10"),
        LeaderboardEntry("Rahul Kumar", 85, "15:00"),
        LeaderboardEntry("Sara Khan", 82, "11:50")
    )

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Leaderboard", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color(0xFFFFD700), // Gold
                    titleContentColor = Color.Black,
                    navigationIconContentColor = Color.Black
                )
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            // Top 3 Podium (Simplified)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(24.dp),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.Bottom
            ) {
                PodiumItem(name = "Alice", rank = 2, color = Color(0xFFC0C0C0)) // Silver
                PodiumItem(name = "Kalpajit", rank = 1, color = Color(0xFFFFD700)) // Gold
                PodiumItem(name = "John", rank = 3, color = Color(0xFFCD7F32)) // Bronze
            }

            Text(
                text = "Global Rankings",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(16.dp)
            )

            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                itemsIndexed(leaderboard) { index, entry ->
                    LeaderboardCard(rank = index + 1, entry = entry)
                }
            }
        }
    }
}

@Composable
fun PodiumItem(name: String, rank: Int, color: Color) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(Icons.Default.EmojiEvents, contentDescription = null, tint = color, modifier = Modifier.size(48.dp))
        Text(name, fontWeight = FontWeight.Bold, fontSize = 14.sp)
        Surface(
            modifier = Modifier.width(60.dp).height(if (rank == 1) 80.dp else 50.dp),
            color = color,
            shape = RoundedCornerShape(topStart = 8.dp, topEnd = 8.dp)
        ) {
            Box(contentAlignment = Alignment.Center) {
                Text("#$rank", fontWeight = FontWeight.Bold, color = Color.White)
            }
        }
    }
}

@Composable
fun LeaderboardCard(rank: Int, entry: LeaderboardEntry) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(2.dp)
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Surface(
                shape = CircleShape,
                color = when(rank) {
                    1 -> Color(0xFFFFD700)
                    2 -> Color(0xFFC0C0C0)
                    3 -> Color(0xFFCD7F32)
                    else -> Color(0xFFEEEEEE)
                },
                modifier = Modifier.size(32.dp)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Text("$rank", fontWeight = FontWeight.Bold, fontSize = 12.sp)
                }
            }
            Spacer(Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(entry.name, fontWeight = FontWeight.SemiBold)
                Text("Time: ${entry.timeTaken}", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
            }
            Text("${entry.score}%", fontWeight = FontWeight.ExtraBold, color = Color(0xFF1976D2), fontSize = 18.sp)
        }
    }
}
