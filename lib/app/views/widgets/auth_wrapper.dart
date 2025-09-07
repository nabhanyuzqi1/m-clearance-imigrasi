import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:m_clearance_imigrasi/app/models/user_model.dart';
import 'package:m_clearance_imigrasi/app/services/auth_service.dart';
import 'package:m_clearance_imigrasi/app/views/screens/auth/login_screen.dart';
import 'package:m_clearance_imigrasi/app/views/screens/auth/email_verification_screen.dart';
import 'package:m_clearance_imigrasi/app/views/screens/auth/upload_documents_screen.dart';
import 'package:m_clearance_imigrasi/app/views/screens/auth/registration_pending_screen.dart';
import 'package:m_clearance_imigrasi/app/views/screens/officer/admin_home_screen.dart';
import 'package:m_clearance_imigrasi/app/views/screens/user/user_home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService _authService = AuthService();

    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final User? user = snapshot.data;
          if (user == null) {
            return const LoginScreen();
          } else {
            return FutureBuilder<UserModel?>(
              future: _authService.getUserData(user.uid),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.done) {
                  if (userSnapshot.hasData) {
                    final userModel = userSnapshot.data!;
                    switch (userModel.status) {
                      case 'approved':
                        if (userModel.role == 'admin' ||
                            userModel.role == 'officer') {
                          return AdminHomeScreen(
                              adminName: userModel.username,
                              adminUsername: userModel.email);
                        } else {
                          return const UserHomeScreen();
                        }
                      case 'pending_email_verification':
                        return const EmailVerificationScreen();
                      case 'pending_documents':
                        return const UploadDocumentsScreen();
                      case 'pending_approval':
                        return const RegistrationPendingScreen();
                      default:
                        return const LoginScreen();
                    }
                  } else {
                    return const LoginScreen();
                  }
                }
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              },
            );
          }
        }
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}