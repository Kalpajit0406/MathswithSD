package com.example.mathswithsd.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.mathswithsd.models.Question
import com.example.mathswithsd.data.repository.Result

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QuestionBankScreen(
    onBack: () -> Unit,
    onNavigateToCreate: () -> Unit,
    viewModel: QuestionBankViewModel = viewModel()
) {
    val state by viewModel.state.collectAsState()
    var selectedClass by remember { mutableStateOf<Int?>(null) }
    var selectedLanguage by remember { mutableStateOf<String?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Question Bank", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = { /* TODO: Show filter dialog */ }) {
                        Icon(Icons.Default.FilterList, contentDescription = "Filter")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color(0xFFFF9800),
                    titleContentColor = Color.White,
                    navigationIconContentColor = Color.White
                )
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = onNavigateToCreate,
                containerColor = Color(0xFFFF9800),
                contentColor = Color.White
            ) {
                Icon(Icons.Default.Add, contentDescription = "Add Question")
            }
        }
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            when (state) {
                is QuestionListState.Loading -> {
                    CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                }
                is QuestionListState.Error -> {
                    Text(
                        "Error: ${(state as QuestionListState.Error).message}",
                        modifier = Modifier.align(Alignment.Center),
                        color = Color.Red
                    )
                }
                is QuestionListState.Success -> {
                    val questions = (state as QuestionListState.Success).questions
                    if (questions.isEmpty()) {
                        Text("No questions found", modifier = Modifier.align(Alignment.Center))
                    } else {
                        LazyColumn(
                            modifier = Modifier.fillMaxSize().padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            items(questions) { question ->
                                QuestionItemCard(question)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun QuestionItemCard(question: Question) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(4.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(
                    text = "Class ${question.classNo} • ${question.language}",
                    style = MaterialTheme.typography.labelMedium,
                    color = Color(0xFFFF9800)
                )
                Row {
                    IconButton(onClick = { /* TODO: Edit */ }, modifier = Modifier.size(24.dp)) {
                        Icon(Icons.Default.Edit, contentDescription = "Edit", tint = Color.Gray, modifier = Modifier.size(18.dp))
                    }
                    Spacer(Modifier.width(8.dp))
                    IconButton(onClick = { /* TODO: Delete */ }, modifier = Modifier.size(24.dp)) {
                        Icon(Icons.Default.Delete, contentDescription = "Delete", tint = Color.Red, modifier = Modifier.size(18.dp))
                    }
                }
            }
            Spacer(Modifier.height(8.dp))
            KaTeXText(text = question.question)
            Spacer(Modifier.height(8.dp))
            Text(
                text = "Correct: ${question.correctAnswer}",
                style = MaterialTheme.typography.bodySmall,
                color = Color(0xFF43A047),
                fontWeight = FontWeight.Bold
            )
        }
    }
}

sealed class QuestionListState {
    object Loading : QuestionListState()
    data class Success(val questions: List<Question>) : QuestionListState()
    data class Error(val message: String) : QuestionListState()
}
