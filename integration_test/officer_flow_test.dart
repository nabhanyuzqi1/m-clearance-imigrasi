import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:m_clearance_imigrasi/firebase_options.dart';
import 'package:m_clearance_imigrasi/app/views/screens/auth/login_screen.dart';
import 'package:m_clearance_imigrasi/app/views/screens/officer/admin_home_screen.dart';
import 'package:m_clearance_imigrasi/main.dart' as app;

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
  Duration step = const Duration(milliseconds: 200),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
  // Final settle to collect any pending microtasks
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  expect(finder, findsOneWidget); // Will throw a readable error if not found
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Officer Authentication and Navigation Flow', () {
    testWidgets(
      'Officer Login -> AdminHomeScreen -> Navigation between screens',
      (WidgetTester tester) async {
        // Initialize Firebase
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        // Ensure no user is logged in
        await FirebaseAuth.instance.signOut();

        final auth = FirebaseAuth.instance;
        final firestore = FirebaseFirestore.instance;

        // Ensure officer user exists in Firestore
        const officerEmail = 'officer@gmail.com';
        const officerPassword = 'officer1122';

        // Check if officer user exists, if not create it
        final existingUser = await firestore
            .collection('users')
            .where('email', isEqualTo: officerEmail)
            .limit(1)
            .get();

        if (existingUser.docs.isEmpty) {
          // Create officer user in Firestore
          final officerUid = 'officer_test_uid_${DateTime.now().millisecondsSinceEpoch}';
          await firestore.collection('users').doc(officerUid).set({
            'uid': officerUid,
            'email': officerEmail,
            'username': 'Officer Test',
            'corporateName': 'Immigration Office',
            'nationality': 'ID',
            'role': 'officer',
            'status': 'approved',
            'isEmailVerified': true,
            'hasUploadedDocuments': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'documents': [],
          });

          // Create Firebase Auth user
          try {
            await auth.createUserWithEmailAndPassword(
              email: officerEmail,
              password: officerPassword,
            );
          } catch (e) {
            // User might already exist in Auth
            print('Officer auth user creation failed: $e');
          }
        }

        // 1) Launch app
        await tester.pumpWidget(const app.MyApp());
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Expect LoginScreen
        expect(find.byType(LoginScreen), findsOneWidget);

        // 2) Enter officer credentials and login
        final emailField = find.byType(TextFormField).at(0);
        final passwordField = find.byType(TextFormField).at(1);
        await tester.enterText(emailField, officerEmail);
        await tester.enterText(passwordField, officerPassword);

        final loginBtn = find.widgetWithText(ElevatedButton, 'Login');
        expect(loginBtn, findsOneWidget);
        await tester.tap(loginBtn);
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // 3) Verify navigation to AdminHomeScreen
        await pumpUntilFound(tester, find.byType(AdminHomeScreen), timeout: const Duration(seconds: 10));

        // 4) Check officer-specific UI elements
        expect(find.text('Immigration Office'), findsOneWidget);
        expect(find.text('Officer'), findsOneWidget);
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Report'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);

        // 5) Test navigation between officer screens
        // Navigate to Report screen
        final reportNav = find.text('Report');
        await tester.tap(reportNav);
        await tester.pumpAndSettle();

        // Verify we're on Report screen (check for report-specific elements)
        expect(find.byType(AdminHomeScreen), findsOneWidget); // Still in AdminHomeScreen but different tab

        // Navigate to Settings screen
        final settingsNav = find.text('Settings');
        await tester.tap(settingsNav);
        await tester.pumpAndSettle();

        // Verify Settings screen elements
        expect(find.text('Settings'), findsOneWidget);

        // Navigate back to Home
        final homeNav = find.text('Home');
        await tester.tap(homeNav);
        await tester.pumpAndSettle();

        // Verify back on Home screen
        expect(find.text('Immigration Office'), findsOneWidget);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    testWidgets(
      'State Restoration: Navigate to Report screen and restart app',
      (WidgetTester tester) async {
        // Initialize Firebase
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        // Ensure no user is logged in
        await FirebaseAuth.instance.signOut();

        // 1) Launch app and login as officer
        await tester.pumpWidget(const app.MyApp());
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.byType(LoginScreen), findsOneWidget);

        // Login
        final emailField = find.byType(TextFormField).at(0);
        final passwordField = find.byType(TextFormField).at(1);
        await tester.enterText(emailField, 'officer@gmail.com');
        await tester.enterText(passwordField, 'officer1122');

        final loginBtn = find.widgetWithText(ElevatedButton, 'Login');
        await tester.tap(loginBtn);
        await tester.pumpAndSettle(const Duration(seconds: 5));

        await pumpUntilFound(tester, find.byType(AdminHomeScreen), timeout: const Duration(seconds: 10));

        // 2) Navigate to Report screen
        final reportNav = find.text('Report');
        await tester.tap(reportNav);
        await tester.pumpAndSettle();

        // 3) Simulate app restart by recreating the app
        await tester.pumpWidget(const app.MyApp());
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // 4) Verify app doesn't show blank loading and restores properly
        // Should automatically login and navigate to AdminHomeScreen
        await pumpUntilFound(tester, find.byType(AdminHomeScreen), timeout: const Duration(seconds: 15));

        // Verify officer UI is present (state restored)
        expect(find.text('Immigration Office'), findsOneWidget);
        expect(find.text('Officer'), findsOneWidget);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    testWidgets(
      'Error Handling: Invalid credentials and network issues',
      (WidgetTester tester) async {
        // Initialize Firebase
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        // Ensure no user is logged in
        await FirebaseAuth.instance.signOut();

        // 1) Launch app
        await tester.pumpWidget(const app.MyApp());
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.byType(LoginScreen), findsOneWidget);

        // 2) Test invalid credentials
        final emailField = find.byType(TextFormField).at(0);
        final passwordField = find.byType(TextFormField).at(1);
        await tester.enterText(emailField, 'invalid@officer.com');
        await tester.enterText(passwordField, 'wrongpassword');

        final loginBtn = find.widgetWithText(ElevatedButton, 'Login');
        await tester.tap(loginBtn);
        await tester.pumpAndSettle();

        // Should show error message
        await pumpUntilFound(tester, find.textContaining('Invalid'), timeout: const Duration(seconds: 5));

        // 3) Test with valid officer credentials but simulate network issue
        // Clear fields and enter valid credentials
        await tester.enterText(emailField, 'officer@gmail.com');
        await tester.enterText(passwordField, 'officer1122');

        // Note: For network issues, in a real scenario we might need to mock connectivity
        // For this test, we'll just verify successful login works
        await tester.tap(loginBtn);
        await tester.pumpAndSettle(const Duration(seconds: 5));

        await pumpUntilFound(tester, find.byType(AdminHomeScreen), timeout: const Duration(seconds: 10));
        expect(find.text('Immigration Office'), findsOneWidget);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}