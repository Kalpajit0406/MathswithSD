package com.example.mathswithsd

import android.Manifest
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import com.example.mathswithsd.api.AuthManager
import com.example.mathswithsd.api.RetrofitClient
import com.example.mathswithsd.ui.AdminDashboard
import com.example.mathswithsd.ui.LoginScreen
import com.example.mathswithsd.ui.theme.MathsWithSDTheme
import retrofit2.Call
import retrofit2.Callback
import retrofit2.Response

import android.app.Activity
import android.content.res.Configuration
import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.google.firebase.messaging.FirebaseMessaging
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity : AppCompatActivity() {

    private val notificationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { /* permission result handled silently */ }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Request notification permission (Android 13+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }

        // Prevent screenshots, screen recording, and display on non-secure displays
        window.setFlags(
            android.view.WindowManager.LayoutParams.FLAG_SECURE,
            android.view.WindowManager.LayoutParams.FLAG_SECURE
        )

        setContent {
            MathsWithSDTheme {
                val authManager = AuthManager(applicationContext)
                val context = LocalContext.current
                val navController = rememberNavController()
                var backPressedTime by remember { mutableStateOf(0L) }

                // Register FCM token once when logged in
                LaunchedEffect(Unit) {
                    if (!authManager.getToken().isNullOrEmpty()) {
                        FirebaseMessaging.getInstance().token.addOnSuccessListener { token ->
                            CoroutineScope(Dispatchers.IO).launch {
                                try {
                                    RetrofitClient.create(applicationContext)
                                        .registerFcmToken(com.example.mathswithsd.models.FcmTokenRequest(token))
                                } catch (e: Exception) {
                                    Log.e("FCM", "Token registration failed: ${e.message}")
                                }
                            }
                        }
                    }
                }

                // Handle deep-link from notification tap
                LaunchedEffect(Unit) {
                    val navigateTo = intent?.getStringExtra("navigate_to")
                    if (navigateTo == "ANNOUNCEMENTS") {
                        navController.navigate("ANNOUNCEMENTS")
                    }
                }

                // Track current route for back press logic
                val navBackStackEntry by navController.currentBackStackEntryFlow.collectAsState(initial = null)
                val currentRoute = navBackStackEntry?.destination?.route

                BackHandler(enabled = true) {
                    val rootScreens = listOf("ADMIN", "STUDENT", "LOGIN")
                    if (currentRoute in rootScreens) {
                        if (System.currentTimeMillis() - backPressedTime < 2000) {
                            (context as? Activity)?.finish()
                        } else {
                            Toast.makeText(context, "Press back again to exit", Toast.LENGTH_SHORT).show()
                            backPressedTime = System.currentTimeMillis()
                        }
                    } else {
                        navController.popBackStack()
                    }
                }

                val startDest = if (authManager.getToken().isNullOrEmpty()) "LOGIN" else {
                    if (authManager.isAdmin()) "ADMIN" else "STUDENT"
                }

                NavHost(navController = navController, startDestination = startDest) {
                    composable("LOGIN") {
                        LoginScreen(
                            onLoginSuccess = { 
                                Log.d("LOGIN_FLOW", "Login success callback triggered")
                                val dest = if (authManager.isAdmin()) "ADMIN" else "STUDENT"
                                navController.navigate(dest) {
                                    popUpTo("LOGIN") { inclusive = true }
                                }
                            },
                            onNavigateToRegister = {
                                navController.navigate("REGISTER")
                            }
                        )
                    }
                    composable("REGISTER") {
                        com.example.mathswithsd.ui.RegistrationScreen(
                            onBackToLogin = { navController.popBackStack() }
                        )
                    }
                    composable("ADMIN") {
                        if (!authManager.isAdmin()) {
                            LaunchedEffect(Unit) {
                                Toast.makeText(context, "Access Denied. Admins only.", Toast.LENGTH_SHORT).show()
                                navController.navigate("STUDENT") { popUpTo(0) }
                            }
                            return@composable
                        }
                        AdminDashboard(
                            onLogout = {
                                authManager.logout()
                                navController.navigate("LOGIN") { popUpTo(0) }
                            },
                            onNavigateToManageStudents = { navController.navigate("MANAGE_STUDENTS") },
                            onNavigateToStudentDashboard = { navController.navigate("STUDENT") },
                            onNavigateToCreateTest = { navController.navigate("CREATE_TEST") },
                            onNavigateToYourTests = { navController.navigate("YOUR_TESTS") },
                            onNavigateToAnnouncements = { navController.navigate("ANNOUNCEMENTS") }
                        )
                    }
                    composable("YOUR_TESTS") {
                        com.example.mathswithsd.ui.YourTestsScreen(
                            onBack = { navController.popBackStack() }
                        )
                    }
                    composable("CREATE_TEST") {
                        com.example.mathswithsd.ui.CreateTestScreen(
                            onBack = { navController.popBackStack() }
                        )
                    }
                    composable("MANAGE_STUDENTS") {
                        com.example.mathswithsd.ui.ManageStudentsScreen(
                            onBack = { navController.popBackStack() }
                        )
                    }
                    composable("STUDENT") {
                        com.example.mathswithsd.ui.StudentDashboard(
                            onLogout = {
                                authManager.logout()
                                navController.navigate("LOGIN") { popUpTo(0) }
                            },
                            onNavigateToAdminDashboard = { navController.navigate("ADMIN") },
                            onNavigateToScheduledExams = { navController.navigate("SCHEDULED_EXAMS") },
                            onNavigateToAnnouncements = { navController.navigate("ANNOUNCEMENTS") }
                        )
                    }
                    composable("SCHEDULED_EXAMS") {
                        com.example.mathswithsd.ui.ScheduledExamsScreen(
                            onBack = { navController.popBackStack() }
                        )
                    }
                    // Announcement routes
                    composable("ANNOUNCEMENTS") {
                        com.example.mathswithsd.ui.AnnouncementsScreen(
                            isAdmin = authManager.isAdmin(),
                            studentClass = if (authManager.isAdmin()) null else authManager.getUserClass().toString(),
                            onBack = { navController.popBackStack() },
                            onCreateClick = { navController.navigate("CREATE_ANNOUNCEMENT") }
                        )
                    }
                    composable("CREATE_ANNOUNCEMENT") {
                        com.example.mathswithsd.ui.CreateAnnouncementScreen(
                            onBack = { navController.popBackStack() }
                        )
                    }
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        checkSecureState()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (!hasFocus) {
            com.example.mathswithsd.util.SecurityEventBus.postEvent(com.example.mathswithsd.util.SecurityEvent.ViolationDetected)
        }
        checkSecureState()
    }

    override fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean, newConfig: Configuration) {
        super.onMultiWindowModeChanged(isInMultiWindowMode, newConfig)
        if (isInMultiWindowMode) {
            com.example.mathswithsd.util.SecurityEventBus.postEvent(com.example.mathswithsd.util.SecurityEvent.ViolationDetected)
        }
        checkSecureState()
    }

    override fun onPause() {
        super.onPause()
        com.example.mathswithsd.util.SecurityEventBus.postEvent(com.example.mathswithsd.util.SecurityEvent.ViolationDetected)
        checkSecureState()
    }


    private fun checkSecureState() {
        // 1. Standard Android API Check
        // isInMultiWindowMode covers split-screen and freeform (floating) on standard Android.
        if (isInMultiWindowMode || (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O && isInPictureInPictureMode)) {
            enforceKill()
            return
        }

        // 2. Comprehensive Screen Resolution/Dimension Check
        // This detects floating windows and bubbles that might not trigger 'isInMultiWindowMode'
        // on some OEM skins (Xiaomi, Samsung, Oppo etc).
        val displayMetrics = android.util.DisplayMetrics()
        windowManager.defaultDisplay.getRealMetrics(displayMetrics)
        val screenWidth = displayMetrics.widthPixels
        val screenHeight = displayMetrics.heightPixels

        val windowRect = android.graphics.Rect()
        window.decorView.getWindowVisibleDisplayFrame(windowRect)
        val windowWidth = windowRect.width()
        val windowHeight = windowRect.height()

        // Buffer for system bars (status bar, navigation bar)
        // Usually, a full screen app should occupy nearly 100% of width.
        // Floating windows are significantly smaller.
        val isFloatingWidth = windowWidth > 0 && windowWidth < (screenWidth * 0.95).toInt()
        
        // Height check is more sensitive due to keyboards and status bars.
        // But in extreme floating mode, height is also reduced.
        val isFloatingHeight = windowHeight > 0 && windowHeight < (screenHeight * 0.7).toInt()

        if (isFloatingWidth || isFloatingHeight) {
            enforceKill()
        }
    }

    private fun enforceKill() {
        Toast.makeText(this, "Security Violation: Floating Screen Detected. Exam Terminated.", Toast.LENGTH_LONG).show()
        finishAndRemoveTask()
        android.os.Process.killProcess(android.os.Process.myPid())
        System.exit(0)
    }
}

@Composable
fun QuestionScreen() {
    var statusText by remember { mutableStateOf("Loading...") }
    val context = androidx.compose.ui.platform.LocalContext.current

    LaunchedEffect(Unit) {
        Log.d("API_FLOW", "Fetching questions...")
        RetrofitClient.create(context).getQuestions().enqueue(object : Callback<List<Any>> {
            override fun onResponse(call: Call<List<Any>>, response: Response<List<Any>>) {
                Log.d("API_FLOW", "Response received: ${response.code()}")
                if (response.isSuccessful) {
                    val questions = response.body()
                    Log.d("API_SUCCESS", "Questions: $questions")
                    statusText = "API Success: ${questions?.size ?: 0} questions"
                } else {
                    val errorBody = response.errorBody()?.string()
                    Log.e("API_ERROR", "Error: ${response.code()}, Body: $errorBody")
                    statusText = "API Error: ${response.code()}"
                }
            }

            override fun onFailure(call: Call<List<Any>>, t: Throwable) {
                Log.e("API_ERROR", t.message.toString())
                statusText = "API Failure: ${t.message}"
            }
        })
    }

    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text(text = statusText)
    }
}
