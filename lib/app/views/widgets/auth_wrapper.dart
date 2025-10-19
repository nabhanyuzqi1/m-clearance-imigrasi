import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:m_clearance_imigrasi/app/models/user_model.dart';
import 'package:m_clearance_imigrasi/app/services/auth_service.dart';
import 'package:m_clearance_imigrasi/app/services/logging_service.dart';
import 'package:m_clearance_imigrasi/app/services/notification_service.dart';
import 'package:m_clearance_imigrasi/app/config/routes.dart';
import 'package:m_clearance_imigrasi/app/config/theme.dart';
import 'bouncing_dots_loader.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper>
    with RestorationMixin, WidgetsBindingObserver {
  @override
  String? get restorationId => 'auth_wrapper';

  final RestorableString _selectedLanguage = RestorableString('EN');
  bool _hasNavigated = false;
  static const Duration _authRecoveryWindow = Duration(seconds: 2);
  Timer? _resumeHoldTimer;
  bool _resumeHoldActive = false;
  String? _lastKnownUserId;

  String get selectedLanguage => _selectedLanguage.value;

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_selectedLanguage, 'selected_language');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastKnownUserId = FirebaseAuth.instance.currentUser?.uid;
    LoggingService().info('AuthWrapper initialized');
  }

  @override
  void dispose() {
    LoggingService().debug('Disposing AuthWrapper resources');
    WidgetsBinding.instance.removeObserver(this);
    _resumeHoldTimer?.cancel();
    _selectedLanguage.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      LoggingService().debug(
        'AuthWrapper detected app resume; applying auth recovery window',
      );
      _beginResumeHold('app resumed');
    }
  }

  void _beginResumeHold(
    String reason, {
    bool clearLastKnownOnTimeout = false,
  }) {
    LoggingService().debug('Starting resume hold: $reason');
    _resumeHoldTimer?.cancel();
    if (!_resumeHoldActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _resumeHoldActive = true;
        });
      });
    }
    _resumeHoldTimer = Timer(_authRecoveryWindow, () {
      if (!mounted) return;
      setState(() {
        _resumeHoldActive = false;
        if (clearLastKnownOnTimeout) {
          _lastKnownUserId = null;
        }
      });
    });
  }

  void _clearResumeHold() {
    _resumeHoldTimer?.cancel();
    _resumeHoldTimer = null;
    if (_resumeHoldActive) {
      _resumeHoldActive = false;
    }
  }

  Widget _buildLoadingShell() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: const Center(child: BouncingDotsLoader()),
    );
  }

  bool _shouldDeferAuthRecovery(
    User? candidateUser, {
    bool allowStart = true,
  }) {
    if (_resumeHoldActive) {
      return true;
    }
    if (!allowStart) {
      return false;
    }
    if (candidateUser != null) {
      _beginResumeHold('Firebase currentUser still available');
      return true;
    }
    if (_lastKnownUserId != null) {
      _beginResumeHold(
        'Auth stream emitted null but last user persists',
        clearLastKnownOnTimeout: true,
      );
      return true;
    }
    return false;
  }

  void _scheduleNavigation(
    String routeName, {
    Map<String, dynamic>? arguments,
  }) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, routeName, arguments: arguments);
    });
  }

  @override
  Widget build(BuildContext context) {
    LoggingService().debug('Building AuthWrapper');
    final AuthService authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.active) {
          return _buildLoadingShell();
        }

        final User? user = snapshot.data;
        final currentUser = FirebaseAuth.instance.currentUser;

        if (user != null) {
          _clearResumeHold();
          _lastKnownUserId = user.uid;
        }

        if (user == null) {
          if (_shouldDeferAuthRecovery(currentUser)) {
            LoggingService().debug(
              'Deferring login redirect while waiting for auth recovery',
            );
            return _buildLoadingShell();
          }
          LoggingService().info('No authenticated user, redirecting to login');
          _lastKnownUserId = null;
          _scheduleNavigation(AppRoutes.login);
          return _buildLoadingShell();
        }

        // Authenticated - load user data from Firebase
        return FutureBuilder<UserModel?>(
          future: _loadUserModel(authService, user.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState != ConnectionState.done) {
              return _buildLoadingShell();
            }

            final userModel = userSnapshot.data;

            if (userModel == null) {
              if (_shouldDeferAuthRecovery(user, allowStart: false)) {
                LoggingService().warning(
                  'User model missing during resume window, delaying sign-out',
                );
                return _buildLoadingShell();
              }
              LoggingService().warning(
                'Unable to load user data, signing out as a safety fallback',
              );
              authService.signOut();
              _scheduleNavigation(AppRoutes.login);
              return _buildLoadingShell();
            }

            return _buildNavigationUI(userModel);
          },
        );
      },
    );
  }

  Future<UserModel?> _loadUserModel(AuthService authService, String uid) async {
    try {
      final cached = await authService.getUserData(uid);
      if (cached != null) return cached;
      return await authService.getUserData(uid, forceRefresh: true);
    } catch (e, stackTrace) {
      LoggingService().error(
        'Failed to load user model for uid: $uid',
        e,
        stackTrace,
      );
      return null;
    }
  }

  Widget _buildNavigationUI(UserModel userModel) {
    String routeName;
    Map<String, dynamic>? args;

    switch (userModel.status) {
      case 'pending_email_verification':
        routeName = AppRoutes.confirmation;
        args = {
          'userData': {'email': userModel.email},
          'initialLanguage': selectedLanguage,
        };
        break;
      case 'pending_documents':
        routeName = AppRoutes.uploadDocuments;
        args = {'initialLanguage': selectedLanguage};
        break;
      case 'pending_approval':
        routeName = AppRoutes.registrationPending;
        args = {'initialLanguage': selectedLanguage};
        break;
      case 'approved':
        if (userModel.role == 'admin' || userModel.role == 'officer') {
          routeName = AppRoutes.adminHome;
          final corporateName = userModel.corporateName.trim();
          final fullName = userModel.fullName.trim();
          final displayName = fullName.isNotEmpty
              ? fullName
              : (corporateName.isNotEmpty ? corporateName : userModel.username);
          args = {
            'adminName': displayName,
            'adminUsername': userModel.username,
            'adminCorporateName': corporateName,
            'photoURL': userModel.photoURL,
            'initialLanguage': selectedLanguage,
          };
        } else {
          routeName = AppRoutes.userHome;
          args = {'initialLanguage': selectedLanguage};
        }
        break;
      case 'rejected':
        routeName = AppRoutes.confirmation;
        args = {
          'userData': {'email': userModel.email},
          'initialLanguage': selectedLanguage,
        };
        break;
      default:
        // Defensive default
        routeName = AppRoutes.registrationPending;
        args = {'initialLanguage': selectedLanguage};
    }

    NotificationService().startRealtimeListener();
    LoggingService().info('Navigating to route: $routeName with args: $args');
    _scheduleNavigation(routeName, arguments: args);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: const Center(child: BouncingDotsLoader()),
    );
  }
}
