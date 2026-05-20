package com.example.mathswithsd.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TestScreen(viewModel: TestViewModel) {
    val questions by viewModel.questions.collectAsState()
    val currentIndex by viewModel.currentQuestionIndex.collectAsState()
    val answers by viewModel.answers.collectAsState()
    val timeLeft by viewModel.timeLeft.collectAsState()
    val isSubmitting by viewModel.isSubmitting.collectAsState()

    if (questions.isEmpty()) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator()
        }
        return
    }

    val currentQ = questions[currentIndex]
    val currentAnswer = answers[currentQ.id]

    fun formatTime(millis: Long): String {
        val mins = millis / 60000
        val secs = (millis % 60000) / 1000
        return String.format("%02d:%02d", mins, secs)
    }

    val showSecurityWarning by viewModel.showSecurityWarning.collectAsState()
    val isSecurityLocked by viewModel.isSecurityLocked.collectAsState()

    // Listen to Security Events
    LaunchedEffect(Unit) {
        com.example.mathswithsd.util.SecurityEventBus.events.collect { event ->
            if (event is com.example.mathswithsd.util.SecurityEvent.ViolationDetected) {
                viewModel.onViolationDetected()
            }
        }
    }

    if (showSecurityWarning) {
        AlertDialog(
            onDismissRequest = { /* Don't allow dismiss by clicking outside */ },
            title = { Text("Warning", fontWeight = FontWeight.Bold, color = Color.Red) },
            text = { Text("Do not leave the exam screen. Next violation will submit your test immediately.") },
            confirmButton = {
                Button(onClick = { viewModel.dismissWarning() }) {
                    Text("Continue")
                }
            }
        )
    }

    if (isSecurityLocked) {
        Box(
            modifier = Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.8f)).clickable(enabled = false) {},
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                CircularProgressIndicator(color = Color.White)
                Spacer(Modifier.height(16.dp))
                Text("Security Violation Detected", color = Color.White, fontWeight = FontWeight.Bold)
                Text("Your test is being submitted...", color = Color.White)
            }
        }
        return
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Exam Running") },
                actions = {
                    Text(
                        text = "Time: ${formatTime(timeLeft)}",
                        color = if (timeLeft < 60000) Color.Red else Color.Black,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(end = 16.dp)
                    )
                }
            )
        },
        bottomBar = {
            BottomAppBar {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Button(onClick = { viewModel.previousQuestion() }, enabled = currentIndex > 0) {
                        Text("Prev")
                    }
                    Button(
                        onClick = { viewModel.markForReview(currentQ.id) },
                        colors = ButtonDefaults.buttonColors(containerColor = Color.Magenta)
                    ) {
                        Text("Review")
                    }
                    if (currentIndex == questions.lastIndex) {
                        Button(
                            onClick = { viewModel.submitTest() }, 
                            enabled = !isSubmitting,
                            colors = ButtonDefaults.buttonColors(containerColor = Color.Green)
                        ) {
                            if (isSubmitting) {
                                CircularProgressIndicator(color = Color.White, modifier = Modifier.size(24.dp))
                                Spacer(Modifier.width(8.dp))
                                Text("Submitting...")
                            } else {
                                Text("Submit")
                            }
                        }
                    } else {
                        Button(onClick = { viewModel.nextQuestion() }) {
                            Text("Next")
                        }
                    }
                }
            }
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize().padding(16.dp)) {
            
            // Palette Grid
            LazyVerticalGrid(columns = GridCells.Adaptive(40.dp), modifier = Modifier.height(150.dp)) {
                items(questions.size) { index ->
                    val answer = answers[questions[index].id]
                    val bgColor = when {
                        answer?.markedForReview == true -> Color.Magenta
                        answer != null && answer.selectedOptionIndex != -1 -> Color.Green
                        else -> Color.Gray
                    }
                    Box(modifier = Modifier
                        .padding(4.dp)
                        .size(40.dp)
                        .background(bgColor, shape = MaterialTheme.shapes.small)
                        .clickable { viewModel.jumpTo(index) },
                        contentAlignment = Alignment.Center
                    ) {
                        Text("${index + 1}", color = Color.White)
                    }
                }
            }

            Spacer(Modifier.height(16.dp))

            // Question Display
            Row(modifier = Modifier.fillMaxWidth()) {
                Text("Q${currentIndex + 1}. ", style = MaterialTheme.typography.titleLarge)
                KaTeXText(text = currentQ.text)
            }
            
            currentQ.diagram?.let { url ->
                coil.compose.AsyncImage(
                    model = url,
                    contentDescription = "Question Diagram",
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(200.dp)
                        .padding(vertical = 8.dp),
                    contentScale = androidx.compose.ui.layout.ContentScale.Fit
                )
            }

            Spacer(Modifier.height(16.dp))

            // Options
            currentQ.options.forEachIndexed { optIndex, option ->
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp).clickable {
                    viewModel.selectAnswer(currentQ.id, optIndex)
                }) {
                    RadioButton(
                        selected = currentAnswer?.selectedOptionIndex == optIndex,
                        onClick = { viewModel.selectAnswer(currentQ.id, optIndex) }
                    )
                    KaTeXText(text = option, modifier = Modifier.padding(start = 8.dp))
                }
            }
        }
    }
}
