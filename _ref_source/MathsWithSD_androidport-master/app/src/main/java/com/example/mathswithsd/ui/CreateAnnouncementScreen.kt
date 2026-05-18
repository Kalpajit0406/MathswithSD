package com.example.mathswithsd.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Send
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateAnnouncementScreen(
    onBack: () -> Unit,
    viewModel: AnnouncementViewModel = viewModel()
) {
    val createState by viewModel.createState.collectAsState()

    var title   by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }
    var imageUrl by remember { mutableStateOf("") }
    var selectedClass by remember { mutableStateOf("all") }
    var classDropdownExpanded by remember { mutableStateOf(false) }

    val classOptions = listOf("all", "9", "10", "11", "12")

    // Navigate back automatically after success
    LaunchedEffect(createState) {
        if (createState is CreateAnnouncementState.Success) {
            viewModel.resetCreateState()
            onBack()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Create Announcement", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color(0xFF1565C0),
                    titleContentColor = Color.White,
                    navigationIconContentColor = Color.White
                )
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(Color(0xFFF5F7FF))
                .padding(padding)
                .padding(20.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                "New Announcement",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF1A237E)
            )

            // Title
            OutlinedTextField(
                value = title,
                onValueChange = { title = it },
                label = { Text("Title") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp)
            )

            // Message
            OutlinedTextField(
                value = message,
                onValueChange = { message = it },
                label = { Text("Message") },
                minLines = 4,
                maxLines = 8,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp)
            )

            // Image URL (optional)
            OutlinedTextField(
                value = imageUrl,
                onValueChange = { imageUrl = it },
                label = { Text("Image URL (optional)") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp)
            )

            // Class Selector
            ExposedDropdownMenuBox(
                expanded = classDropdownExpanded,
                onExpandedChange = { classDropdownExpanded = !classDropdownExpanded }
            ) {
                OutlinedTextField(
                    value = if (selectedClass == "all") "All Classes" else "Class $selectedClass",
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("Target Class") },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = classDropdownExpanded) },
                    modifier = Modifier.fillMaxWidth().menuAnchor(),
                    shape = RoundedCornerShape(12.dp)
                )
                ExposedDropdownMenu(
                    expanded = classDropdownExpanded,
                    onDismissRequest = { classDropdownExpanded = false }
                ) {
                    classOptions.forEach { option ->
                        DropdownMenuItem(
                            text = { Text(if (option == "all") "All Classes" else "Class $option") },
                            onClick = {
                                selectedClass = option
                                classDropdownExpanded = false
                            }
                        )
                    }
                }
            }

            // Error state
            if (createState is CreateAnnouncementState.Error) {
                Card(
                    colors = CardDefaults.cardColors(containerColor = Color(0xFFFFEBEE)),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text(
                        (createState as CreateAnnouncementState.Error).message,
                        color = Color(0xFFB71C1C),
                        modifier = Modifier.padding(12.dp)
                    )
                }
            }

            Spacer(Modifier.height(8.dp))

            // Submit Button
            Button(
                onClick = {
                    if (title.isNotBlank() && message.isNotBlank()) {
                        viewModel.createAnnouncement(
                            title = title.trim(),
                            message = message.trim(),
                            image = imageUrl.trim().ifBlank { null },
                            targetClass = selectedClass
                        )
                    }
                },
                enabled = title.isNotBlank() && message.isNotBlank()
                        && createState !is CreateAnnouncementState.Loading,
                modifier = Modifier.fillMaxWidth().height(52.dp),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1565C0))
            ) {
                if (createState is CreateAnnouncementState.Loading) {
                    CircularProgressIndicator(color = Color.White, modifier = Modifier.size(22.dp))
                    Spacer(Modifier.width(10.dp))
                    Text("Sending...")
                } else {
                    Icon(Icons.Default.Send, null, modifier = Modifier.size(20.dp))
                    Spacer(Modifier.width(8.dp))
                    Text("Send Announcement", fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}
