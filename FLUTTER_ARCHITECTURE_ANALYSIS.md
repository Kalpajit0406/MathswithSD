# MathsWithSD Flutter Student App - Complete Architecture Analysis

**Created:** May 19, 2026  
**Status:** Comprehensive Architecture Overview + Crash Vulnerability Analysis  
**Scope:** Student App (mathswithsd) + Admin App (mathswithsd_admin) OCR Pipeline

---

## Executive Summary

The MathsWithSD project consists of:
- **Student App** (`mathswithsd`): Exam-taking interface with secure proctoring
- **Admin App** (`mathswithsd_admin`): Question creation with OCR-powered image-to-question conversion

**Critical Finding**: Student app's `constants.dart` is **EMPTY** - the app cannot run without this file being populated with API endpoints.

The Admin app has a sophisticated but fragile image/OCR pipeline with multiple points of failure. The Student app has a robust exam engine with security lockdowns and state persistence but lacks error resilience.

---

## 1. PUBSPEC.YAML - DEPENDENCIES & VERSIONS

### Student App (`mathswithsd/pubspec.yaml`)

```yaml
SDK: ^3.11.5

Core:
  flutter: sdk
  cupertino_icons: ^1.0.8

Networking & HTTP:
  http: ^1.6.0                          # HTTP client (20s timeout default)

State Management:
  provider: ^6.1.5+1                    # ChangeNotifier-based state

Storage:
  shared_preferences: ^2.5.5             # Local unencrypted cache
  flutter_secure_storage: ^9.2.4         # Encrypted secure storage (Android uses EncryptedSharedPreferences)

Image Handling (Profile only):
  image_picker: ^1.2.2                   # Camera/gallery picker (100% quality)
  image_cropper: ^12.2.1                 # Image cropping (no compression config)
  image: ^4.8.0                          # Image decoding
  cached_network_image: ^3.4.1           # Network image caching

Navigation:
  go_router: ^15.1.2                     # Route navigation (NOT USED - using MaterialApp.routes instead)

Math Rendering:
  webview_flutter: ^4.13.0               # KaTeX rendering via HTML/JS bridge

Utilities:
  device_info_plus: ^12.4.0              # Detect emulator (prevents running on emulator)
  intl: ^0.20.2                          # Internationalization
  path_provider: ^2.1.5                  # File system paths
  path: ^1.9.1                           # Path manipulation

Dependency Overrides:
  path_provider_android: 2.2.12          # Pin to avoid conflicts
```

**Notable Absences:**
- No `camera` package - only uses device gallery/camera via system intent
- No `permission_handler` - relies on implicit permissions
- `go_router` imported but NOT USED - mixing MaterialApp.routes with raw Navigator calls

---

### Admin App (`mathswithsd_admin/pubspec.yaml`) - **Additional Dependencies**

```yaml
Additional beyond Student:
  
Camera & Permissions:
  camera: ^0.12.0+1                      # Direct camera access (high-level API)
  permission_handler: ^12.0.1             # Permission requests for Camera/Gallery/Storage

OCR Services:
  (None declared - backend-dependent)

Additional Processing:
  (Same as student app)
```

**Key Difference**: Admin app has **native camera support** while Student app relies on system intent picker.

---

## 2. LIB FOLDER STRUCTURE

### Student App
```
lib/
├── main.dart                           # App entry, emulator check, MultiProvider setup
├── models/
│   ├── user_model.dart                 # AppUser, StudentUser classes
│   ├── exam_model.dart                 # Exam, Question classes (MCQ structure)
│   ├── test_model.dart                 # TestConfig, Announcement classes
│   └── question_model.dart             # (empty or not visible)
├── providers/
│   ├── auth_provider.dart              # AuthStatus enum, login/logout/tryAutoLogin
│   └── exam_provider.dart              # Exam attempt state, timer, persistence engine
├── services/
│   ├── api_service.dart                # HTTP endpoints (login, exams, attempts, announcements)
│   ├── image_service.dart              # pickAndCropImage() - camera/gallery + cropper
│   └── storage_service.dart            # AuthStorageService - secure token storage
├── screens/
│   ├── login_screen.dart               # Phone + password login UI
│   ├── register_screen.dart            # Registration form
│   ├── shared/
│   │   ├── announcements_screen.dart   # Announcement list with images
│   │   └── katex_widget.dart           # KaTeX rendering via WebView + inline math
│   └── student/
│       ├── student_dashboard.dart      # Main dashboard - tests/announcements tabs
│       ├── exam_attempt_screen.dart    # Exam UI - question palette, timer, options
│       ├── profile_screen.dart         # User profile (minimal)
│       └── result_screen.dart          # Score + answer review screen
├── utils/
│   ├── app_theme.dart                  # Material theme (purple primary color #4A148C)
│   └── constants.dart                  # ⚠️ EMPTY FILE - MISSING AppConstants definition
└── widgets/
    ├── animations.dart                 # Animation utilities
    └── fade_in_slide.dart              # FadeInSlide animation widget
```

### Admin App - **Additional**
```
lib/
├── main.dart                           # Same structure, 4 providers (+ AdminProvider, QuestionProvider)
├── providers/
│   ├── auth_provider.dart
│   ├── exam_provider.dart
│   ├── admin_provider.dart             # ⭐ Test management (create, delete)
│   └── question_provider.dart          # ⭐ OCR scanning, question creation, validation
├── services/
│   ├── api_service.dart                # Includes processOcrImage(), createQuestionResilient()
│   ├── image_service.dart              # pickAndCropImage() with 60% quality + getLostData()
│   ├── latex_extractor_service.dart    # ⭐ Client-side OCR fallback (regex-based)
│   └── storage_service.dart
├── screens/
│   ├── shared/
│   │   └── katex_widget.dart           # Same as student
│   ├── student/                        # Same student dashboard/attempt
│   └── admin/
│       ├── admin_dashboard.dart        # Dashboard with 6 tabs
│       ├── create_question_screen.dart # ⭐ OCR scan UI + manual form
│       ├── create_test_screen.dart     # Test builder
│       ├── question_bank_screen.dart   # Question browser/editor
│       ├── your_tests_screen.dart      # Teacher's test management
│       ├── manage_students_screen.dart # Approve/reject students
│       └── leaderboard_screen.dart     # Test results
└── utils/
    ├── app_theme.dart
    ├── constants.dart                  # ✅ Properly populated
    ├── latex_converter.dart            # LaTeX format utilities
    └── constants.dart has classChapters[9-11]
```

---

## 3. MAIN.DART - APP SETUP & NAVIGATION

### Student App Initialization
```dart
main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Security: Block emulator execution
  bool emulator = await _isEmulator();
  if (emulator) {
    runApp(EmulatorWarningApp());
    Future.delayed(5s) → SystemNavigator.pop() or exit(0)
    return;
  }
  
  // Set portrait-only orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..tryAutoLogin()  // ⭐ Auto-login on startup
        ),
        ChangeNotifierProvider(
          create: (_) => ExamProvider()
        ),
      ],
      child: MathsWithSDApp(),
    ),
  );
}

_isEmulator() async {
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  if (Platform.isAndroid) {
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    return !androidInfo.isPhysicalDevice;
  } else if (Platform.isIOS) {
    IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
    return !iosInfo.isPhysicalDevice;
  }
  return false;
}
```

### App Navigation Structure
```dart
MathsWithSDApp extends StatelessWidget {
  build() => MaterialApp(
    title: 'MathsWithSD',
    theme: AppTheme.lightTheme,
    debugShowCheckedModeBanner: false,
    home: _AuthGate(),  // Root navigation
    routes: {
      '/login': LoginScreen(...),
      '/register': RegisterScreen(...),
    }
  );
}

_AuthGate extends StatelessWidget {
  // Consumer<AuthProvider> listens to auth.status
  build() =>
    auth.status == initial/loading
      ? Scaffold(SplashScreen)
    : auth.isAuthenticated
      ? StudentDashboard() (or AdminDashboard if isAdmin)
    : LoginScreen()
}
```

