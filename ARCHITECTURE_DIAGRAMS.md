# MathsWithSD Flutter - Architecture Overview Diagram

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    MATHSWITHSD FLUTTER APPS                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  STUDENT APP (mathswithsd/)            ADMIN APP (mathswithsd_admin/)│
│  ━━━━━━━━━━━━━━━━━━━━━━━━━             ━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  • Exam taking                         • Question creation            │
│  • Answer submission                   • OCR scanning                 │
│  • Result view                         • Test management              │
│  • Profile                             • Student approval             │
│                                        • Leaderboard                  │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
                                    ↓
            ┌───────────────────────────────────────┐
            │    Shared Backend (Node.js + MongoDB)  │
            │         math-app-backend/               │
            ├───────────────────────────────────────┤
            │ Express.js server on :5000              │
            │ • Authentication (JWT)                  │
            │ • OCR Pipeline (Mathpix API)            │
            │ • Question management                   │
            │ • Exam/Attempt endpoints                │
            └───────────────────────────────────────┘
```

---

## State Management Layer

```
┌──────────────────────────────────────────────────────────┐
│              PROVIDER PATTERN (State Management)          │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  ┌─────────────────────────────────────────────────┐    │
│  │ AuthProvider (Both Apps)                        │    │
│  ├─────────────────────────────────────────────────┤    │
│  │ • status: AuthStatus (initial/loading/auth...)  │    │
│  │ • user: AppUser? (id, name, phone, token)      │    │
│  │ • isAdmin: bool                                 │    │
│  │ • Methods:                                      │    │
│  │   - tryAutoLogin()  [SharedPreferences]         │    │
│  │   - login(phone, password)  [API]               │    │
│  │   - logout()                                    │    │
│  └─────────────────────────────────────────────────┘    │
│                                                           │
│  ┌─────────────────────────────────────────────────┐    │
│  │ ExamProvider (Both Apps)                        │    │
│  ├─────────────────────────────────────────────────┤    │
│  │ • exams: List<Exam>                             │    │
│  │ • userAnswers: Map<questionId → answer>         │    │
│  │ • remainingSeconds: int [Timer]                 │    │
│  │ • currentAttemptId: String                      │    │
│  │                                                 │    │
│  │ Key Methods:                                    │    │
│  │  startExam() → Backend call                     │    │
│  │  submitExam() → Backend call                    │    │
│  │  resumeExam() → SharedPreferences restore       │    │
│  │  _saveAttemptToPrefs() [Every 5s during exam]   │    │
│  │  _startTimer() [1s tick]                        │    │
│  │  [⚠️ Race condition in async save]              │    │
│  └─────────────────────────────────────────────────┘    │
│                                                           │
│  ┌─────────────────────────────────────────────────┐    │
│  │ QuestionProvider (Admin Only)                   │    │
│  ├─────────────────────────────────────────────────┤    │
│  │ • questions: List<Question>                     │    │
│  │ • questionQueue: List<ScanData> [OCR results]   │    │
│  │ • isScanning: bool                              │    │
│  │ • isSaving: bool                                │    │
│  │                                                 │    │
│  │ Key Methods:                                    │    │
│  │  scanImage(File) → Backend OCR                  │    │
│  │    ├─ If parsedMcq exists: use it               │    │
│  │    └─ Else: LatexExtractorService.extract()     │    │
│  │  saveQuestion(Question)                         │    │
│  │  popQuestionFromQueue()                         │    │
│  └─────────────────────────────────────────────────┘    │
│                                                           │
│  ┌─────────────────────────────────────────────────┐    │
│  │ AdminProvider (Admin Only)                      │    │
│  ├─────────────────────────────────────────────────┤    │
│  │ • tests: List<TestConfig>                       │    │
│  │ • students: Map<status → List<StudentUser>>     │    │
│  │ • Methods:                                      │    │
│  │   - loadTests(), createTest()                   │    │
│  │   - approveStudent(), rejectStudent()           │    │
│  └─────────────────────────────────────────────────┘    │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

---

## Services Layer

