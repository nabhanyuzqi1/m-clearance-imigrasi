import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/config/routes.dart';
import 'app/config/theme.dart';
import 'firebase_options.dart';
import 'app/views/widgets/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Guard against duplicate initialization (hot restart, multiple isolates).
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('[Startup] Firebase.initializeApp executed');
    } else {
      debugPrint('[Startup] Firebase already initialized, skipping initializeApp');
    }
  } on FirebaseException catch (e) {
    // Ignore duplicate-app errors but rethrow others
    if (e.code != 'duplicate-app') {
      rethrow;
    } else {
      debugPrint('[Startup] Ignored duplicate-app during initializeApp');
    }
  }

  // Ensure a dedicated named app with correct Dart-provided options to avoid
  // picking up native defaults from google-services.json.
  FirebaseApp appClient;
  try {
    appClient = Firebase.app('client');
    debugPrint('[Startup] Using existing Firebase app "client"');
  } catch (_) {
    appClient = await Firebase.initializeApp(
      name: 'client',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[Startup] Initialized Firebase app "client"');
  }

  // Diagnostics: print effective Firebase options for the named app.
  final opts = appClient.options;
  final safeKey = (opts.apiKey.length > 6) ? '${opts.apiKey.substring(0, 6)}...' : opts.apiKey;
  debugPrint('[Startup] FirebaseOptions(client): projectId=${opts.projectId}, appId=${opts.appId}, apiKey=$safeKey, '
      'storageBucket=${opts.storageBucket}, authDomain=${opts.authDomain}, '
      'messagingSenderId=${opts.messagingSenderId}, measurementId=${opts.measurementId}');

  if (opts.storageBucket != null && opts.storageBucket!.contains('firebasestorage.app')) {
    debugPrint('[Startup][Warning] storageBucket looks like a download host ("firebasestorage.app"). '
        'Bucket IDs usually end with "appspot.com" (e.g., "${opts.projectId}.appspot.com").');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'M-Clearance ISAM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      home: const AuthWrapper(),
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}