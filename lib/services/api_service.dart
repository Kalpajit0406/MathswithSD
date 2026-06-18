import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
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
  static VoidCallback? onUnauthorized;
  // Static value from build-time env; resolved at runtime by _getBaseUrl
  final String _staticBaseUrl = AppConstants.baseUrl;
  static String? _resolvedBaseUrl;

  String get baseUrl => _resolvedBaseUrl ?? _staticBaseUrl;

  Future<String> _getBaseUrl() async {
    if (_resolvedBaseUrl != null && _resolvedBaseUrl!.isNotEmpty) {
      return _resolvedBaseUrl!;
    }
    // Check for a manual override stored in secure storage
    // (useful for dev builds with --dart-define=API_BASE_URL=http://localhost:5000)
    try {
      final override = await AuthStorageService.getBaseUrlOverride();
      if (override != null && override.isNotEmpty) {
        _resolvedBaseUrl = override;
        if (kDebugMode) debugPrint('[ApiService] Using stored base URL override.');
        return override;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiService] Error reading base URL override: $e');
    }

    // Use the compile-time constant — defaults to production.
    if (kDebugMode) debugPrint('[ApiService] Using static base URL.');
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
    if (kDebugMode) debugPrint('[ApiService] 401 Unauthorized — session cleared.');
    await AuthStorageService.clearAll();
    onUnauthorized?.call();
  }

  Future<dynamic> _parseJson(String body) async {
    if (body.length > 20000) {
      return compute(_jsonDecodeHelper, body);
    }
    return jsonDecode(body);
  }

  static dynamic _jsonDecodeHelper(String body) => jsonDecode(body);

  String _friendlyMessage(int statusCode, String serverMessage) {
    if (serverMessage.isNotEmpty) return serverMessage;
    switch (statusCode) {
      case 401: return 'Your session has expired. Please log in again.';
      case 403: return 'You do not have permission to perform this action.';
      case 404: return 'The requested resource was not found.';
      case 413: return 'The selected file is too large. Please upload a smaller file.';
      case 429: return 'Too many requests. Please wait a moment and try again.';
      case 500:
      case 502:
      case 503:
      case 504: return 'The server encountered an issue. Please try again in a few moments.';
      default:
        return 'An error occurred (HTTP $statusCode). Please try again.';
    }
  }

  Future<dynamic> _processResponse(http.Response response) async {
    // Handle 401 unauthorized
    if (response.statusCode == 401) {
      _handleUnauthorized();
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      try {
        return await _parseJson(response.body);
      } catch (e) {
        if (kDebugMode) debugPrint('[ApiService] JSON decode error: $e');
        throw ApiException('Received an unexpected response. Please try again.', response.statusCode);
      }
    }

    // Map status codes to user-friendly messages
    String serverMessage = '';
    try {
      final body = await _parseJson(response.body);
      serverMessage = (body['message'] as String?) ?? '';
    } catch (_) {}
    final friendlyMessage = _friendlyMessage(response.statusCode, serverMessage);
    if (kDebugMode) debugPrint('[ApiService] Error ${response.statusCode}: $serverMessage');
    throw ApiException(friendlyMessage, response.statusCode);
  }

  /// Safe request wrapper — converts low-level network errors to ApiExceptions
  Future<T> _safeRequest<T>(Future<T> Function() fn,
      {String? operation}) async {
    try {
      return await fn();
    } on SocketException {
      throw ApiException(
        'Unable to connect to the server. Please check your internet connection.',
        0,
      );
    } on TimeoutException {
      throw ApiException(
        'The request timed out. Please try again.',
        408,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ApiService] ${operation ?? 'Request'} failed: $e');
      }
      throw ApiException(
        'An unexpected error occurred. Please try again.',
        500,
      );
    }
  }

  // ─── Auth ────────────────────────────────────────────────────────────────────

  Future<Map<String, String>> _getDeviceBlueprint() async {
    final deviceInfo = DeviceInfoPlugin();
    String androidId = '';
    String model = '';
    String manufacturer = '';

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        androidId = androidInfo.id;
        model = androidInfo.model;
        manufacturer = androidInfo.manufacturer;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        androidId = iosInfo.identifierForVendor ?? '';
        model = iosInfo.model;
        manufacturer = 'Apple';
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    String? installId = prefs.getString('app_install_id');
    if (installId == null) {
      final randomVal = DateTime.now().millisecondsSinceEpoch.toString() + '_' + (100000 + math.Random().nextInt(900000)).toString();
      installId = randomVal;
      await prefs.setString('app_install_id', installId);
    }

    return {
      'androidId': androidId,
      'model': model,
      'manufacturer': manufacturer,
      'appInstallId': installId,
      'platform': Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iOS' : 'unknown'),
    };
  }

  Future<Map<String, dynamic>> login(String phone, String password) async {
    return _safeRequest(operation: 'Login', () async {
      final blueprint = await _getDeviceBlueprint();
      final uri = await _uri(AppConstants.loginEndpoint);
      final headers = await _headers(includeAuth: false);
      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'studentPhone': phone,
              'password': password,
              'deviceBlueprint': blueprint,
            }),
          )
          .timeout(const Duration(seconds: 20));
      final data = await _processResponse(response);
      return Map<String, dynamic>.from(data);
    });
  }

  Future<http.Response> register(Map<String, dynamic> data) async {
    return await http
        .post(
          await _uri(AppConstants.registerEndpoint),
          headers: await _headers(includeAuth: false),
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 20));
  }

  /// Returns { blacklisted: bool, attemptCount: int } for a phone number.
  /// Called before showing the registration loader so we can gate/warn early.
  Future<Map<String, dynamic>> checkPhoneStatus(String phone) async {
    final response = await http
        .get(
          await _uri(
              '${AppConstants.phoneStatusEndpoint}/${Uri.encodeComponent(phone)}'),
          headers: await _headers(includeAuth: false),
        )
        .timeout(const Duration(seconds: 15));
    final data = await _processResponse(response);
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> fetchProfile() async {
    final response = await http
        .get(
          await _uri(AppConstants.profileMeEndpoint),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 15));
    final data = await _processResponse(response);
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> submitProfileEditRequest(
    int classNo,
    String language, {
    bool isJoint = false,
  }) async {
    final response = await http
        .post(
          await _uri(AppConstants.profileEditEndpoint),
          headers: await _headers(),
          body: jsonEncode({
            'classNo': classNo,
            'language': language,
            'isJoint': isJoint,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final data = await _processResponse(response);
    return Map<String, dynamic>.from(data);
  }

  // ─── Tests & Exams ───────────────────────────────────────────────────────────

  Future<List<exam.Exam>> fetchExams() async {
    final response = await http
        .get(await _uri(AppConstants.testsEndpoint), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    final data = await _processResponse(response);
    final list = data is List ? data : (data['data'] as List? ?? []);
    return list.map((item) => exam.Exam.fromJson(item)).toList();
  }

  Future<Map<String, dynamic>> startAttempt(String examId) async {
    final response = await http
        .post(
          await _uri(AppConstants.startAttemptEndpoint),
          headers: await _headers(),
          body: jsonEncode({'examId': examId}),
        )
        .timeout(const Duration(seconds: 15));
    final data = await _processResponse(response);
    return Map<String, dynamic>.from(data['data'] ?? {});
  }

  Future<Map<String, dynamic>> submitAnswers({
    required String attemptId,
    required List<Map<String, dynamic>> answers,
    List<Map<String, dynamic>>? violations,
    bool isAutoSubmitted = false,
    String? autoSubmitReason,
    bool emulatorDetected = false,
    bool rootDetected = false,
  }) async {
    final Map<String, dynamic> bodyData = {
      'attemptId': attemptId,
      'responses': answers
          .where((a) => a['questionId'] != null)
          .map(
            (a) => {
              'questionId': a['questionId'],
              'userAnswer': a['answer'] ?? a['selectedOption'],
            },
          )
          .toList(),
      'violations': ?violations,
      'isAutoSubmitted': isAutoSubmitted,
      'autoSubmitReason': ?autoSubmitReason,
      'emulatorDetected': emulatorDetected,
      'rootDetected': rootDetected,
    };

    final response = await http
        .post(
          await _uri(AppConstants.submitAttemptEndpoint),
          headers: await _headers(),
          body: jsonEncode(bodyData),
        )
        .timeout(const Duration(seconds: 15));
    final data = await _processResponse(response);
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> getResult(String attemptId) async {
    final response = await http
        .get(
          await _uri('${AppConstants.testResponseEndpoint}/result/$attemptId'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 15));
    final data = await _processResponse(response);
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> getResultWithRetry(String attemptId) async {
    int attempt = 0;
    const maxAttempts = 3;
    while (attempt < maxAttempts) {
      try {
        return await getResult(attemptId);
      } catch (e) {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(Duration(milliseconds: 1000 * attempt));
      }
    }
    throw ApiException('Get result failed after $maxAttempts attempts', 500);
  }

  // ─── Announcements ────────────────────────────────────────────────────────────

  Future<List<Announcement>> getAnnouncements({String? targetClass}) async {
    final params = <String, String>{};
    if (targetClass != null) params['targetClass'] = targetClass;

    final uri = (await _uri(
      AppConstants.announcementsEndpoint,
    )).replace(queryParameters: params);
    final response = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 15));

    final data = await _processResponse(response);
    final list = data['data'] as List? ?? [];
    return list.map((a) => Announcement.fromJson(a)).toList();
  }

  // ─── Analytics ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getPerformance({
    String timeframe = 'week',
  }) async {
    final uri = (await _uri(
      '/api/v1/analytics/my-performance',
    )).replace(queryParameters: {'timeframe': timeframe});
    final response = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 15));
    final data = await _processResponse(response);
    return Map<String, dynamic>.from(data);
  }

  Future<double> fetchExamDifficulty(String examId) async {
    try {
      final response = await http
          .get(
            await _uri('/api/v1/ratings/exam-analytics/$examId'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 10));

      final body = await _processResponse(response);
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
      if (kDebugMode) debugPrint('[ApiService] Error fetching exam difficulty: $e');
    }
    return 3.0; // Default fallback
  }

  // ─── Retry Methods ───────────────────────────────────────────────────────────

  /// Login with exponential backoff retry (1s → 2s → 4s)
  Future<Map<String, dynamic>> loginWithRetry(
    String phone,
    String password,
  ) async {
    int attempt = 0;
    const maxAttempts = 3;
    Duration delay = const Duration(seconds: 1);

    while (attempt < maxAttempts) {
      try {
        return await login(phone, password);
      } on ApiException {
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
      } on ApiException {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(delay);
        delay = Duration(seconds: delay.inSeconds * 2);
      }
    }
    throw ApiException('Fetch exams failed after $maxAttempts attempts', 500);
  }

  /// Start exam attempt with retry
  Future<Map<String, dynamic>> startAttemptWithRetry(String examId) async {
    int attempt = 0;
    const maxAttempts = 3;
    Duration delay = const Duration(seconds: 1);

    while (attempt < maxAttempts) {
      try {
        return await startAttempt(examId);
      } on ApiException {
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
    List<Map<String, dynamic>>? violations,
    bool isAutoSubmitted = false,
    String? autoSubmitReason,
    bool emulatorDetected = false,
    bool rootDetected = false,
  }) async {
    int attempt = 0;
    const maxAttempts = 3;
    Duration delay = const Duration(seconds: 1);

    while (attempt < maxAttempts) {
      try {
        return await submitAnswers(
          attemptId: attemptId,
          answers: answers,
          violations: violations,
          isAutoSubmitted: isAutoSubmitted,
          autoSubmitReason: autoSubmitReason,
          emulatorDetected: emulatorDetected,
          rootDetected: rootDetected,
        );
      } on ApiException {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(delay);
        delay = Duration(seconds: delay.inSeconds * 2);
      }
    }
    throw ApiException(
      'Submit answers failed after $maxAttempts attempts',
      500,
    );
  }

  /// Get announcements with retry
  Future<List<Announcement>> getAnnouncementsWithRetry({
    String? targetClass,
  }) async {
    int attempt = 0;
    const maxAttempts = 3;
    Duration delay = const Duration(seconds: 1);

    while (attempt < maxAttempts) {
      try {
        return await getAnnouncements(targetClass: targetClass);
      } on ApiException {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(delay);
        delay = Duration(seconds: delay.inSeconds * 2);
      }
    }
    throw ApiException(
      'Get announcements failed after $maxAttempts attempts',
      500,
    );
  }

  Future<Map<String, dynamic>> syncOfflineAttempt({
    required String examId,
    required List<Map<String, dynamic>> responses,
  }) async {
    final Map<String, dynamic> bodyData = {
      'examId': examId,
      'responses': responses
          .where((r) => r['questionId'] != null)
          .map(
            (r) => {
              'questionId': r['questionId'],
              'selectedAnswer': r['selectedAnswer'] ?? r['answer'],
              'timeSpent': r['timeSpent'] ?? 0,
            },
          )
          .toList(),
    };

    final response = await http
        .post(
          await _uri(AppConstants.syncOfflineAttemptEndpoint),
          headers: await _headers(),
          body: jsonEncode(bodyData),
        )
        .timeout(const Duration(seconds: 20));
    final data = await _processResponse(response);
    return Map<String, dynamic>.from(data);
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
      } on ApiException {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(delay);
        delay = Duration(seconds: delay.inSeconds * 2);
      }
    }
    throw ApiException(
      'Sync offline attempt failed after $maxAttempts attempts',
      500,
    );
  }

  Future<List<String>> getCompletedExamIds() async {
    final response = await http
        .get(
          await _uri('/api/v1/testResponse/completed-exam-ids'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 15));
    final data = await _processResponse(response);
    final list = data['data'] as List? ?? [];
    return list.map((id) => id.toString()).toList();
  }

  Future<List<String>> getCompletedExamIdsWithRetry() async {
    int attempt = 0;
    const maxAttempts = 3;
    Duration delay = const Duration(seconds: 1);

    while (attempt < maxAttempts) {
      try {
        return await getCompletedExamIds();
      } on ApiException {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(delay);
        delay = Duration(seconds: delay.inSeconds * 2);
      }
    }
    return []; // Return empty list on failure rather than crashing
  }

  Future<DateTime> getServerTime() async {
    final response = await http
        .get(
          await _uri('/api/v1/time'),
          headers: await _headers(includeAuth: false),
        )
        .timeout(const Duration(seconds: 10));
    final data = await _processResponse(response);
    final int timeStamp = data['timeStamp'] as int;
    return DateTime.fromMillisecondsSinceEpoch(timeStamp);
  }

  // ─── Self Assessment ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> generateSelfAssessment({
    List<String>? chapters,
    int? limit,
    int? time,
  }) async {
    final response = await http
        .post(
          await _uri('/api/v1/self-assessment/generate'),
          headers: await _headers(),
          body: jsonEncode({
            'chapters': ?chapters,
            'limit': ?limit,
            'time': ?time,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final data = await _processResponse(response);
    return Map<String, dynamic>.from(data['data'] ?? {});
  }

  Future<List<String>> getSelfAssessmentChapters() async {
    final response = await http
        .get(
          await _uri('/api/v1/self-assessment/chapters'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 15));
    final data = await _processResponse(response);
    final list = List<dynamic>.from(data['data'] ?? []);
    return list.map((e) => e.toString()).toList();
  }

  Future<Map<String, dynamic>> getSelfAssessmentQuestion(String token) async {
    final headers = await _headers();
    headers['x-assessment-token'] = token;

    final response = await http
        .get(await _uri('/api/v1/self-assessment/question'), headers: headers)
        .timeout(const Duration(seconds: 15));
    final data = await _processResponse(response);
    return Map<String, dynamic>.from(data['data'] ?? {});
  }

  Future<Map<String, dynamic>> getSelfAssessmentQuestionsBatch(
    String token, {
    int offset = 0,
    int limit = 5,
  }) async {
    final headers = await _headers();
    headers['x-assessment-token'] = token;

    final response = await http
        .get(
          await _uri(
            '/api/v1/self-assessment/questions-batch?offset=$offset&limit=$limit',
          ),
          headers: headers,
        )
        .timeout(const Duration(seconds: 15));
    final data = await _processResponse(response);
    return Map<String, dynamic>.from(data['data'] ?? {});
  }

  Future<Map<String, dynamic>> submitSelfAssessmentAnswer(
    String token,
    String questionId,
    String selectedAnswer,
  ) async {
    final headers = await _headers();
    headers['x-assessment-token'] = token;

    final response = await http
        .post(
          await _uri('/api/v1/self-assessment/submit'),
          headers: headers,
          body: jsonEncode({
            'questionId': questionId,
            'selectedAnswer': selectedAnswer,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final data = await _processResponse(response);
    return Map<String, dynamic>.from(data['data'] ?? {});
  }

  Future<Map<String, dynamic>> submitAllSelfAssessmentAnswers(
    String token,
    Map<String, String> answers,
  ) async {
    final headers = await _headers();
    headers['x-assessment-token'] = token;

    final response = await http
        .post(
          await _uri('/api/v1/self-assessment/submit-all'),
          headers: headers,
          body: jsonEncode({'answers': answers}),
        )
        .timeout(const Duration(seconds: 15));
    final data = await _processResponse(response);
    return Map<String, dynamic>.from(data['data'] ?? {});
  }

  Future<Map<String, dynamic>> sendSelfAssessmentHeartbeat(String token) async {
    final headers = await _headers();
    headers['x-assessment-token'] = token;

    final response = await http
        .post(await _uri('/api/v1/self-assessment/heartbeat'), headers: headers)
        .timeout(const Duration(seconds: 10));
    final data = await _processResponse(response);
    return Map<String, dynamic>.from(data['data'] ?? {});
  }

  String? getDiagramUrl(String? diagramPath) {
    if (diagramPath == null || diagramPath.isEmpty) return null;
    if (diagramPath.startsWith('http')) return diagramPath;
    final base = baseUrl;
    final cleanBase = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final cleanPath = diagramPath.startsWith('/')
        ? diagramPath
        : '/$diagramPath';
    return '$cleanBase$cleanPath';
  }
}
