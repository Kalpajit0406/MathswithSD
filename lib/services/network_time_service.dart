import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class NetworkTimeService {
  static final NetworkTimeService _instance = NetworkTimeService._internal();
  factory NetworkTimeService() => _instance;
  NetworkTimeService._internal();

  Duration _timeOffset = Duration.zero;
  bool _isSynced = false;
  Timer? _syncTimer;

  bool get isSynced => _isSynced;

  // Get the current offset
  Duration get timeOffset => _timeOffset;

  // Initialize and start the periodic 10-minute sync
  void initialize() {
    syncTime();
    // Run sync every 10 minutes
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      syncTime();
    });
  }

  // Dispose the sync timer
  void dispose() {
    _syncTimer?.cancel();
  }

  // Get current corrected Indian Standard Time (IST) as a local DateTime
  DateTime get istNow {
    final utc = DateTime.now().toUtc().add(_timeOffset);
    final istTime = utc.add(const Duration(hours: 5, minutes: 30));
    return DateTime(
      istTime.year,
      istTime.month,
      istTime.day,
      istTime.hour,
      istTime.minute,
      istTime.second,
      istTime.millisecond,
    );
  }

  // Get current corrected UTC time
  DateTime get utcNow {
    return DateTime.now().toUtc().add(_timeOffset);
  }

  Future<void> syncTime() async {
    // 1. Try our backend server first (most reliable, matches server clock Authority)
    try {
      final baseUrl = ApiService().baseUrl;
      final response = await http
          .get(Uri.parse('$baseUrl/api/v1/health'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final int? timestamp = data['timestamp'] as int?;
        if (timestamp != null) {
          final apiTime = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
          _timeOffset = apiTime.difference(DateTime.now().toUtc());
          _isSynced = true;
          debugPrint('[NetworkTimeService] Synced via Backend (/api/v1/health): Offset = $_timeOffset');
          return;
        }
      }
    } catch (e) {
      debugPrint('[NetworkTimeService] Backend /api/v1/health sync failed: $e');
    }

    try {
      final baseUrl = ApiService().baseUrl;
      final response = await http
          .get(Uri.parse('$baseUrl/api/health'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final int? timestamp = data['timestamp'] as int?;
        if (timestamp != null) {
          final apiTime = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
          _timeOffset = apiTime.difference(DateTime.now().toUtc());
          _isSynced = true;
          debugPrint('[NetworkTimeService] Synced via Backend (/api/health): Offset = $_timeOffset');
          return;
        }
      }
    } catch (e) {
      debugPrint('[NetworkTimeService] Backend /api/health sync failed: $e');
    }

    // 2. Try WorldTimeAPI (Fallback 1)
    try {
      final response = await http
          .get(Uri.parse('https://worldtimeapi.org/api/timezone/Asia/Kolkata'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final int unixtime = data['unixtime'] as int;
        final apiTime = DateTime.fromMillisecondsSinceEpoch(unixtime * 1000, isUtc: true);
        _timeOffset = apiTime.difference(DateTime.now().toUtc());
        _isSynced = true;
        debugPrint('[NetworkTimeService] Synced via WorldTimeAPI: Offset = $_timeOffset');
        return;
      }
    } catch (e) {
      debugPrint('[NetworkTimeService] WorldTimeAPI sync failed: $e');
    }

    // 3. Try TimeAPI.io (Fallback 2)
    try {
      final response = await http
          .get(Uri.parse('https://timeapi.io/api/Time/current/zone?timeZone=Asia/Kolkata'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String dateTimeStr = data['dateTime'] as String; // e.g. "2026-06-03T08:48:39.123"
        final apiTimeUtc = DateTime.parse('${dateTimeStr}Z').subtract(const Duration(hours: 5, minutes: 30));
        _timeOffset = apiTimeUtc.difference(DateTime.now().toUtc());
        _isSynced = true;
        debugPrint('[NetworkTimeService] Synced via TimeAPI.io: Offset = $_timeOffset');
        return;
      }
    } catch (e) {
      debugPrint('[NetworkTimeService] TimeAPI.io sync failed: $e');
    }

    // 4. Fallback: Check HTTP date header from a highly available server (like google.com)
    try {
      final response = await http
          .head(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 4));
      final dateHeader = response.headers['date'];
      if (dateHeader != null) {
        final parsedDate = HttpDate.parse(dateHeader).toUtc();
        _timeOffset = parsedDate.difference(DateTime.now().toUtc());
        _isSynced = true;
        debugPrint('[NetworkTimeService] Synced via Google date header: Offset = $_timeOffset');
        return;
      }
    } catch (e) {
      debugPrint('[NetworkTimeService] HTTP Date Header sync failed: $e');
    }
  }
}
