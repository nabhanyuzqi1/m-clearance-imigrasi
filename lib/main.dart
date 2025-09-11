import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app/config/routes.dart';
import 'app/config/theme.dart';
import 'firebase_options.dart';
import 'app/views/widgets/auth_wrapper.dart';
import 'app/providers/language_provider.dart';

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

  // Note: Using firebasestorage.app bucket as specified by user
  if (opts.storageBucket != null) {
    debugPrint('[Startup] Storage bucket configured: ${opts.storageBucket}');
  }

  // Initialize Firebase Crashlytics (only on mobile platforms)
  if (!kIsWeb) {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
    debugPrint('[Startup] Crashlytics collection enabled: ${!kDebugMode}');

    // Set up error reporting to Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } else {
    debugPrint('[Startup] Crashlytics skipped on web platform');
  }

  // Preload critical assets for better startup performance
  runApp(
    ChangeNotifierProvider(
      create: (context) => LanguageProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _preloadAssets();
  }

  Future<void> _preloadAssets() async {
    // Ensure that the context is available before precaching
    if (mounted) {
      try {
        await Future.wait([
          precacheImage(const AssetImage('assets/images/logo.png'), context),
          precacheImage(const AssetImage('assets/images/dermaga.png'), context),
          precacheImage(const AssetImage('assets/images/shipping.png'), context),
        ]);
        debugPrint('[Startup] Critical assets preloaded successfully');
      } catch (e) {
        debugPrint('[Startup] Asset preloading failed: $e');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('[Lifecycle] App resumed');
        // Handle app resume - refresh authentication state if needed
        break;
      case AppLifecycleState.inactive:
        debugPrint('[Lifecycle] App inactive');
        break;
      case AppLifecycleState.paused:
        debugPrint('[Lifecycle] App paused');
        break;
      case AppLifecycleState.detached:
        debugPrint('[Lifecycle] App detached');
        break;
      case AppLifecycleState.hidden:
        debugPrint('[Lifecycle] App hidden');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return MaterialApp(
          title: 'M-Clearance ISAM',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.themeData,
          locale: languageProvider.locale,
          supportedLocales: const [
            Locale('en', 'US'),
            Locale('id', 'ID'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AuthWrapper(),
          onGenerateRoute: AppRoutes.onGenerateRoute,
          restorationScopeId: 'app', // Enable state restoration
        );
      },
    );
  }
}