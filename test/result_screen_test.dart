import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathswithsd/screens/student/result_screen.dart';
import 'package:mathswithsd/models/exam_model.dart';

void main() {
  late List<Question> dummyQuestions;
  late Map<String, String> dummyAnswers;

  setUp(() {
    dummyQuestions = [
      Question(
        id: 'q1',
        type: 'mcq',
        questionText: 'What is 2 + 2?',
        options: ['3', '4', '5', '6'],
        correctAnswer: '4',
      ),
      Question(
        id: 'q2',
        type: 'numeric',
        questionText: 'Solve: x - 5 = 10',
        correctAnswer: '15',
      ),
    ];
    dummyAnswers = {
      'q1': '4', // Correct
      'q2': '20', // Incorrect
    };
  });

  Widget createTestWidget({
    required int score,
    required bool isOffline,
  }) {
    return MaterialApp(
      home: ResultScreen(
        score: score,
        totalQuestions: dummyQuestions.length,
        timeTaken: 125, // 2m 5s
        questions: dummyQuestions,
        userAnswers: dummyAnswers,
        isOffline: isOffline,
      ),
    );
  }

  testWidgets('displays summary results tab details correctly (online)', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget(score: 1, isOffline: false));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // allow animations / fades to run

    // Verify Tab Headers
    expect(find.text('SUMMARY'), findsOneWidget);
    expect(find.text('REVIEW'), findsOneWidget);

    // Verify passed / congratulations score (1/2 = 50% >= 40% passed)
    expect(find.text('Congratulations!'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget); // Score
    expect(find.text('50.0%'), findsNWidgets(2)); // Accuracy and Attempted Accuracy
    expect(find.text('2m 5s'), findsOneWidget); // Time Taken

    // Verify offline notice is NOT displayed
    expect(find.textContaining('completed offline'), findsNothing);
  });

  testWidgets('displays summary results tab details correctly (offline)', (WidgetTester tester) async {
    // Clear dummy answers so totalCorrect is 0 and it shows Keep Practicing!
    dummyAnswers = {};
    await tester.pumpWidget(createTestWidget(score: 0, isOffline: true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify failed / keep practicing score (0/2 = 0% < 40% failed)
    expect(find.text('Keep Practicing!'), findsOneWidget);

    // Verify offline banner/notice is displayed
    expect(find.textContaining('completed offline'), findsOneWidget);
  });

  testWidgets('switches to review tab and displays questions correctness', (WidgetTester tester) async {
    // Restore correct answers for this test
    dummyAnswers = {
      'q1': '4',
      'q2': '20',
    };
    await tester.pumpWidget(createTestWidget(score: 1, isOffline: false));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Tap on the REVIEW tab
    await tester.tap(find.text('REVIEW'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify question 1 is Correct
    expect(find.text('CORRECT'), findsOneWidget);
    expect(find.text('What is 2 + 2?', findRichText: true), findsOneWidget);

    // Verify question 2 is Incorrect
    expect(find.text('INCORRECT'), findsOneWidget);
    expect(find.text('Solve: x - 5 = 10', findRichText: true), findsOneWidget);
  });

  testWidgets('displays correct percentages and counts for 10 questions, 7 attempted, 1 correct scenario using evaluationSummary', (WidgetTester tester) async {
    final List<Question> tenQuestions = List.generate(
      10,
      (i) => Question(
        id: 'q$i',
        type: 'mcq',
        questionText: 'Question $i',
        correctAnswer: 'A',
        options: ['A', 'B', 'C', 'D'],
      ),
    );

    final evaluationSummary = {
      'totalQuestions': 10,
      'attemptedQuestions': 7,
      'unattemptedQuestions': 3,
      'correctQuestions': 1,
      'incorrectQuestions': 6,
      'marksObtained': 1.0,
      'maxMarks': 10.0,
      'accuracyPercent': 10.0,
      'attemptedAccuracyPercent': 14.3,
      'attemptRatePercent': 70.0,
      'questions': [
        {'questionId': 'q0', 'status': 'CORRECT', 'userAnswer': 'A', 'correctAnswer': 'A', 'isCorrect': true},
        {'questionId': 'q1', 'status': 'INCORRECT', 'userAnswer': 'B', 'correctAnswer': 'A', 'isCorrect': false},
        {'questionId': 'q2', 'status': 'INCORRECT', 'userAnswer': 'B', 'correctAnswer': 'A', 'isCorrect': false},
        {'questionId': 'q3', 'status': 'INCORRECT', 'userAnswer': 'B', 'correctAnswer': 'A', 'isCorrect': false},
        {'questionId': 'q4', 'status': 'INCORRECT', 'userAnswer': 'B', 'correctAnswer': 'A', 'isCorrect': false},
        {'questionId': 'q5', 'status': 'INCORRECT', 'userAnswer': 'B', 'correctAnswer': 'A', 'isCorrect': false},
        {'questionId': 'q6', 'status': 'INCORRECT', 'userAnswer': 'B', 'correctAnswer': 'A', 'isCorrect': false},
        {'questionId': 'q7', 'status': 'UNATTEMPTED', 'userAnswer': '', 'correctAnswer': 'A', 'isCorrect': null},
        {'questionId': 'q8', 'status': 'UNATTEMPTED', 'userAnswer': '', 'correctAnswer': 'A', 'isCorrect': null},
        {'questionId': 'q9', 'status': 'UNATTEMPTED', 'userAnswer': '', 'correctAnswer': 'A', 'isCorrect': null},
      ]
    };

    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(
          score: 1,
          totalQuestions: 10,
          timeTaken: 120,
          questions: tenQuestions,
          userAnswers: const {
            'q0': 'A',
            'q1': 'B',
            'q2': 'B',
            'q3': 'B',
            'q4': 'B',
            'q5': 'B',
            'q6': 'B',
          },
          isOffline: false,
          evaluationSummary: evaluationSummary,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // allow animations / fades to run

    // Verify Score is displayed as 1 / 10
    expect(find.text('1 / 10'), findsOneWidget);

    // Verify overall accuracy (Accuracy) is displayed as 10.0%
    expect(find.text('10.0%'), findsOneWidget);

    // Verify Attempted Accuracy is displayed as 14.3%
    expect(find.text('14.3%'), findsOneWidget);

    // Verify counts in row
    expect(find.text('7'), findsOneWidget); // Attempted
    expect(find.text('1'), findsOneWidget); // Correct (Score matches but correct count badge is exactly "1")
    expect(find.text('6'), findsOneWidget); // Incorrect
    expect(find.text('3'), findsOneWidget); // Unattempted

    // Switch to review tab
    await tester.tap(find.text('REVIEW'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify we have CORRECT and INCORRECT labels built for the visible items
    expect(find.text('CORRECT'), findsOneWidget);
    expect(find.text('INCORRECT'), findsAtLeastNWidgets(1));
  });
}
