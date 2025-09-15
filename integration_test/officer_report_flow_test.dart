import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:m_clearance_imigrasi/app/providers/language_provider.dart';
import 'package:provider/provider.dart';
import 'package:m_clearance_imigrasi/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Officer Report Flow', () {
    testWidgets('Login as officer and verify report generation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LanguageProvider(),
          child: const app.MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Login as officer
      await tester.enterText(find.byKey(const Key('emailField')), 'officer@test.com');
      await tester.enterText(find.byKey(const Key('passwordField')), 'password123');
      await tester.tap(find.byKey(const Key('loginButton')));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Navigate to Officer Report Screen
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // Tap the "Generate Report" button
      await tester.tap(find.text('Generate Report'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Assert that the report is generated successfully
      expect(find.text('Report Generated Successfully'), findsOneWidget);
    });

    testWidgets('Login as officer and verify data fetching for reports',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LanguageProvider(),
          child: const app.MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Login as officer
      await tester.enterText(find.byKey(const Key('emailField')), 'officer@test.com');
      await tester.enterText(find.byKey(const Key('passwordField')), 'password123');
      await tester.tap(find.byKey(const Key('loginButton')));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Navigate to Officer Report Screen
      await tester.tap(find.byIcon(Icons.bar_chart));
      await tester.pumpAndSettle();

      // Assert that daily and monthly stats are not zero or empty
      expect(find.byKey(const Key('dailyStats')), findsOneWidget);
      expect(find.byKey(const Key('monthlyStats')), findsOneWidget);

      final dailyStatsText = tester.widget<Text>(find.byKey(const Key('dailyStats'))).data;
      final monthlyStatsText = tester.widget<Text>(find.byKey(const Key('monthlyStats'))).data;

      expect(dailyStatsText, isNot('0'));
      expect(monthlyStatsText, isNot('0'));
    });
  });
}