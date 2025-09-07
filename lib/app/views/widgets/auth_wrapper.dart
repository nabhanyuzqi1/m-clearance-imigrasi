import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:m_clearance_imigrasi/app/models/user_model.dart';
import 'package:m_clearance_imigrasi/app/services/auth_service.dart';
import 'package:m_clearance_imigrasi/app/config/routes.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService _authService = AuthService();

    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
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

        // Authenticated
        final bool emailVerified = user.emailVerified;
        if (!emailVerified) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, AppRoutes.emailVerification);
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Load user document
        return FutureBuilder<UserModel?>(
          future: _authService.getUserData(user.uid),
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

            String routeName;
            Map<String, dynamic>? args;

            switch (userModel.status) {
              case 'pending_email_verification':
                routeName = AppRoutes.emailVerification;
                break;
              case 'pending_documents':
                routeName = AppRoutes.uploadDocuments;
                break;
              case 'pending_approval':
                routeName = AppRoutes.registrationPending;
                break;
              case 'approved':
                if (userModel.role == 'admin' || userModel.role == 'officer') {
                  routeName = AppRoutes.adminHome;
                  args = {
                    'adminName': userModel.username,
                    'adminUsername': userModel.email,
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
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacementNamed(context, routeName, arguments: args);
            });

            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          },
        );
      },
    );
  }
}