```
┌──────────────────────────────────────────────────────────────┐
│                      SERVICES (Backend + Storage)             │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ ApiService (HTTP Layer)                               │  │
│  ├────────────────────────────────────────────────────────┤  │
│  │ Base URL: http://10.37.148.209:5000                    │  │
│  │ Headers: Bearer token + ngrok-skip-browser-warning     │  │
│  │                                                        │  │
│  │ Endpoints:                                            │  │
│  │  POST   /api/v1/student/login         [20s timeout]   │  │
│  │  POST   /api/v1/student/register                      │  │
│  │  GET    /api/v1/tests                 [15s timeout]   │  │
│  │  POST   /api/v1/testResponse/start    [15s timeout]   │  │
│  │  POST   /api/v1/testResponse/submit   [15s timeout]   │  │
│  │  GET    /api/v1/announcements         [15s timeout]   │  │
│  │  GET    /api/v1/question/questions    [15s timeout]   │  │
│  │  POST   /api/v1/scan/process          [60s timeout]   │  │
│  │  POST   /api/v1/question/addQuestion  [30s timeout]   │  │
│  │                                                        │  │
│  │ Response Format:                                       │  │
│  │ { data: {...}, message?: "..." }                       │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ ImageService (Image Capture + Crop)                   │  │
│  ├────────────────────────────────────────────────────────┤  │
│  │                                                        │  │
│  │ Student App:                                           │  │
│  │  pickAndCropImage()                                    │  │
│  │  └─ ImagePicker: quality=100% [OOM risk]              │  │
│  │                                                        │  │
│  │ Admin App:                                             │  │
│  │  pickAndCropImage(source)                              │  │
│  │  └─ ImagePicker: quality=60%, max=1600x1600 [safe]    │  │
│  │     ImageCropper: compress JPEG 80%                   │  │
│  │  getLostData()                                         │  │
│  │  └─ Handle Android process death recovery             │  │
│  │                                                        │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ LatexExtractorService (Client-side OCR Fallback)       │  │
│  ├────────────────────────────────────────────────────────┤  │
│  │ Regex Patterns for Option Extraction:                  │  │
│  │  1. (a) option (b) option ... [Most common]            │  │
│  │  2. [a] option [b] option                              │  │
│  │  3. a. option b. option                                │  │
│  │  4. Line-separated a) b) c) d)                         │  │
│  │                                                        │  │
│  │ Cleans Mathpix artifacts:                              │  │
│  │  • HTML tags (<span>, <math>, etc.)                    │  │
│  │  • HTML entities (&lt;, &gt;, &amp;, &#39;)            │  │
│  │  • CSS classes and styles                              │  │
│  │  • Mathpix-specific markup                             │  │
│  │                                                        │  │
│  │ Preserves LaTeX: $...$ and \\[...\\]                   │  │
│  │                                                        │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ AuthStorageService (Secure Token Storage)              │  │
│  ├────────────────────────────────────────────────────────┤  │
│  │ Backend: FlutterSecureStorage                          │  │
│  │   Android: EncryptedSharedPreferences [Encrypted]      │  │
│  │   iOS: Keychain                                        │  │
│  │                                                        │  │
│  │ Stored Values:                                         │  │
│  │  • access_token (JWT)                                  │  │
│  │  • is_admin (bool)                                     │  │
│  │  • user_first_name, user_last_name                     │  │
│  │  • user_phone, user_class                              │  │
│  │  [⚠️ user_id NOT STORED - Lost on auto-login]          │  │
│  │                                                        │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

---

## OCR Pipeline (Admin Only)

```
┌────────────────────────────────────────────────────────────────┐
│                     OCR SCANNING PIPELINE                        │
└────────────────────────────────────────────────────────────────┘

Step 1: Image Selection
  ├─ User taps "Scan Question" button
  ├─ Check camera permission
  ├─ ImageService.pickAndCropImage(source: camera)
  │  ├─ Capture: quality 60%, max 1600x1600
  │  ├─ Crop: JPEG compression 80%
  │  └─ Return: File(cropped)
  └─ [⚠️ Crash risk: Permission, OOM, file deletion]

