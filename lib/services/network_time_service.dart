import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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

  // Get current corrected Indian Standard Time (IST)
  DateTime get istNow {
    final utc = DateTime.now().toUtc().add(_timeOffset);
    return utc.add(const Duration(hours: 5, minutes: 30));
  }

  // Get current corrected UTC time
  DateTime get utcNow {
    return DateTime.now().toUtc().add(_timeOffset);
  }

  Future<void> syncTime() async {
    // Try WorldTimeAPI
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

    // Try TimeAPI.io fallback
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

    // Fallback: Check HTTP date header from a highly available server (like google.com)
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
