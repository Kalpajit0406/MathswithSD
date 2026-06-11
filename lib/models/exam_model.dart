import 'package:flutter/foundation.dart';

class Exam {
  final String id;
  final String title;
  final int duration;
  final List<Question> questions;
  final String date;
  final String time;
  final int classNo;
  final String language;

  Exam({
    required this.id,
    required this.title,
    required this.duration,
    required this.questions,
    required this.date,
    required this.time,
    required this.classNo,
    required this.language,
  });

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      id: json['id'] ?? json['_id'] ?? '',
      title: json['title'] ?? '',
      duration: json['duration'] ?? 0,
      questions: (json['questions'] as List? ?? [])
          .map((q) => Question.fromJson(q))
          .toList(),
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      classNo: json['classNo'] ?? 10,
      language: json['language'] ?? 'English',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'duration': duration,
      'questions': questions.map((q) => q.toJson()).toList(),
      'date': date,
      'time': time,
      'classNo': classNo,
      'language': language,
    };
  }

  // Parses date and time into a DateTime object
  DateTime? getExamDateTime() {
    try {
      String cleanDate = date.trim();
      String cleanTime = time.trim();
      if (cleanDate.isEmpty || cleanTime.isEmpty) return null;
      
      int year = 0, month = 0, day = 0;
      if (cleanDate.contains('/')) {
        final parts = cleanDate.split('/');
        if (parts.length == 3) {
          day = int.parse(parts[0]);
          month = int.parse(parts[1]);
          year = int.parse(parts[2]);
        }
      } else if (cleanDate.contains('-')) {
        final parts = cleanDate.split('-');
        if (parts.length == 3) {
          year = int.parse(parts[0]);
          month = int.parse(parts[1]);
          day = int.parse(parts[2]);
        }
      } else {
        return DateTime.parse(cleanDate);
      }
      
      int hour = 0, minute = 0;
      final timeParts = cleanTime.split(':');
      if (timeParts.length >= 2) {
        hour = int.parse(timeParts[0]);
        final minPart = timeParts[1].replaceAll(RegExp(r'[^0-9]'), '');
        minute = int.parse(minPart);
        
        final isPm = cleanTime.toLowerCase().contains('pm');
        final isAm = cleanTime.toLowerCase().contains('am');
        if (isPm && hour < 12) {
          hour += 12;
        } else if (isAm && hour == 12) {
          hour = 0;
        }
      }
      
      return DateTime(year, month, day, hour, minute);
    } catch (e) {
      debugPrint('Error parsing exam datetime: $e');
      return null;
    }
  }
}

class Question {
  final String id;
  final String type; // 'mcq' or 'numeric'
  final String questionText;
  final List<String>? options;
  final String? correctAnswer;
  final String? diagram;

  Question({
    required this.id,
    required this.type,
    required this.questionText,
    this.options,
    this.correctAnswer,
    this.diagram,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] ?? '',
      type: json['type'] ?? 'mcq',
      questionText: json['questionText'] ?? '',
      options: json['options'] != null ? List<String>.from(json['options']) : null,
      correctAnswer: json['correctAnswer'],
      diagram: json['diagram'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'questionText': questionText,
      'options': options,
      'correctAnswer': correctAnswer,
      'diagram': diagram,
    };
  }
}
