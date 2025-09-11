import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:m_clearance_imigrasi/firebase_options.dart';
import 'package:m_clearance_imigrasi/app/config/routes.dart';
import 'package:m_clearance_imigrasi/app/views/screens/auth/login_screen.dart';
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

Future<void> enterRegisterFieldsByIndex(
  WidgetTester tester, {
  required String corporateName,
  required String username,
  required String email,
  required String password,
}) async {
  // RegisterScreen has 5 TextFormFields in order:
  // 0: corporateName, 1: username, 2: email, 3: password, 4: confirm password
  final fields = find.byType(TextFormField);
  expect(fields, findsNWidgets(5));

  await tester.enterText(fields.at(0), corporateName);
  await tester.enterText(fields.at(1), username);
  await tester.enterText(fields.at(2), email);
  await tester.enterText(fields.at(3), password);
  await tester.enterText(fields.at(4), password);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End Auth + Routing', () {
    testWidgets(
      'New user: Register -> EmailVerification -> Upload -> RegistrationPending -> UserHome via Firestore transitions',
      (WidgetTester tester) async {
        // Initialize Firebase (app bootstrap also calls this; doing it here stabilizes test env)
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        final auth = FirebaseAuth.instance;
        final firestore = FirebaseFirestore.instance;

        // Unique test credentials
        final millis = DateTime.now().millisecondsSinceEpoch;
        final email = 'itest+$millis@example.com';
        const password = 'Passw0rd!';

        // 1) Launch app (AuthWrapper is home) -> navigate to Register -> submit -> land on EmailVerification
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Expect we are on LoginScreen (AuthWrapper routes unauthenticated users to login)
        expect(find.byType(LoginScreen), findsOneWidget);

        // Navigate to Register. Prefer UI tap on "Register now" (RichText span).
        final registerNowText = find.text('Register now');
        if (registerNowText.evaluate().isNotEmpty) {
          await tester.tap(registerNowText);
        } else {
          // Fallback: push to register via Navigator in case RichText finder fails
          final ctx = tester.element(find.byType(LoginScreen));
          Navigator.pushNamed(ctx, AppRoutes.register, arguments: {'initialLanguage': 'EN'});
        }
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // Fill the registration form and submit
        await enterRegisterFieldsByIndex(
          tester,
          corporateName: 'ITest Corp $millis',
          username: 'itest_user_$millis',
          email: email,
          password: password,
        );

        // Agree to terms
        final termsCheckbox = find.byType(Checkbox);
        expect(termsCheckbox, findsOneWidget);
        await tester.tap(termsCheckbox);
        await tester.pump();

        // Tap Continue
        final continueBtn = find.widgetWithText(ElevatedButton, 'Continue');
        expect(continueBtn, findsOneWidget);
        await tester.tap(continueBtn);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Verify EmailVerificationScreen
        await pumpUntilFound(tester, find.text('Email Verification'), timeout: const Duration(seconds: 10));

        // Capture uid
        final uid = auth.currentUser!.uid;

        // 2) Simulate email verification by updating Firestore, then navigate to UploadDocuments
        await firestore.collection('users').doc(uid).set({
          'isEmailVerified': true,
          'status': 'pending_documents',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        // Directly navigate to UploadDocuments in test to continue the flow
        final ctx = tester.element(find.text('Email Verification'));
        Navigator.pushNamed(ctx, AppRoutes.uploadDocuments, arguments: {'initialLanguage': 'EN'});
        await tester.pumpAndSettle(const Duration(seconds: 2));
        await pumpUntilFound(tester, find.text('Submission'), timeout: const Duration(seconds: 10));

        // 3) Simulate document upload completion -> route to RegistrationPending
        await firestore.collection('users').doc(uid).set({
          'hasUploadedDocuments': true,
          'documents': [
            {
              'storagePath': 'test/doc1.pdf',
              'documentName': 'doc1.pdf',
              'uploadedAt': FieldValue.serverTimestamp(),
            }
          ],
          'status': 'pending_approval',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Force app to re-evaluate guards by signing out then signing back in.
        // UploadDocumentsScreen listens to auth changes and will route back to Login on sign-out.
        await auth.signOut();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Back on Login, sign in
        expect(find.byType(LoginScreen), findsOneWidget);
        final loginEmailField = find.byType(TextFormField).at(0);
        final loginPasswordField = find.byType(TextFormField).at(1);
        await tester.enterText(loginEmailField, email);
        await tester.enterText(loginPasswordField, password);

        final loginBtn = find.widgetWithText(ElevatedButton, 'Login');
        expect(loginBtn, findsOneWidget);
        await tester.tap(loginBtn);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Should be on Registration Pending (Waiting for Verification)
        await pumpUntilFound(tester, find.text('Waiting for Verification'), timeout: const Duration(seconds: 10));

        // 4) Simulate officer approval -> route to UserHomeScreen
        await firestore.collection('users').doc(uid).set({
          'status': 'approved',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Sign out to force LoginScreen to drive routing by Firestore status on next sign-in
        await auth.signOut();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Sign back in
        expect(find.byType(LoginScreen), findsOneWidget);
        await tester.enterText(loginEmailField, email);
        await tester.enterText(loginPasswordField, password);
        await tester.tap(loginBtn);
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Expect User home (unique UI: AppBar 'Home' and body 'Welcome!')
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Welcome!'), findsOneWidget);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
