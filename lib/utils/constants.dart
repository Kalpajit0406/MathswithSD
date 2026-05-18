class AppConstants {
  // Use local LAN IP since you are testing on a physical device
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.37.148.88:5000',
  );
  // static const String baseUrl = 'http://10.0.2.2:5000'; // For emulator
  // API Endpoints
  static const String loginEndpoint = '/api/v1/student/login';
  static const String registerEndpoint = '/api/v1/student/register';
  static const String questionsEndpoint = '/api/v1/question/questions';
  static const String createQuestionEndpoint = '/api/v1/question/addQuestion'; // updated
  static const String uploadImageEndpoint = '/api/v1/scan'; // updated
  static const String processOcrEndpoint = '/api/v1/scan/process'; // Assuming this or similar, wait I will handle OCR in dart if it doesn't exist
  static const String testsEndpoint = '/api/v1/tests';
  static const String createTestEndpoint = '/api/v1/tests/create';
  static const String announcementsEndpoint = '/api/v1/announcements'; // Will be mocked
  static const String studentsEndpoint = '/api/v1/student/students';
  static const String acceptStudentEndpoint = '/api/v1/student/accept';
  static const String rejectStudentEndpoint = '/api/v1/student/reject';
  static const String startAttemptEndpoint = '/api/v1/testResponse/start';
  static const String submitAttemptEndpoint = '/api/v1/testResponse/submit';
  static const String testResponseEndpoint = '/api/v1/testResponse';

  // Storage Keys
  static const String tokenKey = 'access_token';
  static const String isAdminKey = 'is_admin';
  static const String userPhoneKey = 'user_phone';
  static const String userClassKey = 'user_class';
  static const String userFirstNameKey = 'user_first_name';
  static const String userLastNameKey = 'user_last_name';
}

class AppColors {
  // Admin Theme - Teal/Cyan
  static const int adminPrimary = 0xFF006064;
  static const int adminLight = 0xFFE0F7FA;
  static const int adminAccent = 0xFF00BCD4;

  // Student Theme - Purple
  static const int studentPrimary = 0xFF4A148C;
  static const int studentLight = 0xFFF3E5F5;
  static const int studentAccent = 0xFF9C27B0;

  // General
  static const int teal = 0xFF009688;
  static const int deepPurple = 0xFF673AB7;
  static const int blue = 0xFF1565C0;
  static const int orange = 0xFFFF9800;
  static const int pink = 0xFFE91E63;
  static const int green = 0xFF43A047;
  static const int red = 0xFFE53935;
  static const int gold = 0xFFFFD700;

  // Answer palette
  static const int answered = 0xFF43A047;
  static const int markedReview = 0xFF9C27B0;
  static const int unanswered = 0xFF9E9E9E;
  static const int current = 0xFF1565C0;
}