Step 2: OCR Processing (Server)
  ├─ ApiService.processOcrImage(File)
  ├─ MultipartRequest POST /api/v1/scan/process
  ├─ 60-second timeout
  ├─ Server: Mathpix API processes image
  └─ Response:
     ├─ rawText: "Question text extracted from OCR"
     ├─ latex: "$LaTeX$ formatted equation"
     └─ parsedMcq: {
         ├─ question: "What is 2+2?"
         └─ options: ["a", "b", "c", "d"]
        }
  [⚠️ Crash risk: Timeout, network, JSON parse error]

Step 3: Extract Questions from Response
  ├─ Backend returned parsedMcq?
  │  ├─ YES: Use structured data
  │  └─ NO: Fall back to client-side extraction
  ├─ LatexExtractorService.extractQuestions(rawText)
  │  ├─ Regex: Find options pattern (a) (b) (c) (d)
  │  ├─ Parse: Question text + 4 options
  │  └─ Return: List<ScanData>
  └─ Add to _questionQueue
  [⚠️ Crash risk: Regex failure, <4 options found]

Step 4: User Review & Edit
  ├─ _syncFromQueue() populates form fields
  ├─ User edits question and options in TextFields
  ├─ User sets correct answer
  └─ User picks diagram (optional)
  [⚠️ Crash risk: Widget unmount, memory leak, race condition]

Step 5: Save Question
  ├─ User taps "Save Question"
  ├─ QuestionProvider.saveQuestion(question, diagramFile)
  ├─ ApiService.createQuestionResilient()
  ├─ MultipartRequest POST /api/v1/question/addQuestion
  │  ├─ Fields: question, options[], correctAnswer, classNo, chapter, language
  │  ├─ File: diagram (if selected)
  │  └─ Timeout: 30 seconds
  ├─ Server saves to DB
  ├─ Response: { data: Question object }
  ├─ _questions.insert(0, saved)
  └─ _questionQueue.removeAt(0) [remove from queue]
  [⚠️ Crash risk: Network failure, no retry, file stream leak]

Result:
  ✓ On success: "Question saved successfully"
  ✗ On failure: "Failed to save question" + data lost forever
  ✓ User can retry but must fill form again (good UX)
  ✗ No checkpoint system = wasted effort on timeout
```

---

## Data Models

```
┌─────────────────────────────────────────────────────────┐
│                    DATA STRUCTURES                       │
├─────────────────────────────────────────────────────────┤
│                                                          │
│ AppUser                                                  │
│  ├─ id: String [⚠️ LOST after auto-login]               │
│  ├─ firstName: String                                   │
│  ├─ lastName: String                                    │
│  ├─ phone: String                                       │
│  ├─ role: String (admin/teacher/student)                │
│  ├─ classNo: int (9-12)                                 │
│  ├─ verified: bool                                      │
│  └─ token: String [JWT, 24h expiration]                 │
│                                                          │
│ Exam                                                     │
│  ├─ id: String                                          │
│  ├─ title: String                                       │
│  ├─ duration: int [minutes]                             │
│  └─ questions: List<Question>                           │
│                                                          │
│ Question                                                 │
│  ├─ id: String                                          │
│  ├─ type: String (mcq/numeric)                          │
│  ├─ questionText: String [LaTeX format]                 │
│  ├─ options: List<String> [For MCQ only]                │
│  ├─ correctAnswer: String                               │
│  ├─ classNo: int                                        │
│  ├─ chapter: String                                     │
│  └─ language: String (English/other)                    │
│                                                          │
│ TestAttempt                                              │
│  ├─ id: String                                          │
│  ├─ examId: String                                      │
│  ├─ studentId: String [⚠️ NOT QUERIED]                  │
│  ├─ responses: List<{                                   │
│  │   questionId: String,                                │
│  │   userAnswer: String                                 │
│  │ }>                                                    │
│  ├─ score: int                                          │
│  ├─ createdAt: DateTime                                 │
│  └─ completedAt: DateTime                               │
│                                                          │
│ ScanData [Internal to QuestionProvider]                  │
│  ├─ questionText: String                                │
│  ├─ options: List<String> [4 items]                     │
│  ├─ correctAnswer: String                               │
│  ├─ latex: String?                                      │
│  └─ rawText: String                                     │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## Screen Hierarchy