**Navigation Issues:**
- ✅ Clean auth gate pattern
- ❌ Routes defined but rarely used - mostly Navigator.push/pop
- ❌ No GoRouter despite importing it (unnecessary dependency)
- ❌ Hard-coded routes make testing difficult

---

## 4. STATE MANAGEMENT - PROVIDER PATTERN

### AuthProvider (Both Apps)
```dart
class AuthProvider with ChangeNotifier {
  AuthStatus _status;
  AppUser? _user;
  String? _errorMessage;
  bool _isAdmin;
  
  enum AuthStatus {
    initial,         // Before checking token
    loading,         // Attempting login
    authenticated,   // Login successful
    unauthenticated, // No valid token
    error            // Login failed
  }
  
  // ⭐ Auto-login mechanism
  Future<void> tryAutoLogin() async {
    final token = await AuthStorageService.getToken();
    if (token == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    
    // Reconstruct user from secure storage
    _user = AppUser(
      id: '',  // ⚠️ ID not stored - lost
      firstName: await AuthStorageService.getUserFirstName(),
      lastName: await AuthStorageService.getUserLastName(),
      phone: await AuthStorageService.getUserPhone(),
      classNo: await AuthStorageService.getUserClass(),
      token: token,
    );
    _status = AuthStatus.authenticated;
    notifyListeners();
  }
  
  Future<bool> login(String phone, String password) async {
    _status = AuthStatus.loading;
    notifyListeners();
    
    try {
      final response = await _apiService.login(phone, password);
      final data = response['data'];
      
      final accessToken = data['accessToken'];
      final userData = data['student'];
      final role = userData['role'];
      
      _isAdmin = role == 'admin' || role == 'teacher';
      _user = AppUser.fromJson(userData, accessToken);
      
      // Persist to secure storage
      await AuthStorageService.saveToken(accessToken);
      await AuthStorageService.saveIsAdmin(_isAdmin);
      await AuthStorageService.saveUserPhone(_user!.phone);
      await AuthStorageService.saveUserClass(_user!.classNo);
      await AuthStorageService.saveUserName(_user!.firstName, _user!.lastName);
      
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Connection error...';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }
  
  Future<void> logout() async {
    await AuthStorageService.clearAll();
    _user = null;
    _isAdmin = false;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
```

**Issues:**
- ❌ User ID not persisted - tryAutoLogin() sets empty string
- ✅ Good error handling with try-catch blocks
- ✅ Secure storage for sensitive data
- ❌ No timeout for login request (relies on http client timeout)

### ExamProvider (Student App) - **Persistence & Timer Engine**
```dart
class ExamProvider with ChangeNotifier {
  // Current exam state
  List<Exam> _exams;
  int _currentQuestionIndex;
  Map<String, String> _userAnswers;      // questionId -> answer
  int _remainingSeconds;
  Timer? _timer;
  String? _currentAttemptId;
  String? _currentExamId;
  
  // Security: Track app lifecycle violations
  int _violations;
  
  // ⭐ PERSISTENCE ENGINE - LocalStorage for exam resumption
  Future<void> _saveAttemptToPrefs() async {
    if (_currentAttemptId == null) return;
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString('active_attempt_id', _currentAttemptId!);
    await prefs.setString('active_exam_id', _currentExamId!);
    await prefs.setString('active_answers', jsonEncode(_userAnswers));
    await prefs.setInt('active_last_tick', DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt('active_remaining_seconds', _remainingSeconds);
    // Saves every 5 seconds during timer tick
  }
  
  // ⭐ CHECK RESUMABLE EXAM
  Future<Map<String, dynamic>?> checkForResumableExam() async {
    final prefs = await SharedPreferences.getInstance();
    final attemptId = prefs.getString('active_attempt_id');
    if (attemptId == null) return null;
    
    final lastTick = prefs.getInt('active_last_tick') ?? now;
    final cachedRemaining = prefs.getInt('active_remaining_seconds') ?? 0;
    
    // Calculate elapsed time since last save
    final elapsedSeconds = (now - lastTick) ~/ 1000;
    final calculatedRemaining = cachedRemaining - elapsedSeconds;
    
    // If time expired, clear cache
    if (calculatedRemaining <= 0) {
      await _clearAttemptFromPrefs();
      return null;
    }
    
    return {
      'attemptId': attemptId,
      'examId': prefs.getString('active_exam_id'),
      'answers': Map<String, String>.from(jsonDecode(prefs.getString('active_answers'))),
      'remainingSeconds': calculatedRemaining,
    };
  }
  
  // ⭐ TIMER MANAGEMENT
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        if (_remainingSeconds % 5 == 0) {
          await _saveAttemptToPrefs();  // ⚠️ Async called in timer - could race
        }
        notifyListeners();
      } else {
        _timer?.cancel();  // ⚠️ Timer not cancelled in dispose
      }
    });
  }
  
  Future<void> startExam(String examId) async {
    _currentExamId = examId;
    _currentQuestionIndex = 0;
    _userAnswers = {};
    
    final exam = _scheduledTests.firstWhere((e) => e.id == examId);
    _remainingSeconds = exam.duration * 60;
    
    try {
      _currentAttemptId = await _apiService.startAttempt(examId);
      await _saveAttemptToPrefs();
      _startTimer();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
  
  Future<bool> resumeExam(Map<String, dynamic> cachedData) async {
    _currentAttemptId = cachedData['attemptId'];
    _currentExamId = cachedData['examId'];
    _userAnswers = cachedData['answers'];
    _remainingSeconds = cachedData['remainingSeconds'];
    _currentQuestionIndex = 0;
    _startTimer();
    notifyListeners();
    return true;
  }
  
  Future<void> submitExam(List<Map<String, dynamic>> answers) async {
    if (_currentAttemptId == null) return;
    
    _timer?.cancel();  // ⚠️ Only cancelled here, not in dispose
    
    try {
      await _apiService.submitAnswers(
        attemptId: _currentAttemptId!,
        answers: answers,
      );
      _currentAttemptId = null;
      await _clearAttemptFromPrefs();
    } finally {
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    _timer?.cancel();  // ⚠️ May not be called if widget is not properly disposed
    super.dispose();
  }
}
```

**Issues:**
- ⚠️ **Timer-based persistence creates race conditions** - async save in timer tick could overlap
- ⚠️ **SharedPreferences values are strings** - intentional delays during deserialization
- ⚠️ **Timer disposed only in dispose()** - rapid screen transitions could leave timers running
- ✅ Good resumption logic - calculates elapsed time correctly
- ❌ No exponential backoff if submission fails

### QuestionProvider (Admin App Only)
```dart
class QuestionProvider with ChangeNotifier {
  List<Question> _questions;
  List<ScanData> _questionQueue;  // Results from OCR pipeline
  bool _isScanning;
  bool _isSaving;
  String? _creationError;
  
  // ⭐ OCR SCANNING FLOW
  Future<void> scanImage(File imageFile) async {
    _isScanning = true;
    _creationError = null;
    notifyListeners();
    
    try {
      // Send to backend: /api/v1/scan/process
      final ocrResult = await _apiService.processOcrImage(imageFile);
      final rawText = ocrResult['rawText'] ?? '';
      
      if (rawText.isEmpty) {
        _creationError = 'Could not extract text';
      } else {
        // Step 1: Check if backend returned structured MCQ
        if (ocrResult.containsKey('parsedMcq') && ocrResult['parsedMcq'] != null) {
          final parsed = ocrResult['parsedMcq'];
          List<String> options = [];
          for (var opt in parsed['options'] ?? []) {
            options.add((opt is Map) ? opt['text'] : opt.toString());
          }
          
          // Normalize to exactly 4 options
          while (options.length < 4) options.add('');
          if (options.length > 4) options = options.sublist(0, 4);
          
          _questionQueue = [
            ScanData(
              questionText: parsed['question'] ?? '',
              options: options,
              correctAnswer: '',
              latex: ocrResult['latex'],
              rawText: rawText,
            )
          ];
        } else {
          // Step 2: Fallback to client-side extraction
          _questionQueue = LatexExtractorService.extractQuestions(rawText);
        }
      }
    } on ApiException catch (e) {
      _creationError = e.message;
    } catch (e) {
      _creationError = 'Scanning failed. Please try again.';
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }
  
  Future<bool> saveQuestion(Question question, {File? diagramFile}) async {
    _isSaving = true;
    _creationError = null;
    notifyListeners();
    
    try {
      final saved = await _apiService.createQuestionResilient(question, diagramFile: diagramFile);
      _questions.insert(0, saved);
      _isSaving = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _creationError = e.message;
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }
}
```

