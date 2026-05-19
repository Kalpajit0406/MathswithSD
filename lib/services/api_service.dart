import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
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

  // ─── Tests & Exams ───────────────────────────────────────────────────────────

  Future<List<exam.Exam>> fetchExams() async {
    final response = await http.get(
      Uri.parse('$_baseUrl${AppConstants.testsEndpoint}'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    final data = _processResponse(response);
    final list = data is List ? data : (data['data'] as List? ?? []);
    return list.map((item) => exam.Exam.fromJson(item)).toList();
  }

  Future<String> startAttempt(String examId) async {
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
}