```
BOTH APPS:
  └─ MathsWithSDApp (MaterialApp)
     └─ _AuthGate [Checks auth status]
        ├─ if authenticated && isAdmin
        │  └─ AdminDashboard
        │     ├─ [Tab 1] AdminQuestions/CreateQuestionTab
        │     │   └─ Form + OCR scan button
        │     ├─ [Tab 2] AdminTests/CreateTestTab
        │     ├─ [Tab 3] ManageStudentsTab
        │     ├─ [Tab 4] QuestionBankTab
        │     ├─ [Tab 5] LeaderboardTab
        │     └─ [Tab 6] YourTestsTab
        │
        ├─ if authenticated && !isAdmin
        │  └─ StudentDashboard
        │     ├─ [Tab 1] AvailableExams
        │     │  └─ Tap exam → ExamAttemptScreen
        │     │     └─ Question palette + Timer + Options
        │     │     └─ On submit → ResultScreen
        │     ├─ [Tab 2] Announcements
        │     └─ [Tab 3] Profile
        │
        ├─ if unauthenticated
        │  ├─ LoginScreen
        │  └─ RegisterScreen
        │
        └─ if loading
           └─ SplashScreen

SHARED WIDGETS:
  ├─ KaTeXWidget [Math rendering via WebView]
  ├─ InlineMathText [Wrapper for text + math]
  └─ Announcements/KaTeX display
```

---

## Timeline: Application Startup Sequence

```
1. main() called
   │
2. WidgetsFlutterBinding.ensureInitialized()
   │
3. [Student only] Check emulator via DeviceInfoPlus
   │  ├─ if emulator: Show warning, exit after 5s
   │  └─ if physical device: Continue
   │
4. Set preferred orientations (portrait only)
   │
5. Create MultiProvider with:
   ├─ AuthProvider (calls tryAutoLogin())
   ├─ ExamProvider
   ├─ [AdminOnly] QuestionProvider
   └─ [AdminOnly] AdminProvider
   │
6. Launch MaterialApp
   │
7. _AuthGate checks AuthProvider.status
   │  ├─ if initial/loading: Show splash
   │  ├─ if authenticated: Navigate to Dashboard (admin/student)
   │  └─ if unauthenticated: Show LoginScreen
   │
8. tryAutoLogin() checks secure storage
   │  ├─ Get token
   │  ├─ Get user info (name, phone, class)
   │  └─ Set user (with empty ID! ⚠️)
   │
9. User interactions → Navigate screens
```

---

## Persistence Architecture

```
┌─────────────────────────────────────────────┐
│         STATE PERSISTENCE LAYER             │
├─────────────────────────────────────────────┤
│                                             │
│ SECURE STORAGE (FlutterSecureStorage)       │
│  ├─ Access token (JWT) [Encrypted]          │
│  ├─ Is admin (bool)                         │
│  ├─ User name, phone, class                 │
│  └─ Cleared on logout                       │
│                                             │
│ SHARED PREFERENCES (Unencrypted)            │
│  ├─ active_attempt_id                       │
│  ├─ active_exam_id                          │
│  ├─ active_answers [JSON string]            │
│  ├─ active_remaining_seconds [int]          │
│  ├─ active_last_tick [milliseconds]         │
│  │  [⚠️ Used to calculate elapsed time]     │
│  └─ Cleared on exam submit/timeout          │
│                                             │
│ In-Memory (Provider State)                  │
│  ├─ _currentQuestionIndex                   │
│  ├─ _userAnswers [Map]                      │
│  ├─ _remainingSeconds [Timer value]         │
│  ├─ _violations [proctoring counter]        │
│  └─ [Lost on app restart]                   │
│                                             │
│ Exam Resumption Flow:                       │
│  1. User starts exam → Save to SharedPrefs  │
│  2. App backgrounded → Data persisted       │
│  3. App killed → Data in SharedPrefs        │
│  4. App relaunched                          │
│  5. ExamAttemptScreen.initState()           │
│  6. checkForResumableExam()                 │
│     ├─ Read from SharedPrefs                │
│     ├─ Calculate elapsed = now - lastTick   │
│     ├─ remaining = cached_remaining - elapsed│
│     └─ Resume if remaining > 0              │
│  7. Timer continues from resumed time       │
│                                             │
│  [⚠️ Race condition: Last save might be     │
│      inconsistent with answer changes]      │
│                                             │
└─────────────────────────────────────────────┘
```

