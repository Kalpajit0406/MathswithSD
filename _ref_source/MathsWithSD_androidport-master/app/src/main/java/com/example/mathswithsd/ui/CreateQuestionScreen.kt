package com.example.mathswithsd.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Collections
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.filled.Queue
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.mathswithsd.data.repository.Result

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateQuestionTab(
    viewModel: QuestionViewModel = viewModel()
) {
    var questionText by remember { mutableStateOf("") }
    var option1 by remember { mutableStateOf("") }
    var option2 by remember { mutableStateOf("") }
    var option3 by remember { mutableStateOf("") }
    var option4 by remember { mutableStateOf("") }
    var correctAnswer by remember { mutableStateOf("") }
    var chapter by remember { mutableStateOf("") }
    var selectedClass by remember { mutableStateOf(10) }
    var selectedLanguage by remember { mutableStateOf("English") }

    val questionQueue by viewModel.questionQueue.collectAsState()

    val scanResult by viewModel.scanResult.collectAsState()
    val isScanning by viewModel.isScanning.collectAsState()
    val isUploading by viewModel.isUploading.collectAsState()
    val creationStatus by viewModel.creationStatus.collectAsState()

    val context = androidx.compose.ui.platform.LocalContext.current

    // Sync scan result to text fields
    LaunchedEffect(scanResult) {
        scanResult?.let { scan ->
            android.util.Log.d("OCR_UI", "Updating UI with: ${scan.questionText}")
            questionText = scan.questionText
            if (scan.options.size >= 4) {
                option1 = scan.options[0]
                option2 = scan.options[1]
                option3 = scan.options[2]
                option4 = scan.options[3]
            }
            scan.correctAnswer?.let { correctAnswer = it }
            android.widget.Toast.makeText(context, "Question Loaded from Queue!", android.widget.Toast.LENGTH_SHORT).show()
        }
    }

    val galleryLauncher = androidx.activity.compose.rememberLauncherForActivityResult(
        contract = androidx.activity.result.contract.ActivityResultContracts.GetContent()
    ) { uri: android.net.Uri? ->
        uri?.let {
            val bitmap = if (android.os.Build.VERSION.SDK_INT < 28) {
                android.provider.MediaStore.Images.Media.getBitmap(context.contentResolver, it)
            } else {
                val source = android.graphics.ImageDecoder.createSource(context.contentResolver, it)
                android.graphics.ImageDecoder.decodeBitmap(source)
            }
            viewModel.scanQuestion(bitmap)
        }
    }

    // Camera Launcher
    val cameraLauncher = androidx.activity.compose.rememberLauncherForActivityResult(
        contract = androidx.activity.result.contract.ActivityResultContracts.TakePicturePreview()
    ) { bitmap: android.graphics.Bitmap? ->
        bitmap?.let {
            viewModel.scanQuestion(it)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        if (questionQueue.isNotEmpty()) {
            Card(
                colors = CardDefaults.cardColors(containerColor = Color(0xFFEDE7F6)),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier.padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(Icons.Filled.Queue, contentDescription = null, tint = Color(0xFF673AB7))
                    Spacer(Modifier.width(12.dp))
                    Text(
                        "Scanned Queue: ${questionQueue.size} questions remaining",
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFF673AB7)
                    )
                }
            }
        }

        Text("Create New Question", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, color = Color(0xFF673AB7))
        
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Camera Button
            OutlinedButton(
                onClick = { cameraLauncher.launch(null) },
                modifier = Modifier.weight(1f),
                enabled = !isScanning,
                shape = RoundedCornerShape(12.dp)
            ) {
                Icon(Icons.Default.PhotoCamera, contentDescription = null)
                Spacer(Modifier.width(8.dp))
                Text("Scan Paper")
            }
            
            // Gallery Button
            OutlinedButton(
                onClick = { galleryLauncher.launch("image/*") },
                modifier = Modifier.weight(1f),
                enabled = !isScanning,
                shape = RoundedCornerShape(12.dp)
            ) {
                Icon(Icons.Default.Collections, contentDescription = null)
                Spacer(Modifier.width(8.dp))
                Text("Gallery")
            }
        }

        if (isScanning) {
            LinearProgressIndicator(modifier = Modifier.fillMaxWidth(), color = Color(0xFF673AB7))
            Text("Analyzing all questions in the image...", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
        }

        OutlinedTextField(
            value = questionText,
            onValueChange = { questionText = it },
            label = { Text("Question Text (KaTeX supported)") },
            modifier = Modifier.fillMaxWidth(),
            minLines = 3,
            shape = RoundedCornerShape(12.dp)
        )

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(
                value = chapter,
                onValueChange = { chapter = it },
                label = { Text("Chapter") },
                modifier = Modifier.weight(1f),
                shape = RoundedCornerShape(12.dp)
            )
            // Class Selector
            var expanded by remember { mutableStateOf(false) }
            ExposedDropdownMenuBox(
                expanded = expanded,
                onExpandedChange = { expanded = !expanded },
                modifier = Modifier.weight(1f)
            ) {
                OutlinedTextField(
                    value = "Class $selectedClass",
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("Target Class") },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                    modifier = Modifier.menuAnchor(),
                    shape = RoundedCornerShape(12.dp)
                )
                ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                    listOf(9, 10, 11, 12).forEach { cls ->
                        DropdownMenuItem(
                            text = { Text("Class $cls") },
                            onClick = {
                                selectedClass = cls
                                expanded = false
                            }
                        )
                    }
                }
            }
        }

        Text("Options", fontWeight = FontWeight.Bold, color = Color.Gray)
        OutlinedTextField(value = option1, onValueChange = { option1 = it }, label = { Text("Option 1") }, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(12.dp))
        OutlinedTextField(value = option2, onValueChange = { option2 = it }, label = { Text("Option 2") }, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(12.dp))
        OutlinedTextField(value = option3, onValueChange = { option3 = it }, label = { Text("Option 3") }, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(12.dp))
        OutlinedTextField(value = option4, onValueChange = { option4 = it }, label = { Text("Option 4") }, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(12.dp))

        OutlinedTextField(
            value = correctAnswer,
            onValueChange = { correctAnswer = it },
            label = { Text("Correct Answer") },
            placeholder = { Text("Paste exact text of the correct option") },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp)
        )

        Button(
            onClick = {
                viewModel.createQuestion(
                    questionText,
                    listOf(option1, option2, option3, option4),
                    correctAnswer,
                    selectedClass,
                    selectedLanguage,
                    chapter
                )
            },
            modifier = Modifier.fillMaxWidth().height(56.dp),
            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF673AB7)),
            enabled = creationStatus !is Result.Loading && questionText.isNotBlank(),
            shape = RoundedCornerShape(12.dp)
        ) {
            if (creationStatus is Result.Loading) {
                CircularProgressIndicator(color = Color.White, modifier = Modifier.size(24.dp))
            } else {
                Text(
                    if (questionQueue.size > 1) "Save & Load Next" else "Save Question to DB", 
                    fontWeight = FontWeight.Bold
                )
            }
        }

        // Status Message
        when (creationStatus) {
            is Result.Success -> {
                LaunchedEffect(Unit) {
                    // Reset current form fields
                    questionText = ""
                    option1 = ""; option2 = ""; option3 = ""; option4 = ""
                    correctAnswer = ""
                    
                    // Pop from queue and reset status
                    viewModel.nextQuestion()
                    viewModel.resetStatus()
                }
            }
            is Result.Error -> {
                Text("Error: ${(creationStatus as Result.Error).message}", color = Color.Red, modifier = Modifier.padding(8.dp))
            }
            else -> {}
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateQuestionScreen(
    onBack: () -> Unit,
    viewModel: QuestionViewModel = viewModel()
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Create Question", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color(0xFF673AB7),
                    titleContentColor = Color.White,
                    navigationIconContentColor = Color.White
                )
            )
        }
    ) { padding ->
        Box(modifier = Modifier.padding(padding)) {
            CreateQuestionTab(viewModel)
        }
    }
}

// Extension to simplify mutableStateOf with delegate
@Composable
fun <T> mutableStateFlowOf(value: T) = remember { mutableStateOf(value) }