---

## 5. SERVICES LAYER - API, IMAGE, STORAGE

### ApiService (Core HTTP Layer)
```dart
class ApiService {
  final String _baseUrl = AppConstants.baseUrl;  // http://10.37.148.209:5000
  
  Future<Map<String, String>> _headers({bool includeAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
    if (includeAuth) {
      final token = await AuthStorageService.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }
  
  dynamic _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);  // ⚠️ Can throw on malformed JSON
    }
    String message = 'Request failed (${response.statusCode})';
    try {
      final body = jsonDecode(response.body);
      message = body['message'] ?? message;
    } catch (_) {}
    throw ApiException(message, response.statusCode);
  }
  
  // ⭐ AUTH ENDPOINTS
  Future<Map<String, dynamic>> login(String phone, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl${AppConstants.loginEndpoint}'),
      headers: await _headers(includeAuth: false),
      body: jsonEncode({'studentPhone': phone, 'password': password}),
    ).timeout(Duration(seconds: 20));  // ✅ 20s timeout
    return _processResponse(response);
  }
  
  // ⭐ EXAM ENDPOINTS
  Future<List<Exam>> fetchExams() async {
    final response = await http.get(
      Uri.parse('$_baseUrl${AppConstants.testsEndpoint}'),
      headers: await _headers(),
    ).timeout(Duration(seconds: 15));
    final data = _processResponse(response);
    final list = data is List ? data : (data['data'] as List? ?? []);
    return list.map((item) => Exam.fromJson(item)).toList();
  }
  
  Future<String> startAttempt(String examId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl${AppConstants.startAttemptEndpoint}'),
      headers: await _headers(),
      body: jsonEncode({'examId': examId}),
    ).timeout(Duration(seconds: 15));
    final data = _processResponse(response);
    return data['data']?['id'] ?? data['data']?['_id'] ?? '';
  }
  
  Future<Map<String, dynamic>> submitAnswers({
    required String attemptId,
    required List<Map<String, dynamic>> answers,
  }) async {
    // ⚠️ Response mapping is fragile
    List<Map<String, dynamic>> mappedAnswers = answers
        .where((a) => a['questionId'] != null)
        .map((a) => {
          'questionId': a['questionId'],
          'userAnswer': a['answer'] ?? a['selectedOption'],  // ⚠️ Falls back to undefined key
        })
        .toList();
    
    final response = await http.post(
      Uri.parse('$_baseUrl${AppConstants.submitAttemptEndpoint}'),
      headers: await _headers(),
      body: jsonEncode({'attemptId': attemptId, 'responses': mappedAnswers}),
    ).timeout(Duration(seconds: 15));
    return _processResponse(response);
  }
  
  // ⭐ OCR PIPELINE (Admin Only)
  Future<Map<String, dynamic>> processOcrImage(File file) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl${AppConstants.processOcrEndpoint}'),  // /api/v1/scan/process
      );
      
      final headers = await _headers();
      headers.remove('Content-Type');  // Let multipart set it
      request.headers.addAll(headers);
      request.files.add(await http.MultipartFile.fromPath('image', file.path));
      
      // ⭐ 60-second timeout for Mathpix processing
      final streamedResponse = await request.send().timeout(Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);
      
      final data = _processResponse(response);
      return Map<String, dynamic>.from(data['data'] ?? {});
      
    } on SocketException {
      throw ApiException('Network unreachable. Ensure your server is running.', 503);
    } on TimeoutException {
      throw ApiException('OCR request timed out. Try a smaller crop.', 408);  // ⚠️ User must retry
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Upload failed: ${e.toString()}', 500);
    }
  }
  
  // ⭐ QUESTION CREATION (Admin Only)
  Future<Question> createQuestionResilient(Question question, {File? diagramFile}) async {
    final token = await AuthStorageService.getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl${AppConstants.createQuestionEndpoint}'),
    );
    
    request.headers['Authorization'] = 'Bearer ${token ?? ''}';
    request.headers['ngrok-skip-browser-warning'] = 'true';
    
    // Add text fields
    request.fields['question'] = question.questionText;
    request.fields['options'] = jsonEncode(question.options);
    request.fields['correctAnswer'] = question.correctAnswer;
    request.fields['classNo'] = question.classNo.toString();
    request.fields['chapter'] = question.chapter;
    request.fields['language'] = question.language;
    
    // Add diagram
    if (diagramFile != null) {
      request.files.add(await http.MultipartFile.fromPath('diagram', diagramFile.path));
    }
    
    // ⭐ 30-second timeout for upload
    final streamedResponse = await request.send().timeout(Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);
    
    final data = _processResponse(response);
    return Question.fromJson(data['data']);
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  
  ApiException(this.message, this.statusCode);
  
  @override
  String toString() => message;
}
```

**API Issues:**
- ⚠️ **No retry logic** - single timeout failure = permanent loss of OCR result
- ⚠️ **Multipart streams not explicitly cancelled** on timeout
- ✅ Good timeout configuration (20s login, 15s normal, 60s OCR)
- ❌ No connection pooling or persistent connections
- ❌ Error messages leaked to UI (internal error details exposed)

### ImageService - Image Selection & Cropping

#### Student App Version
```dart
class ImageService {
  final ImagePicker _picker = ImagePicker();
  
  Future<File?> pickAndCropImage(BuildContext context) async {
    final primaryColor = Theme.of(context).primaryColor;
    try {
      // 1. Pick Image from Camera
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,  // ⚠️ FULL QUALITY - can exceed memory limits
      );
      
      if (photo == null) return null;
      
      // 2. Open Crop Screen
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: photo.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Question',
            toolbarColor: primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
          IOSUiSettings(
            title: 'Crop Question',
            aspectRatioPresets: [...],
          ),
        ],
      );
      
      if (croppedFile == null) return null;
      
      return File(croppedFile.path);
    } catch (e) {
      debugPrint("ImageService Error: $e");  // ⚠️ Error swallowed
      return null;
    }
  }
}
```

#### Admin App Version - **Optimized**
```dart
class ImageService {
  final ImagePicker _picker = ImagePicker();
  
  Future<File?> pickAndCropImage(BuildContext context, {ImageSource source = ImageSource.camera}) async {
    try {
      // ⭐ Memory-conscious settings
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 60,        // ✅ 60% quality to save memory
        maxWidth: 1600,          // ✅ Limit dimensions
        maxHeight: 1600,
      );
      
      if (photo == null) return null;
      
      // ⭐ Compress during cropping
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: photo.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 80,  // ✅ Compress on crop
        uiSettings: [...],
      );
      
      if (croppedFile == null) return null;
      
      return File(croppedFile.path);
    } catch (e) {
      debugPrint("ImageService Error: $e");
      return null;
    }
  }
  
  // ⭐ Handle Android process death during camera
  Future<XFile?> getLostData() async {
    if (Platform.isAndroid) {
      final LostDataResponse response = await _picker.retrieveLostData();
      if (response.isEmpty) return null;
      return response.file;
    }
    return null;
  }
}
```

