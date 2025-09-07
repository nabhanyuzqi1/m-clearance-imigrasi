// integration_test/e2e_android_test.dart
// E2E Android entrypoint using the existing auth/document routing scenario.
//
// Run with one of:
// flutter drive -d emulator-5554 --driver=integration_test/app_driver.dart --target=integration_test/e2e_android_test.dart
// flutter drive -d emulator-5554 --driver=test_driver/integration_test.dart --target=integration_test/e2e_android_test.dart
// flutter test -d android integration_test/e2e_android_test.dart

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

// Reuse helpers from the existing scenario
import 'auth_flow_test.dart' as authflow;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E Android: Auth + Routing flow', () {
    testWidgets(
      'Register -> EmailVerification -> Upload -> RegistrationPending -> UserHome',
      (WidgetTester tester) async {
        // Initialize Firebase for the test environment.
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        final auth = FirebaseAuth.instance;
        final firestore = FirebaseFirestore.instance;

        // Unique test credentials
        final millis = DateTime.now().millisecondsSinceEpoch;
        final email = 'android_e2e+$millis@example.com';
        const password = 'Passw0rd!';

        // 1) Launch app and allow settle for Android
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Expect Login
        expect(find.byType(LoginScreen), findsOneWidget);

        // Navigate to Register via "Register now"
        final registerNowText = find.text('Register now');
        if (registerNowText.evaluate().isNotEmpty) {
          await tester.tap(registerNowText);
        } else {
          // Fallback navigation
          final ctx = tester.element(find.byType(LoginScreen));
          Navigator.pushNamed(ctx, AppRoutes.register, arguments: {'initialLanguage': 'EN'});
        }
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Fill registration and submit
        await authflow.enterRegisterFieldsByIndex(
          tester,
          corporateName: 'Android E2E Corp $millis',
          username: 'android_e2e_$millis',
          nationality: 'ID',
          email: email,
          password: password,
        );

        // Agree to terms
        final termsCheckbox = find.byType(Checkbox);
        expect(termsCheckbox, findsOneWidget);
        await tester.tap(termsCheckbox);
        await tester.pump();

        // Continue
        final continueBtn = find.widgetWithText(ElevatedButton, 'Continue');
        expect(continueBtn, findsOneWidget);
        await tester.tap(continueBtn);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // EmailVerification
        await authflow.pumpUntilFound(
          tester,
          find.text('Email Verification'),
          timeout: const Duration(seconds: 12),
        );

        // Capture uid
        final uid = auth.currentUser!.uid;

        // 2) Simulate email verification and route to UploadDocuments
        await firestore.collection('users').doc(uid).set({
          'isEmailVerified': true,
          'status': 'pending_documents',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final iHaveVerifiedBtn = find.widgetWithText(ElevatedButton, 'I have verified my email');
        if (iHaveVerifiedBtn.evaluate().isNotEmpty) {
          await tester.tap(iHaveVerifiedBtn);
        }
        await tester.pumpAndSettle(const Duration(seconds: 5));
        await authflow.pumpUntilFound(
          tester,
          find.text('Upload Documents'),
          timeout: const Duration(seconds: 12),
        );

        // 3) Simulate document upload completion -> RegistrationPending
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

        // Force guards by sign-out
        await auth.signOut();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Back to Login, sign in
        expect(find.byType(LoginScreen), findsOneWidget);
        final loginEmailField = find.byType(TextFormField).at(0);
        final loginPasswordField = find.byType(TextFormField).at(1);
        await tester.enterText(loginEmailField, email);
        await tester.enterText(loginPasswordField, password);

        final loginBtn = find.widgetWithText(ElevatedButton, 'Login');
        expect(loginBtn, findsOneWidget);
        await tester.tap(loginBtn);
        await tester.pumpAndSettle(const Duration(seconds: 5));

        await authflow.pumpUntilFound(
          tester,
          find.text('Registration Pending'),
          timeout: const Duration(seconds: 12),
        );

        // 4) Approval -> UserHome
        await firestore.collection('users').doc(uid).set({
          'status': 'approved',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await auth.signOut();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Sign back in
        expect(find.byType(LoginScreen), findsOneWidget);
        await tester.enterText(loginEmailField, email);
        await tester.enterText(loginPasswordField, password);
        await tester.tap(loginBtn);
        await tester.pumpAndSettle(const Duration(seconds: 6));

        // Expect UserHome unique UI
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Welcome!'), findsOneWidget);
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  });
}