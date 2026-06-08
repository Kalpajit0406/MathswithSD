import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mathswithsd/screens/student/performance_screen.dart';
import 'package:mathswithsd/providers/auth_provider.dart';
import 'package:mathswithsd/providers/exam_provider.dart';
import 'package:mathswithsd/models/user_model.dart';

class MockAuthProvider extends AuthProvider {
  final AppUser? mockUser;
  final AuthStatus mockStatus;

  MockAuthProvider({this.mockUser, this.mockStatus = AuthStatus.authenticated});

  @override
  AppUser? get user => mockUser;

  @override
  AuthStatus get status => mockStatus;

  @override
  bool get isAuthenticated => mockStatus == AuthStatus.authenticated;
}

class MockExamProvider extends ExamProvider {
  final Map<String, dynamic>? mockPerformanceData;
  final Object? mockError;

  MockExamProvider({this.mockPerformanceData, this.mockError});

  @override
  Future<Map<String, dynamic>?> fetchStudentPerformance({String timeframe = 'week'}) async {
    if (mockError != null) {
      throw mockError!;
    }
    return mockPerformanceData;
  }
}

void main() {
  late AppUser dummyUser;

  setUp(() {
    dummyUser = AppUser(
      id: 'student-123',
      firstName: 'Rohan',
      lastName: 'Sharma',
      phone: '9876543210',
      token: 'mock-jwt-token',
    );
  });

  Widget createTestWidget({
    required AuthProvider authProvider,
    required ExamProvider examProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<ExamProvider>.value(value: examProvider),
      ],
      child: const MaterialApp(
        home: PerformanceScreen(),
      ),
    );
  }

  testWidgets('shows loading indicator while fetching data', (WidgetTester tester) async {
    final auth = MockAuthProvider(mockUser: dummyUser);
    final exam = MockExamProvider(
      mockPerformanceData: null,
    );

    await tester.pumpWidget(createTestWidget(authProvider: auth, examProvider: exam));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('displays performance metrics successfully when data is fetched', (WidgetTester tester) async {
    final auth = MockAuthProvider(mockUser: dummyUser);
    final exam = MockExamProvider(
      mockPerformanceData: {
        'totalAttempts': 12,
        'lastTestPercentage': 85.5,
        'accuracyRate': 78.2,
        'improvementTrend': 4.5,
        'performanceByChapter': {
          'Algebra': {'accuracy': 82.0, 'attempts': 5},
          'Geometry': {'accuracy': 74.0, 'attempts': 7},
        },
        'recentAttempts': [
          {
            'examTitle': 'Algebra Midterm',
            'score': 17,
            'maxScore': 20,
            'date': '2026-06-05',
          },
        ],
      },
    );

    await tester.pumpWidget(createTestWidget(authProvider: auth, examProvider: exam));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify student name greeting
    expect(find.text('Hello, Rohan! 👋'), findsOneWidget);

    // Verify key metrics from metrics grid
    expect(find.text('12'), findsOneWidget); // Total Attempts
    expect(find.text('85.5%'), findsOneWidget); // Last Test Score
    expect(find.text('78.2%'), findsOneWidget); // Accuracy Rate
    expect(find.text('+4.5%'), findsOneWidget); // Improvement

    // Verify chapter performance
    expect(find.text('Algebra'), findsOneWidget);
    expect(find.text('Geometry'), findsOneWidget);

    // Verify recent attempts section
    expect(find.text('Algebra Midterm'), findsOneWidget);
  });

  testWidgets('shows error state and retries on failure', (WidgetTester tester) async {
    final auth = MockAuthProvider(mockUser: dummyUser);
    final exam = MockExamProvider(
      mockError: Exception('Connection failed'),
    );

    await tester.pumpWidget(createTestWidget(authProvider: auth, examProvider: exam));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify error state components
    expect(find.text('Could not load performance data'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