**Image Handling Issues:**
- ⚠️ **Student app uses 100% quality** - OOM crash risk
- ✅ **Admin app optimized** with quality/size limits and lost data recovery
- ❌ **No graceful fallback** if image_picker permission is denied
- ❌ **File cleanup** not guaranteed - orphaned temp files possible

### Storage Service - Secure Token Management
```dart
class AuthStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),  // ✅ Encrypted on Android
  );
  
  // ⭐ Token Management
  static Future<void> saveToken(String token) async {
    await _storage.write(key: AppConstants.tokenKey, value: token);
  }
  
  static Future<String?> getToken() async {
    return await _storage.read(key: AppConstants.tokenKey);
  }
  
  // ⭐ Admin Status
  static Future<void> saveIsAdmin(bool isAdmin) async {
    await _storage.write(key: AppConstants.isAdminKey, value: isAdmin.toString());
  }
  
  // ⭐ User Info (for tryAutoLogin)
  static Future<void> saveUserName(String firstName, String lastName) async {
    await _storage.write(key: AppConstants.userFirstNameKey, value: firstName);
    await _storage.write(key: AppConstants.userLastNameKey, value: lastName);
  }
  
  static Future<String> getUserFirstName() async {
    return await _storage.read(key: AppConstants.userFirstNameKey) ?? '';
  }
  
  static Future<String> getUserLastName() async {
    return await _storage.read(key: AppConstants.userLastNameKey) ?? '';
  }
  
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
  
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
```

**Storage Issues:**
- ✅ Uses encrypted secure storage
- ❌ User ID not stored - breaks auto-login
- ❌ No versioning for storage migration
- ⚠️ Multiple async read calls during tryAutoLogin (could batch them)

---

## 6. SCREENS - UI & USER FLOWS

### Student Dashboard (Main Entry Point)
```dart
class StudentDashboard extends StatefulWidget {
  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> with WidgetsBindingObserver {
  int _selectedTabIndex = 0;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);  // Monitor lifecycle
    _loadInitialData();
  }
  
  void _loadInitialData() {
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    examProvider.loadTests();
    examProvider.loadAnnouncements();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${auth.user?.firstName}'),
        actions: [
          IconButton(icon: Icon(Icons.person), onPressed: _goToProfile),
          IconButton(icon: Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: [
          ExamsTab(),       // Lists available tests
          AnnouncementsTab(), // Announcements with images
          ProfileTab(),     // User profile
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        onTap: (i) => setState(() => _selectedTabIndex = i),
        items: [...],
      ),
    );
  }
}
```

### Exam Attempt Screen - **Proctoring & Timer**
```dart
class ExamAttemptScreen extends StatefulWidget {
  final Exam exam;
  
  @override
  State<ExamAttemptScreen> createState() => _ExamAttemptScreenState();
}

class _ExamAttemptScreenState extends State<ExamAttemptScreen> with WidgetsBindingObserver {
  int _violations = 0;
  bool _isSubmitted = false;
  bool _isInitializing = true;
  String? _initError;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeExam();
  }
  
  // ⭐ EXAM RESUMPTION
  Future<void> _initializeExam() async {
    final provider = Provider.of<ExamProvider>(context, listen: false);
    try {
      final cached = await provider.checkForResumableExam();
      if (cached != null && cached['examId'] == widget.exam.id) {
        // Resume from SharedPreferences
        await provider.resumeExam(cached);
      } else {
        // Start fresh
        await provider.startExam(widget.exam.id);
      }
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _initError = e.toString();
        });
      }
    }
  }
  
  // ⭐ SECURITY: Detect app switching
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isSubmitted || _isInitializing || _initError != null) return;
    
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _violations++;
      if (_violations >= 2) {
        _autoSubmitExam('Multiple security violations detected. Exam auto-submitted.');
      } else {
        _showViolationWarning();
      }
    }
  }
  
  void _showViolationWarning() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.warning, color: Colors.red),
          SizedBox(width: 8),
          Text('Security Warning'),
        ]),
        content: Text('Please do not switch apps during the exam. One more violation will result in automatic submission.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('I Understand', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  Future<void> _autoSubmitExam(String reason) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(reason), backgroundColor: Colors.red),
    );
    await _submit();
  }
  
  // ⭐ SUBMISSION & RESULT CALCULATION
  Future<void> _submit() async {
    if (_isSubmitted) return;
    _isSubmitted = true;
    
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    
    // Calculate score
    int score = 0;
    List<Map<String, dynamic>> finalAnswers = [];
    
    for (var q in widget.exam.questions) {
      String? userAns = examProvider.userAnswers[q.id];
      if (userAns != null && userAns == q.correctAnswer) {
        score++;
      }
      finalAnswers.add({
        'questionId': q.id,
        'answer': userAns,
      });
    }
    
    try {
      await examProvider.submitExam(finalAnswers);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              score: score,
              totalQuestions: widget.exam.questions.length,
              timeTaken: (widget.exam.duration * 60) - examProvider.remainingSeconds,
              questions: widget.exam.questions,
              userAnswers: examProvider.userAnswers,
            ),
          ),
        );
      }
    } catch (e) {
      _isSubmitted = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: Color(0xFFF7F9FB),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF4A148C)),
              SizedBox(height: 20),
              Text(
                'Securing examination environment...',
                style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_initError != null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Color(0xFF4A148C), title: Text('Exam Initialization Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
              SizedBox(height: 20),
              Text('Initialization Failed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              SizedBox(height: 12),
              Text(_initError!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4A148C),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Go Back', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }
    
    final examProvider = Provider.of<ExamProvider>(context);
    final totalQ = widget.exam.questions.length;
    final currentQIndex = examProvider.currentQuestionIndex;
    final currentQ = widget.exam.questions[currentQIndex];
    
    // Check time is up - auto-submit
    if (examProvider.remainingSeconds == 0 && !_isSubmitted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoSubmitExam('Time is up! Exam auto-submitted.');
      });
    }
    
    return PopScope(
      canPop: false,  // ⭐ Block back button
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Color(0xFF4A148C),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Q ${currentQIndex + 1}/$totalQ', style: TextStyle(color: Colors.white, fontSize: 18)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: examProvider.remainingSeconds < 60 ? Colors.red : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer, color: Colors.white, size: 18),
                    SizedBox(width: 4),
                    Text(
                      _formatTime(examProvider.remainingSeconds),
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Submit Exam?'),
                  content: Text('Are you sure you want to submit your answers? You cannot change them later.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _submit();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF4A148C)),
                      child: Text('Submit', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
              child: Text('FINISH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        body: Column(
          children: [
            // Question Palette
            Container(
              height: 60,
              color: Colors.white,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                itemCount: totalQ,
                itemBuilder: (context, i) {
                  bool isAnswered = examProvider.userAnswers.containsKey(widget.exam.questions[i].id);
                  bool isCurrent = i == currentQIndex;
                  return Container(
                    width: 40,
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? Color(0xFF4A148C)
                          : isAnswered
                              ? Color(0xFF4CAF50)
                              : Colors.grey.shade300,
                      shape: BoxShape.circle,
                      border: isCurrent ? Border.all(color: Color(0xFF9C27B0), width: 2) : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: (isCurrent || isAnswered) ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Question & Options
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: Offset(0, 4)),
                        ],
                      ),
                      child: KaTeXWidget(text: currentQ.questionText),  // ⭐ Math rendering
                    ),
                    SizedBox(height: 24),
                    
                    if (currentQ.options != null)
                      ...currentQ.options!.map((opt) {
                        bool isSelected = examProvider.userAnswers[currentQ.id] == opt;
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () => examProvider.setAnswer(currentQ.id, opt),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected ? Color(0xFFF3E5F5) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? Color(0xFF9C27B0) : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                    color: isSelected ? Color(0xFF9C27B0) : Colors.grey,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(child: InlineMathText(text: opt, fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            
            // Navigation
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: Offset(0, -4)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: currentQIndex > 0 ? () => examProvider.previousQuestion() : null,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('PREVIOUS'),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: currentQIndex < totalQ - 1 ? () => examProvider.nextQuestion(totalQ) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF4A148C),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('NEXT', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
```

