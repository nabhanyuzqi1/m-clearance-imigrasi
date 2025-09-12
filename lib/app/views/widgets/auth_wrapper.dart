import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:m_clearance_imigrasi/app/models/user_model.dart';
import 'package:m_clearance_imigrasi/app/services/auth_service.dart';
import 'package:m_clearance_imigrasi/app/services/logging_service.dart';
import 'package:m_clearance_imigrasi/app/config/routes.dart';
import 'package:m_clearance_imigrasi/app/config/theme.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with RestorationMixin {
  @override
  String? get restorationId => 'auth_wrapper';

  final RestorableString _selectedLanguage = RestorableString('EN');

  String get selectedLanguage => _selectedLanguage.value;

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_selectedLanguage, 'selected_language');
  }

  @override
  void initState() {
    super.initState();
    LoggingService().info('AuthWrapper initialized');
  }

  @override
  void dispose() {
    LoggingService().debug('Disposing AuthWrapper resources');
    _selectedLanguage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    LoggingService().debug('Building AuthWrapper');
    final AuthService authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.active) {
          return Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            body: Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            ),
          );
        }

        final User? user = snapshot.data;

        if (user == null) {
          LoggingService().info('No authenticated user, redirecting to login');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, AppRoutes.login);
          });
          return Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            body: Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            ),
          );
        }

        // Authenticated - load user data from Firebase
        return FutureBuilder<UserModel?>(
          future: authService.getUserData(user.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState != ConnectionState.done) {
              return Scaffold(
                backgroundColor: AppTheme.backgroundColor,
                body: Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                  ),
                ),
              );
            }

            final userModel = userSnapshot.data;

            if (userModel == null) {
              // Missing user document after login; fallback to register
              LoggingService().warning('Missing user document for authenticated user, redirecting to register');
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacementNamed(context, AppRoutes.register);
              });
              return Scaffold(
                backgroundColor: AppTheme.backgroundColor,
                body: Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                  ),
                ),
              );
            }

            return _buildNavigationUI(userModel);
          },
        );
      },
    );
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
        args = {'initialLanguage': 'EN'};
        break;
      case 'pending_approval':
        routeName = AppRoutes.registrationPending;
        args = {'initialLanguage': 'EN'};
        break;
      case 'approved':
        if (userModel.role == 'admin' || userModel.role == 'officer') {
          routeName = AppRoutes.adminHome;
          args = {
            'adminName': userModel.username,
            'adminUsername': userModel.email,
            'initialLanguage': 'EN',
          };
        } else {
          routeName = AppRoutes.userHome;
        }
        break;
      case 'rejected':
        routeName = AppRoutes.confirmation;
        args = {
          'userData': {'email': userModel.email},
          'initialLanguage': 'EN',
        };
        break;
      default:
        // Defensive default
        routeName = AppRoutes.registrationPending;
        args = {'initialLanguage': 'EN'};
    }

    LoggingService().info('Navigating to route: $routeName with args: $args');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(context, routeName, arguments: args);
    });

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }
}
