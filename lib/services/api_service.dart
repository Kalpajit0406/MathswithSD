import 'package:flutter/foundation.dart';
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
  // Static value from build-time env; resolved at runtime by _getBaseUrl
  final String _staticBaseUrl = AppConstants.baseUrl;
  String? _resolvedBaseUrl;

  Future<String> _getBaseUrl() async {
    if (_resolvedBaseUrl != null && _resolvedBaseUrl!.isNotEmpty) return _resolvedBaseUrl!;
    // Check for a manual override stored in secure storage
    try {
      final override = await AuthStorageService.getBaseUrlOverride();
      if (override != null && override.isNotEmpty) {
        _resolvedBaseUrl = override;
        debugPrint('[ApiService] Using stored base URL override: $override');
        return override;
      }
    } catch (e) {
      debugPrint('[ApiService] Error reading base URL override: $e');
    }

    final candidates = <String>[
      _staticBaseUrl,
      'http://10.0.2.2:5000', // Android emulator
      'http://localhost:5000', // Desktop
    ];
    for (final c in candidates) {
      try {
        final probeUri = Uri.parse('$c${AppConstants.questionsEndpoint}?classNo=1&language=English');
        final resp = await http.get(probeUri).timeout(const Duration(seconds: 3));
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          _resolvedBaseUrl = c;
          debugPrint('[ApiService] Resolved base URL to $c');
          return c;
        }
      } catch (e) {
        debugPrint('[ApiService] Probe failed for $c -> $e');
      }
    }
    debugPrint('[ApiService] Falling back to static base URL: $_staticBaseUrl');
    _resolvedBaseUrl = _staticBaseUrl;
    return _staticBaseUrl;
  }

  Future<Uri> _uri(String endpoint) async {
    final base = await _getBaseUrl();
    return Uri.parse('$base$endpoint');
  }

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

  Future<void> _handleUnauthorized() async {
    debugPrint('[ApiService] 401 Unauthorized - clearing all stored data');
    await AuthStorageService.clearAll();
    // Notify listeners to redirect to login (if using Provider or similar)
  }

  dynamic _processResponse(http.Response response) {
    debugPrint('[ApiService] Response: ${response.statusCode} (${response.request?.url})');
    
    // Handle 401 unauthorized
    if (response.statusCode == 401) {
      _handleUnauthorized();
    }
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        debugPrint('[ApiService] Empty response body');
        return {};
      }
      try {
        final decoded = jsonDecode(response.body);
        debugPrint('[ApiService] Response body (truncated): ${response.body.length > 200 ? response.body.substring(0, 200) + '...' : response.body}');
        return decoded;
      } catch (e) {
        debugPrint('[ApiService] JSON decode error: $e');
        throw ApiException('Invalid JSON response: $e', response.statusCode);
      }
    }
    String message = 'Request failed (${response.statusCode})';
    try {
      final body = jsonDecode(response.body);
      message = body['message'] ?? message;
    } catch (_) {
      debugPrint('[ApiService] Error response body: ${response.body}');
    }
    debugPrint('[ApiService] Error: $message');
    throw ApiException(message, response.statusCode);
  }

  Future<void> _logRequest(String method, Uri uri, Map<String, String>? headers) async {
    debugPrint('[ApiService] Request: $method ${uri.path}');
    if (headers != null) {
      final sanitized = Map<String, String>.from(headers);
      if (sanitized.containsKey('Authorization')) {
        sanitized['Authorization'] = sanitized['Authorization']!.replaceAll(RegExp(r'.{20}'), 'X');
      }
      debugPrint('[ApiService] Headers: $sanitized');
    }
  }

  // ─── Auth ────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String phone, String password) async {
    final uri = await _uri(AppConstants.loginEndpoint);
    final headers = await _headers(includeAuth: false);
    await _logRequest('POST', uri, headers);
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'studentPhone': phone, 'password': password}),
    ).timeout(const Duration(seconds: 20));
    return _processResponse(response);
  }

  Future<http.Response> register(Map<String, dynamic> data) async {
    return await http.post(
      await _uri(AppConstants.registerEndpoint),
      headers: await _headers(includeAuth: false),
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 20));
  }

  // ─── Tests & Exams ───────────────────────────────────────────────────────────

  Future<List<exam.Exam>> fetchExams() async {
    final response = await http.get(
      await _uri(AppConstants.testsEndpoint),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    final data = _processResponse(response);
    final list = data is List ? data : (data['data'] as List? ?? []);
    return list.map((item) => exam.Exam.fromJson(item)).toList();
  }

  Future<String> startAttempt(String examId) async {
    final response = await http.post(
      await _uri(AppConstants.startAttemptEndpoint),
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
      await _uri(AppConstants.submitAttemptEndpoint),
      headers: await _headers(),
      body: jsonEncode(bodyData),
    ).timeout(const Duration(seconds: 15));
    return _processResponse(response);
  }

  // ─── Announcements ────────────────────────────────────────────────────────────

  Future<List<Announcement>> getAnnouncements({String? targetClass}) async {
    final params = <String, String>{};
    if (targetClass != null) params['targetClass'] = targetClass;
    
    final uri = (await _uri(AppConstants.announcementsEndpoint)).replace(queryParameters: params);
    final response = await http.get(
      uri,
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    
    final data = _processResponse(response);
    final list = data['data'] as List? ?? [];
    return list.map((a) => Announcement.fromJson(a)).toList();
  }

  // ─── Analytics ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getPerformance() async {
    final response = await http.get(
      await _uri('/api/v1/analytics/my-performance'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    return _processResponse(response);
  }

  Future<double> fetchExamDifficulty(String examId) async {
    try {
      final response = await http.get(
        await _uri('/api/v1/ratings/exam-analytics/$examId'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 10));
      
      final body = _processResponse(response);
      if (body['success'] == true && body['data'] != null) {
        final List list = body['data'] as List;
        if (list.isNotEmpty) {
          double totalDiff = 0;
          int count = 0;
          for (var item in list) {
            final diffRaw = item['averageDifficulty'];
            if (diffRaw != null) {
              final val = double.tryParse(diffRaw.toString());
              if (val != null) {
                totalDiff += val;
                count++;
              }
            }
          }
          if (count > 0) {
            return totalDiff / count;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching exam difficulty: $e');
    }
    return 3.0; // Default fallback
  }

  // ─── Retry Methods ───────────────────────────────────────────────────────────

  /// Login with exponential backoff retry (1s → 2s → 4s)
  Future<Map<String, dynamic>> loginWithRetry(String phone, String password) async {
    int attempt = 0;
    const maxAttempts = 3;
    Duration delay = const Duration(seconds: 1);

    while (attempt < maxAttempts) {
      try {
        return await login(phone, password);
      } on ApiException catch (e) {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(delay);
        delay = Duration(seconds: delay.inSeconds * 2);
      }
    }
    throw ApiException('Login failed after $maxAttempts attempts', 500);
  }

  /// Fetch exams with retry logic
  Future<List<exam.Exam>> fetchExamsWithRetry() async {
    int attempt = 0;
    const maxAttempts = 3;
    Duration delay = const Duration(seconds: 1);

    while (attempt < maxAttempts) {
      try {
        return await fetchExams();
      } on ApiException catch (e) {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(delay);
        delay = Duration(seconds: delay.inSeconds * 2);
      }
    }
    throw ApiException('Fetch exams failed after $maxAttempts attempts', 500);
  }

  /// Start exam attempt with retry
  Future<String> startAttemptWithRetry(String examId) async {
    int attempt = 0;
    const maxAttempts = 3;
    Duration delay = const Duration(seconds: 1);

    while (attempt < maxAttempts) {
      try {
        return await startAttempt(examId);
      } on ApiException catch (e) {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(delay);
        delay = Duration(seconds: delay.inSeconds * 2);
      }
    }
    throw ApiException('Start attempt failed after $maxAttempts attempts', 500);
  }

  /// Submit answers with retry
  Future<Map<String, dynamic>> submitAnswersWithRetry({
    required String attemptId,
    required List<Map<String, dynamic>> answers,
  }) async {
    int attempt = 0;
    const maxAttempts = 3;
    Duration delay = const Duration(seconds: 1);

    while (attempt < maxAttempts) {
      try {
        return await submitAnswers(attemptId: attemptId, answers: answers);
      } on ApiException catch (e) {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(delay);
        delay = Duration(seconds: delay.inSeconds * 2);
      }
    }
    throw ApiException('Submit answers failed after $maxAttempts attempts', 500);
  }

  /// Get announcements with retry
  Future<List<Announcement>> getAnnouncementsWithRetry({String? targetClass}) async {
    int attempt = 0;
    const maxAttempts = 3;
    Duration delay = const Duration(seconds: 1);

    while (attempt < maxAttempts) {
      try {
        return await getAnnouncements(targetClass: targetClass);
      } on ApiException catch (e) {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(delay);
        delay = Duration(seconds: delay.inSeconds * 2);
      }
    }
    throw ApiException('Get announcements failed after $maxAttempts attempts', 500);
  }

  Future<Map<String, dynamic>> syncOfflineAttempt({
    required String examId,
    required List<Map<String, dynamic>> responses,
  }) async {
    final Map<String, dynamic> bodyData = {
      'examId': examId,
      'responses': responses
          .where((r) => r['questionId'] != null)
          .map((r) => {
                'questionId': r['questionId'],
                'selectedAnswer': r['selectedAnswer'] ?? r['answer'],
                'timeSpent': r['timeSpent'] ?? 0,
              })
          .toList(),
    };

    final response = await http.post(
      await _uri(AppConstants.syncOfflineAttemptEndpoint),
      headers: await _headers(),
      body: jsonEncode(bodyData),
    ).timeout(const Duration(seconds: 20));
    return _processResponse(response);
  }

  Future<Map<String, dynamic>> syncOfflineAttemptWithRetry({
    required String examId,
    required List<Map<String, dynamic>> responses,
  }) async {
    int attempt = 0;
    const maxAttempts = 3;
    Duration delay = const Duration(seconds: 1);

    while (attempt < maxAttempts) {
      try {
        return await syncOfflineAttempt(examId: examId, responses: responses);
      } on ApiException catch (e) {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(delay);
        delay = Duration(seconds: delay.inSeconds * 2);
      }
    }
    throw ApiException('Sync offline attempt failed after $maxAttempts attempts', 500);
  }
}