**Exam Screen Issues:**
- ✅ Good proctoring with lifecycle monitoring
- ✅ Proper back button blocking
- ❌ _violations counter not reset on resume
- ⚠️ Auto-submit happens in build frame callback (could double-execute)

---

## 7. IMAGE/OCR HANDLING - COMPLETE FLOW

### **OCR Pipeline (Admin App Only)**

```
┌─────────────────────────────────────────────────────────────────┐
│ STEP 1: IMAGE SELECTION & CROPPING                              │
└─────────────────────────────────────────────────────────────────┘

User taps "Scan Question"
  ↓
Check camera permission
  ↓
ImageService.pickAndCropImage(source: ImageSource.camera)
  ├─ _picker.pickImage(
  │    source: camera,
  │    imageQuality: 60%,        ✅ Memory optimization
  │    maxWidth: 1600,
  │    maxHeight: 1600
  │  )
  │  ├─ Photo null? Return null
  │  └─ Photo captured → croppedFile variable
  ├─ ImageCropper().cropImage(
  │    sourcePath: photo.path,
  │    compressFormat: jpg,
  │    compressQuality: 80%,      ✅ Compress during crop
  │    uiSettings: [Android + iOS presets]
  │  )
  │  ├─ User crop cancelled? Return null
  │  └─ Crop completed → croppedFile variable
  └─ Return File(croppedFile.path)


⚠️ CRASH POINTS IN IMAGE SELECTION:
1. Permission not granted
   → _picker.pickImage() returns null silently
   → User expects image but gets nothing
   
2. Camera launch fails
   → Platform-level exception
   → Try-catch swallows error, returns null
   → User doesn't know what happened
   
3. Lost data on Android
   → App backgrounded during capture
   → Process death when returning
   → Old image_picker doesn't handle getLostData()
   → ✅ Admin app has getLostData() recovery
   
4. OOM during crop
   → Image dimensions too large
   → Cropper creates temporary bitmap
   → Android kills app if memory exceeds threshold
   ├─ Fixed in Admin: maxWidth/maxHeight limits
   └─ Still broken in Student: 100% quality + no limits

5. File system error
   → Crop output path invalid
   → SD card unmounted during operation
   → Exception swallowed in catch block


┌─────────────────────────────────────────────────────────────────┐
│ STEP 2: OCR PROCESSING (SERVER CALL)                            │
└─────────────────────────────────────────────────────────────────┘

processScannedFile(File file)
  ↓
QuestionProvider.scanImage(file)
  ├─ _isScanning = true
  ├─ _creationError = null
  ├─ notifyListeners() → UI shows "Processing..."
  └─ ApiService.processOcrImage(file)
      └─ http.MultipartRequest POST → /api/v1/scan/process
          ├─ Headers: Authorization Bearer token
          ├─ Files: image (single field)
          ├─ Timeout: 60 seconds              ✅ Long for Mathpix
          └─ Response: {
                data: {
                  rawText: "Question text extracted...",
                  latex: "$LaTeX$ format",
                  parsedMcq: {
                    question: "...",
                    options: [a, b, c, d]
                  }
                }
              }
          
          ⚠️ CRASH POINTS IN OCR UPLOAD:
          
          1. Network disconnection mid-upload
             → SocketException
             → Timeout after 60s
             → User sees "OCR request timed out"
             → Image + time lost, must retry
          
          2. Server processing error (Mathpix fails)
             → Status 500/400
             → Response: { message: "OCR failed" }
             → _creationError set, UI shows error
          
          3. Malformed JSON response
             → _processResponse calls jsonDecode
             → jsonDecode throws FormatException
             → Exception propagates, caught as catch(e)
             → _creationError set to "Scanning failed"
          
          4. Empty response body
             → _processResponse returns {}
             → ocrResult['rawText'] ?? '' → ''
             → _creationError = 'Could not extract text'
             → User doesn't know if image is bad or OCR failed
          
          5. MultipartRequest stream never cancelled
             → Request.send() returns StreamResponse
             → If timeout occurs, stream might continue reading
             → Memory not freed immediately
             → Multiple retries could exhaust buffer


┌─────────────────────────────────────────────────────────────────┐
│ STEP 3: TEXT EXTRACTION & QUESTION PARSING                      │
└─────────────────────────────────────────────────────────────────┘

After OCR response received:

Try backend structured MCQ parsing first:
  if ocrResult['parsedMcq'] != null {
    Parse structured data:
    - question: from parsed['question']
    - options: array → normalize to 4 items
    - Add to _questionQueue
  } else {
    Fall back to client-side:
    LatexExtractorService.extractQuestions(rawText)
      └─ Regex patterns to find:
          ├─ (a) option (b) option ... (Most common)
          ├─ [a] option [b] option
          ├─ a. option b. option
          └─ Line-separated format
      └─ Returns: List<ScanData>


⚠️ CRASH POINTS IN PARSING:
          
1. Backend didn't parse (parsedMcq missing)
   → Falls back to regex extraction
   → Regex might not find options
   → Returns empty list
   → _questionQueue stays empty
   → UI shows nothing
   
2. Regex options extraction fails
   → Malformed question format
   → Less than 4 options found
   → Returns partial list
   → Options array padded with empty strings
   → User confused by blank options
   
3. Special characters in LaTeX
   → Regex doesn't escape properly
   → Match fails
   → Options not extracted
   → User gets raw OCR text instead


┌─────────────────────────────────────────────────────────────────┐
│ STEP 4: USER REVIEW & MODIFICATION                              │
└─────────────────────────────────────────────────────────────────┘

_questionQueue populated:
  ↓
UI syncs from queue:
  _syncFromQueue() copies extracted text to form controllers
  ├─ _questionCtrl.text = scan.questionText
  ├─ For each option: _optCtrls[i].text = scan.options[i]
  └─ _correctCtrl.text = scan.correctAnswer
  ↓
User edits text
  ├─ Modifies question
  ├─ Fixes options
  ├─ Sets correct answer
  ↓
User taps "Save Question"


⚠️ CRASH POINTS IN USER EDITING:
          
1. User modifies form while scan ongoing
   → Timer tick saves state to SharedPrefs
   → Form still accepting input
   → Race condition between UI update and provider state
   
2. Widget unmounted during editing
   → TextField still trying to notify listeners
   → Provider destroyed but controller updating
   → Exception in notifyListeners()
   
3. Large edited text
   → Memory accumulation
   → Multiple TextEditingController instances
   → Not disposed if screen navigation aborted
   
4. Image file reference lost
   → If diagram selected separately
   → Crop operation but file deleted
   → _saveQuestion() uses stale File reference


┌─────────────────────────────────────────────────────────────────┐
│ STEP 5: QUESTION UPLOAD                                          │
└─────────────────────────────────────────────────────────────────┘

QuestionProvider.saveQuestion(question, diagramFile)
  ├─ _isSaving = true
  ├─ notifyListeners() → UI shows spinner
  └─ ApiService.createQuestionResilient(question, diagramFile)
      └─ http.MultipartRequest POST → /api/v1/question/addQuestion
          ├─ Text fields:
          │   ├─ question (questionText)
          │   ├─ options (jsonEncode)
          │   ├─ correctAnswer
          │   ├─ classNo
          │   ├─ chapter
          │   └─ language
          ├─ File field:
          │   └─ diagram (if present)
          ├─ Timeout: 30 seconds
          └─ Response: { data: Question object }


⚠️ CRASH POINTS IN UPLOAD:
          
1. Network failure mid-upload
   → SocketException during stream
   → Timeout after 30s
   → API call throws ApiException
   → Question lost (not saved on backend)
   → NO RETRY MECHANISM
   → User must fill form again
   
2. Server validation failure
   → Response status 400
   → Body: { message: "Invalid chapter" }
   → _processResponse throws ApiException
   → _creationError set
   → Form remains filled (good UX)
   
3. File stream error
   → DiagramFile deleted before upload
   → MultipartFile.fromPath() throws
   → Uncaught exception
   → App crash
   
4. Response deserialization fails
   → Response: { data: null }
   → Question.fromJson(null) → exception
   → Caught as catch(e)
   → _creationError = "Failed to save..."
   
5. Memory exhaustion
   → Large question + diagram
   → JSON encoding + multipart stream
   → Request pending while new request initiated
   → Multiple parallel uploads exhaust buffer
   
6. Provider destroyed during save
   → User navigates away
   → Provider disposed
   → Callback tries to notifyListeners()
   → Exception: "notifyListeners called after dispose"


⚠️⚠️⚠️ CRITICAL: NO RETRY LOGIC
   ✗ If upload fails, everything is lost
   ✗ Form data not persisted
   ✗ Image not saved
   ✗ User must start over
   ✓ Good: Form fields kept for manual re-entry
   ✗ Bad: Question discarded from _questionQueue
```

