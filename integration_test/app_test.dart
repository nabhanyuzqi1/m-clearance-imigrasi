import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Import your app's main entry point
import 'package:m_clearance_imigrasi/main.dart' as app;
import 'package:m_clearance_imigrasi/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Firebase End-to-End Tests', () {
    setUpAll(() async {
      // It's standard practice to initialize Firebase in the test setup
      // even if it's also in the app's main, to ensure it's ready for the test environment.
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    });

    testWidgets('Full App Flow: Register, Add Note, and Sign Out',
        (WidgetTester tester) async {
      // 1. Launch the app.
      app.main();
      
      // Allow the app to settle on the initial loading screen.
      await tester.pumpAndSettle();

      // IMPORTANT: Add this line to wait for the Firebase auth stream
      // to resolve and navigate from the loading screen to the LoginPage.
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;

      // Use a unique email for each test run to avoid conflicts.
      final email = 'testuser_${DateTime.now().millisecondsSinceEpoch}@test.com';
      const password = 'password123';

      // --- REGISTRATION ---
      // Find the email and password fields.
      final emailField = find.widgetWithText(TextFormField, 'Email');
      final passwordField = find.widgetWithText(TextFormField, 'Password');
      expect(emailField, findsOneWidget);
      expect(passwordField, findsOneWidget);

      // Enter text.
      await tester.enterText(emailField, email);
      await tester.enterText(passwordField, password);
      
      // Find and tap the register button.
      final registerButton = find.widgetWithText(OutlinedButton, 'Register');
      expect(registerButton, findsOneWidget);
      await tester.tap(registerButton);

      // Wait for the app to navigate and settle on the home page.
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // VERIFY: We are on the HomePage
      expect(find.text('Firestore Notes ($email)'), findsOneWidget);
      expect(auth.currentUser, isNotNull);
      final userId = auth.currentUser!.uid;

      // --- FIRESTORE (CREATE NOTE) ---
      // Find the FloatingActionButton and tap it.
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);
      await tester.tap(fab);
      await tester.pumpAndSettle();

      // Find the text field in the dialog.
      final noteField = find.widgetWithText(TextField, 'Note Content');
      expect(noteField, findsOneWidget);

      // Enter note text and add it.
      const noteContent = 'This is an integration test note.';
      await tester.enterText(noteField, noteContent);
      final addButton = find.widgetWithText(ElevatedButton, 'Add');
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // VERIFY: The note appears in the list.
      expect(find.text(noteContent), findsOneWidget);
      
      // --- SIGN OUT ---
      // Find the logout button and tap it.
      final logoutButton = find.byIcon(Icons.logout);
      expect(logoutButton, findsOneWidget);
      await tester.tap(logoutButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // VERIFY: We are back on the LoginPage
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(auth.currentUser, isNull);

      // --- CLEANUP ---
      // Log back in to delete the user and their data.
      await tester.enterText(emailField, email);
      await tester.enterText(passwordField, password);
      final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
      await tester.tap(signInButton);
      await tester.pumpAndSettle();
      
      // Delete the user's notes
      final querySnapshot = await firestore.collection('notes').where('userId', isEqualTo: userId).get();
      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }
      
      // Delete the user
      await auth.currentUser?.delete();
    });
  });
}