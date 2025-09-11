import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:m_clearance_imigrasi/app/models/user_model.dart';
import 'package:m_clearance_imigrasi/app/services/auth_service.dart';
import 'package:m_clearance_imigrasi/app/config/routes.dart';

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
  void dispose() {
    _selectedLanguage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.active) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final User? user = snapshot.data;

        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, AppRoutes.login);
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Authenticated - load user data from Firebase
        return FutureBuilder<UserModel?>(
          future: authService.getUserData(user.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final userModel = userSnapshot.data;

            if (userModel == null) {
              // Missing user document after login; fallback to register
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacementNamed(context, AppRoutes.register);
              });
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(context, routeName, arguments: args);
    });

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