---

## 8. KATEX RENDERING - MATH DISPLAY

```dart
class KaTeXWidget extends StatefulWidget {
  final String text;
  final double? height;
  
  @override
  State<KaTeXWidget> createState() => _KaTeXWidgetState();
}

class _KaTeXWidgetState extends State<KaTeXWidget> {
  late WebViewController _controller;
  bool _isLoaded = false;
  double _contentHeight = 45.0;
  
  static const String _baseHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/katex.min.css">
  <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/katex.min.js"></script>
  <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/contrib/auto-render.min.js"></script>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, 'Segoe UI', sans-serif;
      font-size: 15px;
      color: #1A1A2E;
      padding: 4px;
      word-wrap: break-word;
      overflow-wrap: break-word;
    }
    #content { visibility: hidden; line-height: 1.6; }
    .katex { font-size: 1.05em; }
    .katex-display { overflow-x: auto; overflow-y: hidden; margin: 0.5em 0; }
  </style>
  <script>
    function sendHeight() {
      if (window.HeightChannel) {
        var height = document.body.scrollHeight || document.documentElement.scrollHeight;
        window.HeightChannel.postMessage(height.toString());
      }
    }
    function renderContent(text) {
      var el = document.getElementById('content');
      el.innerHTML = text;
      if (window.renderMathInElement) {
        renderMathInElement(el, {
          delimiters: [
            {left: '$$', right: '$$', display: true},
            {left: '$', right: '$', display: false},
            {left: '\\(', right: '\\)', display: false},
            {left: '\\[', right: '\\]', display: true}
          ],
          throwOnError: false
        });
        el.style.visibility = 'visible';
        setTimeout(sendHeight, 100);
      } else {
        setTimeout(function(){ renderContent(text); }, 80);
      }
    }
  </script>
</head>
<body>
  <div id="content"></div>
</body>
</html>
''';
  
  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)  // ⚠️ Unrestricted JS
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'HeightChannel',
        onMessageReceived: (JavaScriptMessage message) {
          final height = double.tryParse(message.message);
          if (height != null && mounted) {
            setState(() {
              _contentHeight = height + 12;
            });
          }
        },
      )
      ..loadHtmlString(_baseHtml)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          _updateContent();
          setState(() => _isLoaded = true);
        },
      ));
  }
  
  @override
  void didUpdateWidget(covariant KaTeXWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text && _isLoaded) {
      _updateContent();
    }
  }
  
  void _updateContent() {
    final escaped = widget.text
        .replaceAll('\\', '\\\\')        // Escape backslash
        .replaceAll('"', '\\"')          // Escape quotes
        .replaceAll("'", "\\'")          // Escape single quotes
        .replaceAll('\n', '\\n')         // Escape newlines
        .replaceAll('\r', '');           // Remove carriage returns
    
    // ⚠️ Direct string interpolation - potential XSS
    _controller.runJavaScript("renderContent('$escaped');");
  }
  
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height ?? _contentHeight,
      child: WebViewWidget(controller: _controller),  // Creates WebView for each instance
    );
  }
}

class InlineMathText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color? color;
  
  bool get _hasMath => text.contains(r'$') || text.contains(r'\(') || text.contains(r'\[');
  
  @override
  Widget build(BuildContext context) {
    if (_hasMath) {
      return KaTeXWidget(text: text);  // Creates new WebView for each math text
    }
    return Text(
      text,
      style: TextStyle(fontSize: fontSize, color: color ?? Color(0xFF1A1A2E)),
    );
  }
}
```

**KaTeX Rendering Issues:**

| Issue | Severity | Impact |
|-------|----------|--------|
| **WebView per KaTeX instance** | HIGH | Option: Every MCQ option with math = 4 WebViews on screen. Memory leak if not disposed |
| **Unrestricted JavaScript** | MEDIUM | Could execute malicious LaTeX if backend is compromised |
| **String interpolation for JS** | MEDIUM | Potential XSS if math text contains `'` or `"` (escaped, but still risky) |
| **No error boundary** | MEDIUM | KaTeX render error crashes WebView, exam breaks |
| **Height calculation async** | LOW | Initial height=45px, then jumps when content loads (janky) |
| **NDK CDN dependency** | LOW | CDN unavailable = no math rendering (offline = broken) |
| **No caching** | LOW | Every screen refresh = new HTML/JS load |

---

## 9. NAVIGATION & ROUTING

### Current Implementation (MaterialApp.routes + Navigator)
```dart
MaterialApp(
  home: _AuthGate(),
  routes: {
    '/login': (context) => LoginScreen(...),
    '/register': (context) => RegisterScreen(...),
  },
)

// Navigation
Navigator.pushReplacementNamed(context, '/login');
Navigator.push(context, MaterialPageRoute(builder: (_) => ExamAttemptScreen(...)));
Navigator.pop(context);
```

**Issues:**
- ❌ Mixes named routes with direct navigation (inconsistent)
- ❌ GoRouter imported but not used (wasted dependency)
- ❌ No deep linking support
- ❌ No route guards/middleware
- ✅ Simple enough for small app
- ⚠️ Difficult to test (no route history tracking)

### Recommended: Use GoRouter Instead
```dart
// Define routes once
final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (ctx, state) => _AuthGate()),
    GoRoute(path: '/login', builder: (ctx, state) => LoginScreen()),
    GoRoute(path: '/exam/:id', builder: (ctx, state) => ExamAttemptScreen(examId: state.pathParameters['id']!)),
  ],
);

// Use consistently
context.go('/login');
context.push('/exam/123');
context.pop();
```

---

## 10. CRASH-PRONE AREAS & VULNERABILITY ANALYSIS

### 🔴 CRITICAL CRASH ZONES

#### 1. **Empty Constants File (Student App)**
```dart
// lib/utils/constants.dart is EMPTY
// But imported and used everywhere:
import '../utils/constants.dart';  // ✓ No error during import
final String _baseUrl = AppConstants.baseUrl;  // ❌ RUNTIME ERROR: Class 'AppConstants' not defined

// ERROR: AppConstants is not defined
// The app will CRASH on startup
```

**Impact:** Student app cannot run at all
**Fix:** Populate `constants.dart` with API endpoints (copy from Admin app)

---