---

## Dependency Injection & Initialization

```
main()
 │
 ├─ MultiProvider creates instances
 │  ├─ AuthProvider()
 │  │  └─ Internally creates: ApiService()
 │  ├─ ExamProvider()
 │  │  └─ Internally creates: ApiService()
 │  ├─ [Admin] QuestionProvider()
 │  │  ├─ Creates: ApiService()
 │  │  └─ Uses: LatexExtractorService (static)
 │  └─ [Admin] AdminProvider()
 │     └─ Creates: ApiService()
 │
 ├─ Each screen wraps in Consumer<Provider>
 │  └─ Listener watches provider state
 │
 └─ On state change → notifyListeners() → rebuild screens

Issues:
  ✗ Multiple ApiService instances (wasteful)
  ✗ ImageService created locally in screens
  ✓ Storage services are static singletons
  ✗ No Dependency Injection framework
```

---

## Critical Path (Worst Case Scenario)

```
User Takes Exam (Exam Duration: 60 minutes)
│
├─ T=0:00 → User opens app
│           ├─ Starts: AuthProvider.tryAutoLogin()
│           └─ User ID lost ⚠️
│
├─ T=0:30 → User selects exam
│           ├─ ExamProvider.startExam()
│           ├─ Backend creates attempt
│           ├─ Timer starts (60 minutes)
│           └─ State saved to SharedPrefs
│
├─ T=30:00 → App backgrounded (user checks message)
│            ├─ didChangeAppLifecycleState(paused)
│            ├─ _violations++ (1/2)
│            ├─ Warning shown
│            └─ Timer still running
│
├─ T=31:00 → User returns to app
│            └─ Exam continues
│
├─ T=32:00 → App crashes (OOM from WebView math)
│            ├─ Provider not disposed cleanly
│            ├─ Timer still ticking in background ⚠️
│            └─ SharedPrefs has frozen state
│
├─ T=32:05 → App relaunched
│            ├─ AuthProvider.tryAutoLogin()
│            ├─ Empty user ID ⚠️
│            ├─ New ExamProvider created
│            ├─ checkForResumableExam() finds old attempt
│            ├─ Calculates: elapsed = 5s + (T=32:00 - T=30:00)
│            │            = 5 + 120 = 125s
│            ├─ remaining = 1800 - 125 = 1675s (27:55 left)
│            ├─ Resume exam with WRONG timer ⚠️
│            └─ Old timer still ticking in background ⚠️
│
├─ T=60:00 → Exam timeout
│            ├─ remainingSeconds == 0
│            ├─ Auto-submit triggered
│            └─ Answers sent to server
│
└─ T=60:05 → Result displayed

[⚠️] = Bug/vulnerability point
```

---

## File Size & Complexity Metrics

| File | Lines | Complexity | Issues |
|------|-------|-----------|--------|
| exam_provider.dart | 250 | HIGH | Timer, race condition |
| api_service.dart | 200 | MEDIUM | No retry, timeout |
| exam_attempt_screen.dart | 400 | HIGH | Lifecycle, state |
| katex_widget.dart | 150 | MEDIUM | WebView leak, XSS |
| image_service.dart | 60 | LOW | Good (student needs fix) |
| question_provider.dart | 150 | MEDIUM | Good OCR flow |
| create_question_screen.dart | 350 | HIGH | Permissions, complex |
| latex_extractor_service.dart | 250 | MEDIUM | Regex patterns |

**Total: ~2,000 lines of business logic**

---

*Generated May 19, 2026 - Complete Architecture Analysis*
