import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
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
  String? _resolvedBaseUrl;

  String get baseUrl => _resolvedBaseUrl ?? _staticBaseUrl;

  Future<String> _getBaseUrl() async {
    if (_resolvedBaseUrl != null && _resolvedBaseUrl!.isNotEmpty) {
      return _resolvedBaseUrl!;
    }
    // Check for a manual override stored in secure storage
    try {
      final override = await AuthStorageService.getBaseUrlOverride();
      if (override != null && override.isNotEmpty) {
        final overrideResolved = await _probeBaseUrl(override);
        if (overrideResolved) {
          _resolvedBaseUrl = override;
          debugPrint('[ApiService] Using stored base URL override: $override');
          return override;
        }
        debugPrint(
          '[ApiService] Stored base URL override is unreachable, rediscovering: $override',
        );
      }
    } catch (e) {
      debugPrint('[ApiService] Error reading base URL override: $e');
    }

    final candidates = <String>[
      'http://10.0.2.2:5000', // Android emulator
      'http://localhost:5000', // Desktop
    ];
    for (final c in candidates) {
      try {
        if (await _probeBaseUrl(c)) {
          _resolvedBaseUrl = c;
          await AuthStorageService.saveBaseUrlOverride(c);
          debugPrint('[ApiService] Resolved base URL to $c via health probe');
          return c;
        }
      } catch (e) {
        debugPrint('[ApiService] Probe failed for $c -> $e');
      }
    }

    // Try LAN subnet discovery as a final fallback for physical devices.
    try {
      final discovered = await _discoverLanBackendBaseUrl();
      if (discovered != null && discovered.isNotEmpty) {
        _resolvedBaseUrl = discovered;
        await AuthStorageService.saveBaseUrlOverride(discovered);
        debugPrint(
          '[ApiService] Resolved base URL via LAN discovery to $discovered',
        );
        return discovered;
      }
    } catch (e) {
      debugPrint('[ApiService] LAN discovery failed: $e');
    }

    debugPrint('[ApiService] Falling back to static base URL: $_staticBaseUrl');
    _resolvedBaseUrl = _staticBaseUrl;
    return _staticBaseUrl;
  }

  Future<bool> _probeBaseUrl(String baseUrl) async {
    try {
      final probeUri = Uri.parse('$baseUrl/health');
      final isRemote = baseUrl.startsWith('https://');
      final timeoutMs = isRemote ? 8000 : 1500;
      final resp = await http
          .get(probeUri)
          .timeout(Duration(milliseconds: timeoutMs));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<String?> _discoverLanBackendBaseUrl() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );

    final candidates = <String>{};
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        final octets = address.address.split('.');
        if (octets.length != 4) continue;

        final prefix = '${octets[0]}.${octets[1]}.${octets[2]}';
        final lastOctet = int.tryParse(octets[3]);
        final commonHosts = <int>{
          1,
          2,
          3,
          4,
          5,
          10,
          11,
          20,
          50,
          100,
          101,
          110,
          111,
          120,
          125,
          150,
          200,
          254,
        };
        if (lastOctet != null) commonHosts.remove(lastOctet);

        for (final host in commonHosts) {
          candidates.add('http://$prefix.$host:5000');
        }

        // Full /24 scan
        for (var host = 1; host <= 254; host++) {
          if (lastOctet == host) continue;
          candidates.add('http://$prefix.$host:5000');
        }
      }
    }

    if (candidates.isEmpty) return null;

    final candidateList = candidates.toList();
    String? foundUrl;

    const batchSize = 40;
    for (var i = 0; i < candidateList.length; i += batchSize) {
      final end = (i + batchSize < candidateList.length)
          ? i + batchSize
          : candidateList.length;
      final batch = candidateList.sublist(i, end);

      await Future.wait(
        batch.map((url) async {
          if (foundUrl != null) return;
          final ok = await _probeBaseUrl(url);
          if (ok) {
            foundUrl = url;
          }
        }),
      );

      if (foundUrl != null) {
        return foundUrl;
      }
    }

    return null;
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
    onUnauthorized?.call();
  }

  Future<dynamic> _parseJson(String body) async {
    if (body.length > 20000) {
      return compute(_jsonDecodeHelper, body);
    }
    return jsonDecode(body);
  }

  static dynamic _jsonDecodeHelper(String body) => jsonDecode(body);

  Future<dynamic> _processResponse(http.Response response) async {
    debugPrint(
      '[ApiService] Response: ${response.statusCode} (${response.request?.url})',
    );

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
        final decoded = await _parseJson(response.body);
        debugPrint(
          '[ApiService] Response body (truncated): ${response.body.length > 200 ? '${response.body.substring(0, 200)}...' : response.body}',
        );
        return decoded;
      } catch (e) {
        debugPrint('[ApiService] JSON decode error: $e');
        throw ApiException('Invalid JSON response: $e', response.statusCode);
      }
    }
    String message = 'Request failed (${response.statusCode})';
    try {
      final body = await _parseJson(response.body);
      message = body['message'] ?? message;
    } catch (_) {
      debugPrint('[ApiService] Error response body: ${response.body}');
    }
    debugPrint('[ApiService] Error: $message');
    throw ApiException(message, response.statusCode);
  }

  Future<void> _logRequest(
    String method,
    Uri uri,
    Map<String, String>? headers,
  ) async {
    debugPrint('[ApiService] Request: $method ${uri.path}');
    if (headers != null) {
      final sanitized = Map<String, String>.from(headers);
      if (sanitized.containsKey('Authorization')) {
        sanitized['Authorization'] = sanitized['Authorization']!.replaceAll(
          RegExp(r'.{20}'),
          'X',
        );
      }
      debugPrint('[ApiService] Headers: $sanitized');
    }
  }

  // ─── Auth ────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String phone, String password) async {
    final uri = await _uri(AppConstants.loginEndpoint);
    final headers = await _headers(includeAuth: false);
    await _logRequest('POST', uri, headers);
    final response = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode({'studentPhone': phone, 'password': password}),
        )
        .timeout(const Duration(seconds: 20));
    final data = await _processResponse(response);
    return Map<String, dynamic>.from(data);
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
      debugPrint('Error fetching exam difficulty: $e');
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

  Future<Map<String, dynamic>> generateSelfAssessment() async {
    final response = await http
        .post(
          await _uri('/api/v1/self-assessment/generate'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 15));
    final data = await _processResponse(response);
    return Map<String, dynamic>.from(data['data'] ?? {});
  }

  Future<Map<String, dynamic>> getSelfAssessmentQuestion(String token) async {
    final headers = await _headers();
    headers['x-assessment-token'] = token;

    final response = await http
        .get(
          await _uri('/api/v1/self-assessment/question'),
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

  Future<Map<String, dynamic>> sendSelfAssessmentHeartbeat(String token) async {
    final headers = await _headers();
    headers['x-assessment-token'] = token;

    final response = await http
        .post(
          await _uri('/api/v1/self-assessment/heartbeat'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));
    final data = await _processResponse(response);
    return Map<String, dynamic>.from(data['data'] ?? {});
  }
}
