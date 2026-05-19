import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';

/// Model for offline exam data stored locally
class OfflineExam {
  final String examId;
  final String title;
  final int duration;
  final List<Map<String, dynamic>> questions;
  final DateTime startedAt;
  final DateTime? completedAt;
  final bool isCompleted;
  final String status; // 'started', 'completed', 'synced'

  OfflineExam({
    required this.examId,
    required this.title,
    required this.duration,
    required this.questions,
    required this.startedAt,
    this.completedAt,
    this.isCompleted = false,
    this.status = 'started',
  });

  Map<String, dynamic> toMap() {
    return {
      'examId': examId,
      'title': title,
      'duration': duration,
      'questions': jsonEncode(questions), // Store as string
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'isCompleted': isCompleted ? 1 : 0,
      'status': status,
    };
  }

  factory OfflineExam.fromMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>> questionsList = [];
    try {
      if (map['questions'] != null) {
        final decoded = jsonDecode(map['questions']);
        if (decoded is List) {
          questionsList = List<Map<String, dynamic>>.from(
            decoded.map((q) => Map<String, dynamic>.from(q))
          );
        }
      }
    } catch (e) {
      // fallback
    }
    return OfflineExam(
      examId: map['examId'],
      title: map['title'],
      duration: map['duration'],
      questions: questionsList,
      startedAt: DateTime.parse(map['startedAt']),
      completedAt: map['completedAt'] != null 
        ? DateTime.parse(map['completedAt']) 
        : null,
      isCompleted: map['isCompleted'] == 1,
      status: map['status'],
    );
  }
}

/// Model for offline exam responses
class OfflineResponse {
  final String responseId;
  final String examId;
  final String questionId;
  final String selectedAnswer;
  final int timeSpent;
  final DateTime answeredAt;

  OfflineResponse({
    required this.responseId,
    required this.examId,
    required this.questionId,
    required this.selectedAnswer,
    required this.timeSpent,
    required this.answeredAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'responseId': responseId,
      'examId': examId,
      'questionId': questionId,
      'selectedAnswer': selectedAnswer,
      'timeSpent': timeSpent,
      'answeredAt': answeredAt.toIso8601String(),
    };
  }

  factory OfflineResponse.fromMap(Map<String, dynamic> map) {
    return OfflineResponse(
      responseId: map['responseId'],
      examId: map['examId'],
      questionId: map['questionId'],
      selectedAnswer: map['selectedAnswer'],
      timeSpent: map['timeSpent'],
      answeredAt: DateTime.parse(map['answeredAt']),
    );
  }
}

/// Service for offline exam storage and retrieval
class OfflineExamService {
  static final OfflineExamService _instance = OfflineExamService._internal();
  static Database? _database;

  factory OfflineExamService() {
    return _instance;
  }

  OfflineExamService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String path = join(await getDatabasesPath(), 'offline_exams.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        db.execute(
          '''CREATE TABLE offline_exams(
            examId TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            duration INTEGER NOT NULL,
            questions TEXT NOT NULL,
            startedAt TEXT NOT NULL,
            completedAt TEXT,
            isCompleted INTEGER DEFAULT 0,
            status TEXT DEFAULT 'started'
          )''',
        );
        
        db.execute(
          '''CREATE TABLE offline_responses(
            responseId TEXT PRIMARY KEY,
            examId TEXT NOT NULL,
            questionId TEXT NOT NULL,
            selectedAnswer TEXT NOT NULL,
            timeSpent INTEGER NOT NULL,
            answeredAt TEXT NOT NULL,
            FOREIGN KEY (examId) REFERENCES offline_exams(examId)
          )''',
        );
      },
    );
  }

  /// Save an exam for offline use
  Future<void> saveExamOffline(OfflineExam exam) async {
    final db = await database;
    await db.insert(
      'offline_exams',
      exam.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get a previously saved offline exam
  Future<OfflineExam?> getOfflineExam(String examId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'offline_exams',
      where: 'examId = ?',
      whereArgs: [examId],
    );
    
    if (results.isEmpty) return null;
    return OfflineExam.fromMap(results.first);
  }

  /// Get all offline exams for the current user
  Future<List<OfflineExam>> getAllOfflineExams() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query('offline_exams');
    
    return List.generate(results.length, (i) {
      return OfflineExam.fromMap(results[i]);
    });
  }

  /// Save a response to an offline exam
  Future<void> saveOfflineResponse(OfflineResponse response) async {
    final db = await database;
    await db.insert(
      'offline_responses',
      response.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all responses for an offline exam
  Future<List<OfflineResponse>> getOfflineResponses(String examId) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'offline_responses',
      where: 'examId = ?',
      whereArgs: [examId],
    );
    
    return List.generate(results.length, (i) {
      return OfflineResponse.fromMap(results[i]);
    });
  }

  /// Update exam completion status
  Future<void> completeOfflineExam(String examId) async {
    final db = await database;
    await db.update(
      'offline_exams',
      {
        'isCompleted': 1,
        'completedAt': DateTime.now().toIso8601String(),
        'status': 'completed',
      },
      where: 'examId = ?',
      whereArgs: [examId],
    );
  }

  /// Mark exam as synced to server
  Future<void> markExamAsSynced(String examId) async {
    final db = await database;
    await db.update(
      'offline_exams',
      {'status': 'synced'},
      where: 'examId = ?',
      whereArgs: [examId],
    );
  }

  /// Get exams waiting to be synced
  Future<List<OfflineExam>> getUnsyncedExams() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'offline_exams',
      where: 'status != ?',
      whereArgs: ['synced'],
    );
    
    return List.generate(results.length, (i) {
      return OfflineExam.fromMap(results[i]);
    });
  }

  /// Delete an offline exam and its responses
  Future<void> deleteOfflineExam(String examId) async {
    final db = await database;
    await db.delete(
      'offline_responses',
      where: 'examId = ?',
      whereArgs: [examId],
    );
    await db.delete(
      'offline_exams',
      where: 'examId = ?',
      whereArgs: [examId],
    );
  }

  /// Clear all offline data
  Future<void> clearAllOfflineData() async {
    final db = await database;
    await db.delete('offline_responses');
    await db.delete('offline_exams');
  }
}

// Import needed:
// import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';