#### 2. **Image Picker Permission Crash (Create Question Screen)**
```dart
Future<void> _pickImage(ImageSource source) async {
  if (source == ImageSource.camera) {
    final status = await Permission.camera.request();
    // ⚠️ What if permission request throws?
    // ⚠️ What if OS version doesn't support Permission.camera?
  }
  
  // If permission denied:
  if (!status.isGranted) return;  // Silent return, user doesn't know why
  
  try {
    final file = await _imageService.pickAndCropImage(context, source: source);
    // ⚠️ If permission handler not initialized, crash here
  } catch (e) {
    if (mounted) {
      _showSnack('Image selection failed: $e');  // Too generic
    }
  }
}
```

**Crash Scenarios:**
1. Permission.camera not supported on device
2. Permission request times out (system bug)
3. User denies permission in background
4. Platform-level exception during camera launch

**Fix:**
```dart
Future<void> _pickImage(ImageSource source) async {
  try {
    PermissionStatus status;
    
    if (source == ImageSource.camera) {
      status = await Permission.camera.request();
    } else {
      if (Platform.isAndroid && await AndroidDeviceInfo.SDK >= 33) {
        status = await Permission.photos.request();
      } else {
        status = await Permission.storage.request();
      }
    }
    
    if (status.isDenied) {
      _showSnack('Permission denied. Enable in settings.');
      return;
    }
    
    if (status.isPermanentlyDenied) {
      _showPermissionDialog(source == ImageSource.camera ? 'Camera' : 'Gallery');
      return;
    }
    
    final file = await _imageService.pickAndCropImage(context, source: source);
    if (file != null) {
      _processScannedFile(file);
    }
  } catch (e) {
    debugPrint('Permission error: $e');
    _showSnack('Could not access ${source == ImageSource.camera ? 'camera' : 'gallery'}: $e');
  }
}
```

---

#### 3. **Timer Not Cancelled (Exam Provider)**
```dart
void _startTimer() {
  _timer?.cancel();
  _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
    // ... ticker logic
  });
}

@override
void dispose() {
  _timer?.cancel();  // Called when provider is disposed
  super.dispose();
}

// ⚠️ PROBLEM: If exam screen closes WITHOUT disposing provider
// (e.g., app backgrounded, forced stop), timer keeps running
// ⚠️ Timer ticks cause notifyListeners() on dead provider
// ⚠️ Error: "Provider disposed but listener still active"
```

**Crash Scenario:**
1. User taking exam
2. App backgrounded
3. OS kills process (memory pressure)
4. App relaunched
5. New provider instance created
6. Old timer still running in background thread
7. Timer tick tries to notifyListeners on garbage provider
8. Native crash

**Fix:**
```dart
@override
void dispose() {
  _timer?.cancel();
  _timer = null;  // Explicitly null
  _isScanning = false;  // Stop any pending operations
  _isSaving = false;
  super.dispose();
}

@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.detached) {
    dispose();  // Force cleanup on app exit
  }
}
```

---

#### 4. **OCR Timeout = Lost Data**
```dart
Future<Map<String, dynamic>> processOcrImage(File file) async {
  try {
    final request = http.MultipartRequest(...);
    final streamedResponse = await request.send()
        .timeout(Duration(seconds: 60));  // ⚠️ Hard timeout
    
    final response = await http.Response.fromStream(streamedResponse);
    return _processResponse(response);
    
  } on TimeoutException {
    throw ApiException('OCR request timed out. Try a smaller crop.', 408);
    // ⚠️ Image file lost
    // ⚠️ Question queue cleared
    // ⚠️ No checkpoint to resume
    // ⚠️ User must select image AGAIN
  }
}
```

**Crash/Hang Scenario:**
1. User scans image
2. Network slow (>60s for OCR)
3. Timeout exception thrown
4. Scanner state set to `isScanning = false`
5. Form cleared but image lost
6. User tries again but gets same timeout
7. Repeated retries exhaust battery

**Fix:**
```dart
Future<Map<String, dynamic>> processOcrImage(File file, {int retries = 3}) async {
  for (int attempt = 0; attempt < retries; attempt++) {
    try {
      final request = http.MultipartRequest(...);
      final streamedResponse = await request.send()
          .timeout(Duration(seconds: 60));
      
      final response = await http.Response.fromStream(streamedResponse);
      return _processResponse(response);
      
    } on TimeoutException {
      if (attempt < retries - 1) {
        await Future.delayed(Duration(seconds: 2 * (attempt + 1)));  // Exponential backoff
        continue;  // Retry
      } else {
        // After all retries fail, save image for later
        await _saveFailedImage(file);
        throw ApiException('OCR failed after $retries attempts. Image saved for retry.', 408);
      }
    }
  }
}
```

---

#### 5. **WebView Math Rendering Crash**
```dart
void _updateContent() {
  final escaped = widget.text
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll("'", "\\'")
      .replaceAll('\n', '\\n');
  
  // ⚠️ Direct JavaScript execution
  _controller.runJavaScript("renderContent('$escaped');");
  // If escaped text contains unescaped ', this is XSS
}

// Example vulnerable input:
String text = "Test'; alert('XSS'); //";
// Escaped: "Test\\'; alert(\\'XSS\\'); //"
// JavaScript: renderContent('Test\\'; alert(\\'XSS\\'); //');
// Result: XSS via injected JavaScript
```

**Also:**
```dart
addJavaScriptChannel('HeightChannel', onMessageReceived: (message) {
  final height = double.tryParse(message.message);  // ⚠️ What if not a number?
  if (height != null && mounted) {
    setState(() {
      _contentHeight = height + 12;
    });
  }
  // Silent failure if parsing fails - WebView stays at 45px height
});
```

**Fix:**
```dart
void _updateContent() {
  if (!_isLoaded) return;
  
  try {
    // Use JSON encoding instead of string interpolation
    final json = jsonEncode({'content': widget.text});
    _controller.runJavaScript("""
      try {
        var content = $json;
        renderContent(content.content);
      } catch(e) {
        console.error('Render error:', e);
      }
    """);
  } catch (e) {
    debugPrint('KaTeX update failed: $e');
    setState(() => _contentHeight = 45.0);  // Fallback height
  }
}
```

---

### 🟡 HIGH PRIORITY ISSUES

#### 6. **Race Condition in ExamProvider.saveattemptToPrefs()**
```dart
void _startTimer() {
  _timer?.cancel();
  _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
    if (_remainingSeconds > 0) {
      _remainingSeconds--;
      if (_remainingSeconds % 5 == 0) {
        await _saveAttemptToPrefs();  // ⚠️ Async call in timer callback
        // Timer continues immediately, doesn't wait for save
      }
      notifyListeners();  // UI update
    }
  });
}
```

