package com.example.mathswithsd.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.ExperimentalMaterialApi
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.pullrefresh.PullRefreshIndicator
import androidx.compose.material.pullrefresh.pullRefresh
import androidx.compose.material.pullrefresh.rememberPullRefreshState
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.example.mathswithsd.models.AnnouncementResponse

@OptIn(ExperimentalMaterial3Api::class, ExperimentalMaterialApi::class)
@Composable
fun AnnouncementsScreen(
    isAdmin: Boolean,
    studentClass: String? = null,
    onBack: () -> Unit,
    onCreateClick: () -> Unit,
    viewModel: AnnouncementViewModel = viewModel()
) {
    val state by viewModel.state.collectAsState()
    var isRefreshing by remember { mutableStateOf(false) }

    // Load on first composition
    LaunchedEffect(Unit) {
        viewModel.loadAnnouncements(if (isAdmin) null else studentClass)
    }

    val pullRefreshState = rememberPullRefreshState(
        refreshing = isRefreshing,
        onRefresh = {
            isRefreshing = true
            viewModel.refresh(if (isAdmin) null else studentClass)
        }
    )

    // Stop spinner when state changes
    LaunchedEffect(state) {
        if (state !is AnnouncementState.Loading) isRefreshing = false
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Announcements", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color(0xFF1565C0),
                    titleContentColor = Color.White,
                    navigationIconContentColor = Color.White,
                    actionIconContentColor = Color.White
                )
            )
        },
        floatingActionButton = {
            if (isAdmin) {
                ExtendedFloatingActionButton(
                    onClick = onCreateClick,
                    icon = { Icon(Icons.Default.Add, contentDescription = "Create") },
                    text = { Text("New") },
                    containerColor = Color(0xFF1565C0),
                    contentColor = Color.White
                )
            }
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .pullRefresh(pullRefreshState)
                .background(Color(0xFFF5F7FF))
                .padding(padding)
        ) {
            when (val s = state) {
                is AnnouncementState.Loading -> {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = Color(0xFF1565C0))
                    }
                }

                is AnnouncementState.Error -> {
                    Column(
                        Modifier.fillMaxSize(),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        Icon(
                            Icons.Default.CloudOff,
                            contentDescription = null,
                            tint = Color.Gray,
                            modifier = Modifier.size(64.dp)
                        )
                        Spacer(Modifier.height(12.dp))
                        Text(s.message, color = Color.Gray, fontSize = 14.sp)
                        Spacer(Modifier.height(16.dp))
                        Button(onClick = { viewModel.loadAnnouncements(if (isAdmin) null else studentClass) }) {
                            Text("Retry")
                        }
                    }
                }

                is AnnouncementState.Success -> {
                    if (s.announcements.isEmpty()) {
                        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Icon(Icons.Default.Notifications, null, tint = Color.LightGray, modifier = Modifier.size(80.dp))
                                Spacer(Modifier.height(12.dp))
                                Text("No announcements yet", color = Color.Gray)
                            }
                        }
                    } else {
                        LazyColumn(
                            contentPadding = PaddingValues(16.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            items(s.announcements, key = { it._id }) { announcement ->
                                AnnouncementCard(announcement)
                            }
                        }
                    }
                }

                else -> Unit
            }

            PullRefreshIndicator(
                refreshing = isRefreshing,
                state = pullRefreshState,
                modifier = Modifier.align(Alignment.TopCenter),
                contentColor = Color(0xFF1565C0)
            )
        }
    }
}

@Composable
private fun AnnouncementCard(announcement: AnnouncementResponse) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            // Optional image
            announcement.image?.let { url ->
                AsyncImage(
                    model = url,
                    contentDescription = "Announcement image",
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(180.dp)
                        .clip(RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp)),
                    contentScale = ContentScale.Crop
                )
            }

            Column(modifier = Modifier.padding(16.dp)) {
                // Class chip
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Surface(
                        shape = RoundedCornerShape(50),
                        color = Color(0xFFE3F2FD)
                    ) {
                        Text(
                            text = if (announcement.targetClass == "all") "All Classes"
                                   else "Class ${announcement.targetClass}",
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                            fontSize = 11.sp,
                            color = Color(0xFF1565C0),
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                    Spacer(Modifier.weight(1f))
                    Icon(Icons.Default.Schedule, null, tint = Color.Gray, modifier = Modifier.size(14.dp))
                    Spacer(Modifier.width(4.dp))
                    Text(
                        text = formatAnnouncementDate(announcement.createdAt),
                        fontSize = 11.sp,
                        color = Color.Gray
                    )
                }

                Spacer(Modifier.height(10.dp))

                Text(
                    text = announcement.title,
                    fontWeight = FontWeight.Bold,
                    fontSize = 17.sp,
                    color = Color(0xFF1A237E)
                )
                Spacer(Modifier.height(6.dp))
                Text(
                    text = announcement.message,
                    fontSize = 14.sp,
                    color = Color(0xFF424242),
                    maxLines = 5,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

private fun formatAnnouncementDate(isoDate: String?): String {
    if (isoDate == null) return "Unknown date"
    return try {
        val parser = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.US)
        val display = java.text.SimpleDateFormat("dd MMM yyyy, hh:mm a", java.util.Locale.US)
        val date = parser.parse(if (isoDate.length >= 19) isoDate.take(19) else isoDate)
        display.format(date ?: java.util.Date())
    } catch (e: Exception) {
        isoDate
    }
}
