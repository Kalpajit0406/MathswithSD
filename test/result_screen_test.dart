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
    expect(find.text('50.0%'), findsOneWidget); // Accuracy
    expect(find.text('2m 5s'), findsOneWidget); // Time Taken

    // Verify offline notice is NOT displayed
    expect(find.textContaining('completed offline'), findsNothing);
  });

  testWidgets('displays summary results tab details correctly (offline)', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget(score: 0, isOffline: true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify failed / keep practicing score (0/2 = 0% < 40% failed)
    expect(find.text('Keep Practicing!'), findsOneWidget);

    // Verify offline banner/notice is displayed
    expect(find.textContaining('completed offline'), findsOneWidget);
  });

  testWidgets('switches to review tab and displays questions correctness', (WidgetTester tester) async {
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
}
