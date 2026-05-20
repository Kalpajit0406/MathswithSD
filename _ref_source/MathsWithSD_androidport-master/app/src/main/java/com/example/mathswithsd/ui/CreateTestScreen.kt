package com.example.mathswithsd.ui

import android.app.DatePickerDialog
import android.app.TimePickerDialog
import android.widget.Toast
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.CalendarToday
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.util.*
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateTestScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val calendar = Calendar.getInstance()

    var selectedDate by remember { mutableStateOf("") }
    var selectedTime by remember { mutableStateOf("") }

    var expandedClass by remember { mutableStateOf(false) }
    var selectedClass by remember { mutableStateOf("Select Class") }
    val classes = listOf("9", "10", "11", "12")

    var expandedMedium by remember { mutableStateOf(false) }
    var selectedMedium by remember { mutableStateOf("Select Medium") }
    val mediums = listOf("Bengali", "English", "Both")

    var expandedQuestions by remember { mutableStateOf(false) }
    var selectedQuestions by remember { mutableStateOf("Select Total Questions") }
    val questionsOptions = listOf("20", "40", "50", "80", "100")

    var totalTime by remember { mutableStateOf("") }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Create Test", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color(0xFF673AB7), // Match Deep Purple
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
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            Text(
                text = "Test Configuration",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF673AB7)
            )

            // Date & Time Row
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedCard(onClick = {
                    val datePickerDialog = DatePickerDialog(
                        context,
                        { _, year, month, dayOfMonth ->
                            selectedDate = "$dayOfMonth/${month + 1}/$year"
                        },
                        calendar.get(Calendar.YEAR),
                        calendar.get(Calendar.MONTH),
                        calendar.get(Calendar.DAY_OF_MONTH)
                    )
                    datePickerDialog.datePicker.minDate = System.currentTimeMillis() - 1000
                    datePickerDialog.show()
                }, modifier = Modifier.weight(1f)) {
                    Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.CalendarToday, contentDescription = "Date", modifier = Modifier.size(20.dp))
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(if (selectedDate.isEmpty()) "Date" else selectedDate, style = MaterialTheme.typography.bodyMedium)
                    }
                }

                OutlinedCard(onClick = {
                    val timePickerDialog = TimePickerDialog(
                        context,
                        { _, hourOfDay, minute ->
                            val selectedCal = Calendar.getInstance()
                            if (selectedDate.isNotEmpty()) {
                                val parts = selectedDate.split("/")
                                selectedCal.set(parts[2].toInt(), parts[1].toInt() - 1, parts[0].toInt())
                            }
                            
                            val now = Calendar.getInstance()
                            if (selectedCal.get(Calendar.YEAR) == now.get(Calendar.YEAR) &&
                                selectedCal.get(Calendar.DAY_OF_YEAR) == now.get(Calendar.DAY_OF_YEAR)
                            ) {
                                if (hourOfDay < now.get(Calendar.HOUR_OF_DAY) || 
                                    (hourOfDay == now.get(Calendar.HOUR_OF_DAY) && minute < now.get(Calendar.MINUTE))) {
                                    Toast.makeText(context, "Please select an upcoming time", Toast.LENGTH_SHORT).show()
                                    return@TimePickerDialog
                                }
                            }
                            
                            val amPm = if (hourOfDay >= 12) "PM" else "AM"
                            val hour = if (hourOfDay % 12 == 0) 12 else hourOfDay % 12
                            val minStr = if (minute < 10) "0$minute" else "$minute"
                            selectedTime = "$hour:$minStr $amPm"
                        },
                        calendar.get(Calendar.HOUR_OF_DAY),
                        calendar.get(Calendar.MINUTE),
                        false
                    )
                    timePickerDialog.show()
                }, modifier = Modifier.weight(1f)) {
                    Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.Schedule, contentDescription = "Time", modifier = Modifier.size(20.dp))
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(if (selectedTime.isEmpty()) "Time" else selectedTime, style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }

            // Class and Medium Row
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                ExposedDropdownMenuBox(
                    expanded = expandedClass,
                    onExpandedChange = { expandedClass = !expandedClass },
                    modifier = Modifier.weight(1f)
                ) {
                    OutlinedTextField(
                        value = selectedClass,
                        onValueChange = {},
                        readOnly = true,
                        label = { Text("Class") },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expandedClass) },
                        modifier = Modifier.menuAnchor()
                    )
                    ExposedDropdownMenu(
                        expanded = expandedClass,
                        onDismissRequest = { expandedClass = false }
                    ) {
                        classes.forEach { c ->
                            DropdownMenuItem(
                                text = { Text("Class $c") },
                                onClick = {
                                    selectedClass = "Class $c"
                                    expandedClass = false
                                }
                            )
                        }
                    }
                }

                ExposedDropdownMenuBox(
                    expanded = expandedMedium,
                    onExpandedChange = { expandedMedium = !expandedMedium },
                    modifier = Modifier.weight(1f)
                ) {
                    OutlinedTextField(
                        value = selectedMedium,
                        onValueChange = {},
                        readOnly = true,
                        label = { Text("Medium") },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expandedMedium) },
                        modifier = Modifier.menuAnchor()
                    )
                    ExposedDropdownMenu(
                        expanded = expandedMedium,
                        onDismissRequest = { expandedMedium = false }
                    ) {
                        mediums.forEach { m ->
                            DropdownMenuItem(
                                text = { Text(m) },
                                onClick = {
                                    selectedMedium = m
                                    expandedMedium = false
                                }
                            )
                        }
                    }
                }
            }

            // Questions and Time Row
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                ExposedDropdownMenuBox(
                    expanded = expandedQuestions,
                    onExpandedChange = { expandedQuestions = !expandedQuestions },
                    modifier = Modifier.weight(1f)
                ) {
                    OutlinedTextField(
                        value = selectedQuestions,
                        onValueChange = {},
                        readOnly = true,
                        label = { Text("Questions") },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expandedQuestions) },
                        modifier = Modifier.menuAnchor()
                    )
                    ExposedDropdownMenu(
                        expanded = expandedQuestions,
                        onDismissRequest = { expandedQuestions = false }
                    ) {
                        questionsOptions.forEach { q ->
                            DropdownMenuItem(
                                text = { Text(q) },
                                onClick = {
                                    selectedQuestions = q
                                    expandedQuestions = false
                                }
                            )
                        }
                    }
                }

                OutlinedTextField(
                    value = totalTime,
                    onValueChange = { totalTime = it.filter { char -> char.isDigit() } },
                    label = { Text("Total Time (mins)") },
                    singleLine = true,
                    keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(keyboardType = androidx.compose.ui.text.input.KeyboardType.Number),
                    modifier = Modifier.weight(1f)
                )
            }

            Spacer(modifier = Modifier.weight(1f))

            val coroutineScope = rememberCoroutineScope()

            Button(
                onClick = {
                    if (selectedDate.isEmpty() || selectedTime.isEmpty() || selectedClass == "Select Class" || selectedMedium == "Select Medium" || selectedQuestions == "Select Total Questions" || totalTime.isEmpty()) {
                        Toast.makeText(context, "Please fill all fields", Toast.LENGTH_SHORT).show()
                    } else {
                        coroutineScope.launch {
                            try {
                                val request = com.example.mathswithsd.models.CreateTestRequest(
                                    date = selectedDate,
                                    time = selectedTime,
                                    classNo = selectedClass.replace("Class ", "").toInt(),
                                    language = selectedMedium,
                                    totalQuestions = selectedQuestions.toInt(),
                                    totalTime = totalTime.toInt()
                                )
                                com.example.mathswithsd.api.RetrofitClient.create(context).createTest(request)
                                
                                Toast.makeText(context, "Test Created and Saved to DB!", Toast.LENGTH_LONG).show()
                                
                                // Push a local notification
                                val notificationManager = context.getSystemService(android.content.Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                                val channelId = "test_notifications"
                                
                                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                                    val channel = android.app.NotificationChannel(
                                        channelId,
                                        "Test Alerts",
                                        android.app.NotificationManager.IMPORTANCE_HIGH
                                    )
                                    notificationManager.createNotificationChannel(channel)
                                }

                                val notification = androidx.core.app.NotificationCompat.Builder(context, channelId)
                                    .setSmallIcon(android.R.drawable.ic_dialog_info)
                                    .setContentTitle("New Exam Scheduled!")
                                    .setContentText("${selectedClass} (${selectedMedium}): $selectedQuestions questions for $totalTime mins on $selectedDate at $selectedTime.")
                                    .setPriority(androidx.core.app.NotificationCompat.PRIORITY_HIGH)
                                    .setAutoCancel(true)
                                    .build()

                                notificationManager.notify(System.currentTimeMillis().toInt(), notification)

                                onBack()
                            } catch (e: Exception) {
                                Toast.makeText(context, "Error saving test: ${e.message}", Toast.LENGTH_LONG).show()
                            }
                        }
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF673AB7))
            ) {
                Text("Publish Test", fontSize = 18.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}
