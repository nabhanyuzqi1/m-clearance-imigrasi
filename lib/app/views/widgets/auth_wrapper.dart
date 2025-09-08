import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:m_clearance_imigrasi/app/models/user_model.dart';
import 'package:m_clearance_imigrasi/app/services/auth_service.dart';
import 'package:m_clearance_imigrasi/app/services/local_storage_service.dart';
import 'package:m_clearance_imigrasi/app/config/routes.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  UserModel? _cachedUser;
  bool _isLoadingCached = true;
  bool _isUpdatingFromFirebase = false;
  bool _hasFirebaseUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadCachedData();
  }

  Future<void> _loadCachedData() async {
    try {
      final cachedUser = await LocalStorageService.getCachedUserData();
      if (mounted) {
        setState(() {
          _cachedUser = cachedUser;
          _isLoadingCached = false;
        });
      }
    } catch (e) {
      print('Error loading cached data: $e');
      if (mounted) {
        setState(() {
          _isLoadingCached = false;
        });
      }
    }
  }

  Future<void> _updateUserDataInBackground(User user, AuthService authService) async {
    if (_isUpdatingFromFirebase) return;

    setState(() {
      _isUpdatingFromFirebase = true;
    });

    try {
      // Reload user to get fresh verification status
      await user.reload();

      // Sync Firestore status with Firebase Auth
      final updatedUser = await authService.updateEmailVerified();

      if (updatedUser != null) {
        // Cache the updated user data
        await LocalStorageService.cacheUserData(updatedUser);
        if (mounted) {
          setState(() {
            _cachedUser = updatedUser;
            _hasFirebaseUpdate = true;
          });
        }
      }
    } catch (e) {
      // Handle error gracefully, continue with cached data
      print('Error updating user data from Firebase: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingFromFirebase = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthService _authService = AuthService();

    // Show loading while checking cached data
    if (_isLoadingCached) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.active) {
          // Show cached UI if available while Firebase loads
          if (_cachedUser != null) {
            return _buildCachedUI(_cachedUser!);
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final User? user = snapshot.data;

        if (user == null) {
          // Clear cached data on logout
          LocalStorageService.clearAll();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, AppRoutes.login);
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Authenticated - check if we have cached data to show immediately
        if (_cachedUser != null) {
          // Show cached UI and update in background
          _updateUserDataInBackground(user, _authService);
          return _buildCachedUI(_cachedUser!);
        }

        // No cached data - load from Firebase
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

            // Cache the user data for future use
            LocalStorageService.cacheUserData(userModel);

            return _buildNavigationUI(userModel);
          },
        );
      },
    );
  }

  Widget _buildCachedUI(UserModel userModel) {
    // Show cached UI with indicators for cache status
    return Stack(
      children: [
        _buildNavigationUI(userModel),
        // Show updating indicator when syncing with Firebase
        if (_isUpdatingFromFirebase)
          Positioned(
            top: 50,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Updating...',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        // Show offline indicator when not updating (cached data only)
        else if (_cachedUser != null)
          Positioned(
            top: 50,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, size: 14, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Offline',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
      ],
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
          'initialLanguage': 'EN',
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
