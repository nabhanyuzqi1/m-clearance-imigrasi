import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'app/providers/connectivity_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app/config/routes.dart';
import 'app/config/theme.dart';
import 'app/localization/app_localizations.dart';
import 'app/services/auth_service.dart';
import 'app/services/notification_service.dart';
import 'app/services/system_ui_service.dart';
import 'firebase_options.dart';
import 'app/views/widgets/auth_wrapper.dart';
import 'app/views/widgets/connectivity_gate.dart';
import 'app/providers/language_provider.dart';
import 'app/views/widgets/skeleton_loader.dart' as skeleton;
import 'app/providers/theme_provider.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  debugPrint("Handling a background message: ${message.messageId}");
  await NotificationService.handleBackgroundMessage(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemUiService.instance.setSystemBarsAppearance(
    lightStatusBars: true,
    lightNavigationBars: true,
  );

  // Guard against duplicate initialization (hot restart, multiple isolates).
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (!kIsWeb) {
        FirebaseDatabase.instance.setPersistenceEnabled(true);
        FirebaseDatabase.instance.setLoggingEnabled(true);
      }
      debugPrint('[Startup] Firebase.initializeApp executed');
    } else {
      debugPrint(
        '[Startup] Firebase already initialized, skipping initializeApp',
      );
    }
  } on FirebaseException catch (e) {
    // Ignore duplicate-app errors but rethrow others
    if (e.code != 'duplicate-app') {
      rethrow;
    } else {
      debugPrint('[Startup] Ignored duplicate-app during initializeApp');
    }
  }

  // Initialize Firebase App Check
  if (!kDebugMode) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.deviceCheck,
      webProvider: ReCaptchaV3Provider('your-recaptcha-site-key'),
    );
    debugPrint('[Startup] Firebase App Check activated');
  }

  // Initialize Firebase Crashlytics (only on mobile platforms)
  if (!kIsWeb) {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );
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
  // Set up Firebase Cloud Messaging
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final notificationService = NotificationService();

  // Request notification permissions on app start if not already granted
  try {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
    await notificationService.ensureInitialised();
    await notificationService.syncFcmToken();
  } catch (e) {
    debugPrint('[Startup] Error handling notification permissions: $e');
    await notificationService.ensureInitialised();
  }

  // Preload critical assets for better startup performance
  runZonedGuarded(() {
    runApp(
      MultiProvider(
        providers: [
          Provider<AuthService>(create: (_) => AuthService()),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ],
        child: const MyApp(),
      ),
    );
  }, (error, stack) {
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } else {
      debugPrint('[Startup] Unhandled error: $error');
    }
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService();
    WidgetsBinding.instance.addObserver(this);
    // Set up foreground message handling
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await _notificationService.handleForegroundMessage(message);
    });
    FirebaseMessaging.onMessageOpenedApp.listen(
      _notificationService.handleOpenedNotification,
    );
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
          precacheImage(
            const AssetImage('assets/images/dermaga.png'),
            context,
          ),
          precacheImage(
            const AssetImage('assets/images/shipping.png'),
            context,
          ),
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
    // Dispose shared shimmer animation controller
    skeleton.ShimmerAnimationController.dispose();
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
    return Consumer2<LanguageProvider, ThemeProvider>(
      builder: (context, languageProvider, themeProvider, child) {
        return MaterialApp(
          title: 'M-Clearance ISAM',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          scrollBehavior: const AppScrollBehavior(),
          locale: languageProvider.locale,
          supportedLocales: const [Locale('en', 'US'), Locale('id', 'ID')],
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AuthWrapper(),
          onGenerateRoute: AppRoutes.onGenerateRoute,
          restorationScopeId: 'app', // Enable state restoration
          builder: (context, child) =>
              ConnectivityGate(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}
