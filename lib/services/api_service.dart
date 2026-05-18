import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/question_model.dart';
import '../models/test_model.dart';
import '../models/exam_model.dart' as exam;
import '../utils/constants.dart';
import 'storage_service.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}

class ApiService {
  final String _baseUrl = AppConstants.baseUrl;

  Future<Map<String, String>> _headers({bool includeAuth = true}) async {
    final headers = <String, String>{
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
      return jsonDecode(response.body);
    }
    String message = 'Request failed (${response.statusCode})';
    try {
      final body = jsonDecode(response.body);
      message = body['message'] ?? message;
    } catch (_) {}
    throw ApiException(message, response.statusCode);
  }

  // ─── Auth ────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String phone, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl${AppConstants.loginEndpoint}'),
      headers: await _headers(includeAuth: false),
      body: jsonEncode({'studentPhone': phone, 'password': password}),
    ).timeout(const Duration(seconds: 20));
    return _processResponse(response);
  }

  Future<http.Response> register(Map<String, dynamic> data) async {
    return await http.post(
      Uri.parse('$_baseUrl${AppConstants.registerEndpoint}'),
      headers: await _headers(includeAuth: false),
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 20));
  }

  // ─── Questions ────────────────────────────────────────────────────────────────

  Future<List<Question>> getQuestions({int? classNo, String? language}) async {
    final params = <String, String>{};
    if (classNo != null) params['classNo'] = classNo.toString();
    if (language != null) params['language'] = language;

    final uri = Uri.parse('$_baseUrl${AppConstants.questionsEndpoint}')
        .replace(queryParameters: params);
    final response = await http.get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 15));
    final data = _processResponse(response);
    final list = data['data'] as List? ?? [];
    return list.map((q) => Question.fromJson(q)).toList();
  }

  Future<Question> createQuestion(Question question) async {
    final response = await http.post(
      Uri.parse('$_baseUrl${AppConstants.createQuestionEndpoint}'),
      headers: await _headers(),
      body: jsonEncode(question.toJson()),
    ).timeout(const Duration(seconds: 15));
    final data = _processResponse(response);
    return Question.fromJson(data['data']);
  }

  Future<String> uploadImage(File imageFile) async {
    final token = await AuthStorageService.getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl${AppConstants.uploadImageEndpoint}'),
    );
    request.headers['Authorization'] = 'Bearer ${token ?? ''}';
    request.headers['ngrok-skip-browser-warning'] = 'true';
    request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);
    final data = _processResponse(response);
    return data['data']['url'];
  }

  Future<List<ScanData>> processOcrText(String rawText) async {
    final response = await http.post(
      Uri.parse('$_baseUrl${AppConstants.processOcrEndpoint}'),
      headers: await _headers(),
      body: jsonEncode({'rawText': rawText}),
    ).timeout(const Duration(seconds: 30));
    final data = _processResponse(response);
    final list = data['data'] as List? ?? [];
    return list.map((s) => ScanData.fromJson(s)).toList();
  }

  // ─── Tests ────────────────────────────────────────────────────────────────────

  Future<TestConfig> createTest(Map<String, dynamic> testData) async {
    final response = await http.post(
      Uri.parse('$_baseUrl${AppConstants.createTestEndpoint}'),
      headers: await _headers(),
      body: jsonEncode(testData),
    ).timeout(const Duration(seconds: 15));
    final data = _processResponse(response);
    return TestConfig.fromJson(data['data'] ?? data);
  }

  Future<List<TestConfig>> getAllTests() async {
    final response = await http.get(
      Uri.parse('$_baseUrl${AppConstants.testsEndpoint}'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    final data = _processResponse(response);
    final list = data is List ? data : (data['data'] as List? ?? []);
    return list.map((t) => TestConfig.fromJson(t)).toList();
  }

  Future<List<exam.Exam>> fetchExams(String token) async {
    final response = await http.get(
      Uri.parse('$_baseUrl${AppConstants.testsEndpoint}'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    final data = _processResponse(response);
    final list = data is List ? data : (data['data'] as List? ?? []);
    return list.map((item) => exam.Exam.fromJson(item)).toList();
  }

  Future<String> startAttempt(String examId, String token) async {
    final response = await http.post(
      Uri.parse('$_baseUrl${AppConstants.startAttemptEndpoint}'),
      headers: await _headers(),
      body: jsonEncode({'examId': examId}),
    ).timeout(const Duration(seconds: 15));
    final data = _processResponse(response);
    return data['data']?['id'] ?? data['data']?['_id'] ?? '';
  }

  Future<Map<String, dynamic>> submitAnswers({
    required String attemptId,
    required List<Map<String, dynamic>> answers,
    required String token,
  }) async {
    final Map<String, dynamic> bodyData = {
      'attemptId': attemptId,
      'responses': answers
          .where((a) => a['questionId'] != null)
          .map((a) => {
                'questionId': a['questionId'],
                'userAnswer': a['answer'] ?? a['selectedOption'],
              })
          .toList(),
    };

    final response = await http.post(
      Uri.parse('$_baseUrl${AppConstants.submitAttemptEndpoint}'),
      headers: await _headers(),
      body: jsonEncode(bodyData),
    ).timeout(const Duration(seconds: 15));
    return _processResponse(response);
  }


  // ─── Announcements ────────────────────────────────────────────────────────────

  Future<List<Announcement>> getAnnouncements({String? targetClass}) async {
    final params = <String, String>{};
    if (targetClass != null) params['targetClass'] = targetClass;
    
    final uri = Uri.parse('$_baseUrl${AppConstants.announcementsEndpoint}').replace(queryParameters: params);
    final response = await http.get(
      uri,
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    
    final data = _processResponse(response);
    final list = data['data'] as List? ?? [];
    return list.map((a) => Announcement.fromJson(a)).toList();
  }

  Future<Announcement> createAnnouncement(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$_baseUrl${AppConstants.announcementsEndpoint}/admin'),
      headers: await _headers(),
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 15));
    final responseData = _processResponse(response);
    return Announcement.fromJson(responseData['data'] ?? responseData);
  }

  // ─── Students ─────────────────────────────────────────────────────────────────

  Future<Map<String, List<StudentUser>>> getAllStudents() async {
    final response = await http.get(
      Uri.parse('$_baseUrl${AppConstants.studentsEndpoint}'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    final data = _processResponse(response);
    final payload = data['data'] ?? {};

    List<StudentUser> mapList(dynamic raw) {
      if (raw == null) return [];
      return (raw as List).map((u) => StudentUser.fromJson(u)).toList();
    }

    return {
      'unverified': mapList(payload['unverified']),
      'verified': mapList(payload['verified']),
      'rejected': mapList(payload['rejected']),
    };
  }

  Future<void> acceptStudent(String id) async {
    final response = await http.post(
      Uri.parse('$_baseUrl${AppConstants.acceptStudentEndpoint}'),
      headers: await _headers(),
      body: jsonEncode({'id': id}),
    ).timeout(const Duration(seconds: 10));
    _processResponse(response);
  }

  Future<void> rejectStudent(String id) async {
    final response = await http.post(
      Uri.parse('$_baseUrl${AppConstants.rejectStudentEndpoint}'),
      headers: await _headers(),
      body: jsonEncode({'id': id}),
    ).timeout(const Duration(seconds: 10));
    _processResponse(response);
  }
}