**Race Condition:**
1. Timer tick at T=10s
2. `_remainingSeconds` = 10
3. `_saveAttemptToPrefs()` called (async, doesn't await)
4. Timer continues, T=11s
5. `_remainingSeconds` = 9
6. User selects answer
7. `_userAnswers` updated
8. T=12s, save completes but uses old `_remainingSeconds` value
9. User continues, but if app crashes, resumes with wrong timer

**Fix:**
```dart
void _startTimer() {
  _timer?.cancel();
  _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
    if (_remainingSeconds > 0) {
      _remainingSeconds--;
      notifyListeners();
      
      // Save on every tick or every N ticks
      if (_remainingSeconds % 5 == 0 || _remainingSeconds <= 5) {
        // Use Future.microtask to ensure atomic update
        await Future.microtask(() => _saveAttemptToPrefs());
      }
    } else {
      _timer?.cancel();
    }
  });
}
```

---

#### 7. **Null Safety Issues in Answer Mapping**
```dart
final bodyData = Map<String, dynamic>{
  'attemptId': attemptId,
  'responses': answers
      .where((a) => a['questionId'] != null)
      .map((a) => {
            'questionId': a['questionId'],
            'userAnswer': a['answer'] ?? a['selectedOption'],  // ⚠️ selectedOption might not exist
          })
      .toList(),
};
```

**Crash:**
- If answer has neither 'answer' nor 'selectedOption' key
- `a['selectedOption']` throws KeyError or returns null
- JSON encode sends `null` as userAnswer
- Server rejects with 400 error

**Fix:**
```dart
'userAnswer': (a['answer'] as String?) ?? (a['selectedOption'] as String?) ?? '',
```

---

#### 8. **Multipart Request Stream Leak**
```dart
Future<String> uploadImage(File imageFile) async {
  final request = http.MultipartRequest('POST', Uri.parse(url));
  request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
  
  // ⚠️ If timeout occurs here, stream is abandoned
  final streamedResponse = await request.send().timeout(Duration(seconds: 30));
  
  final response = await http.Response.fromStream(streamedResponse);
  // If timeout, streamedResponse is half-read, stream not properly closed
  // File handle remains open
  // Repeated uploads can exhaust file descriptor limit
  
  return data['data']['url'];
}
```

**Fix:**
```dart
Future<String> uploadImage(File imageFile) async {
  final request = http.MultipartRequest('POST', Uri.parse(url));
  request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
  
  HttpClientResponse? streamedResponse;
  try {
    streamedResponse = await request.send()
        .timeout(Duration(seconds: 30))
        .onError((error, stackTrace) {
          // Explicitly close on error
          request.files.clear();
          rethrow;
        });
    
    final response = await http.Response.fromStream(streamedResponse);
    return _processResponse(response)['data']['url'];
  } catch (e) {
    streamedResponse?.detachSocket().close().catchError((_) {});  // Force close
    rethrow;
  }
}
```

---

### 🟢 MEDIUM PRIORITY

#### 9. **Lost User ID on Logout/Login**
```dart
Future<void> tryAutoLogin() async {
  final token = await AuthStorageService.getToken();
  if (token == null) return;
  
  _user = AppUser(
    id: '',  // ⚠️ USER ID LOST!
    firstName: await AuthStorageService.getUserFirstName(),
    ...
  );
}
```

**Impact:** User ID is empty after auto-login, breaks downstream API calls that need user ID

**Fix:**
```dart
static Future<void> saveUserId(String id) async {
  await _storage.write(key: AppConstants.userIdKey, value: id);
}

static Future<String> getUserId() async {
  return await _storage.read(key: AppConstants.userIdKey) ?? '';
}

// In tryAutoLogin:
_user = AppUser(
  id: await AuthStorageService.getUserId(),
  ...
);
```

---

#### 10. **Question Queue Never Clears**
```dart
List<ScanData> _questionQueue = [];

Future<void> scanImage(File file) async {
  // ... OCR processing ...
  _questionQueue = [ScanData(...)];  // ⚠️ Replaces queue
  notifyListeners();
}

void popQuestionFromQueue() {
  if (_questionQueue.isNotEmpty) {
    _questionQueue.removeAt(0);
  }
  notifyListeners();
}

// ⚠️ If user scans multiple images without saving,
// queue keeps growing with no limit
// Memory eventually exhausted
```

**Fix:**
```dart
static const int MAX_QUEUE_SIZE = 10;

Future<void> scanImage(File file) async {
  if (_questionQueue.length >= MAX_QUEUE_SIZE) {
    _creationError = 'Too many pending questions. Please save some before scanning more.';
    notifyListeners();
    return;
  }
  
  // ... OCR processing ...
  _questionQueue.add(ScanData(...));  // Add, don't replace
  notifyListeners();
}
```

---

#### 11. **No Offline Support**
```dart
Future<List<Exam>> fetchExams() async {
  final response = await http.get(
    Uri.parse('$_baseUrl${AppConstants.testsEndpoint}'),
    headers: await _headers(),
  ).timeout(Duration(seconds: 15));
  // ⚠️ No offline cache
  // ⚠️ If network down, app shows blank screen
  // ⚠️ User can't even see exam list
  
  return list.map((item) => Exam.fromJson(item)).toList();
}
```

**Fix:** Implement offline-first with local cache
```dart
Future<List<Exam>> fetchExams({bool forceRefresh = false}) async {
  try {
    final response = await http.get(...).timeout(Duration(seconds: 15));
    final data = _processResponse(response);
    
    // Cache locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_exams', jsonEncode(data));
    
    return data;
  } on SocketException {
    // No internet, try cache
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_exams');
    if (cached != null) {
      return List<Exam>.from(jsonDecode(cached));
    }
    throw ApiException('No internet and no cached data', 503);
  }
}
```

---

### 📊 VULNERABILITY MATRIX

| Area | Student App | Admin App | Severity | Mitigation |
|------|------------|-----------|----------|-----------|
| **Constants File** | ❌ EMPTY | ✅ Populated | CRITICAL | Fill in constants |
| **Image Quality** | ❌ 100% | ✅ 60% | HIGH | Reduce quality |
| **Image Limits** | ❌ None | ✅ 1600x1600 | HIGH | Add constraints |
| **Lost Data Handling** | ❌ No | ✅ Yes | HIGH | Add getLostData() |
| **OCR Retry Logic** | ❌ No | ❌ No | HIGH | Implement retry with backoff |
| **Timer Management** | ⚠️ Risky | ✅ Better | HIGH | Ensure disposal |
| **User ID Persistence** | ❌ Not stored | ❌ Not stored | MEDIUM | Store in secure storage |
| **WebView Caching** | ❌ New per instance | ❌ New per instance | MEDIUM | Use singleton or cache |
| **Error Messages** | ⚠️ Generic | ⚠️ Generic | MEDIUM | More specific errors |
| **Network Timeout** | ⚠️ 20s+ | ⚠️ 60s | MEDIUM | Add exponential backoff |
| **Offline Support** | ❌ No | ❌ No | LOW | Implement cache layer |
| **Input Validation** | ⚠️ Basic | ⚠️ Basic | LOW | Server-side primary |

---

## 11. MEMORY MANAGEMENT & STABILITY

### Memory Leak Points
1. **WebView instances** - One per KaTeXWidget, not pooled
2. **Image files** - Temporary crop files not cleaned up on app exit
3. **Timer references** - Could persist if provider not disposed
4. **SharedPreferences cache** - Exam data kept indefinitely
5. **Exam attempt data** - Never purged after submission

### Optimization Recommendations
1. **Image Service:** Clear temporary files after upload
2. **WebView:** Use caching or singleton instance
3. **Timer:** Force cancellation on app background
4. **SharedPrefs:** Implement data expiration (auto-delete exams 30 days old)
5. **Providers:** Use `ChangeNotifier` disposal guards

---

## Summary: Architecture Quality Score

| Component | Quality | Issues |
|-----------|---------|--------|
| **Dependencies** | 8/10 | Missing constants file, unused imports |
| **State Management** | 7/10 | Good provider usage, race conditions in timer |
| **Services Layer** | 6/10 | No retry logic, timeout handling fragile |
| **Screens** | 7/10 | Good UX, but permission handling weak |
| **Image/OCR** | 5/10 | Multiple failure points, no recovery |
| **KaTeX Rendering** | 6/10 | Works but memory inefficient |
| **Navigation** | 7/10 | Clean but inconsistent |
| **Error Handling** | 5/10 | Many silent failures, generic messages |
| **Memory Management** | 5/10 | Potential leaks, no cleanup strategy |
| **Security** | 6/10 | Emulator block, but weak data validation |

**Overall: 6.2/10 - Functional but fragile**

---

## CRITICAL ACTION ITEMS

**Before Release:**
1. ✅ Populate `constants.dart` in Student app
2. ✅ Reduce image quality to 60% in Student app  
3. ✅ Add max dimensions to image picker
4. ✅ Implement retry logic for OCR uploads
5. ✅ Fix timer disposal in ExamProvider
6. ✅ Add proper error boundaries for WebView
7. ✅ Store user ID in secure storage
8. ✅ Implement offline exam list caching

---

*This analysis is based on complete code review of both Flutter apps as of May 19, 2026. Generated for MathsWithSD project architecture assessment.*
