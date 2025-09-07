import 'package:flutter/material.dart';
import '../models/clearance_application.dart';
import '../views/screens/auth/change_password_screen.dart';
import '../views/screens/auth/confirmation_screen.dart';
import '../views/screens/auth/forgot_password_screen.dart';
import '../views/screens/auth/login_screen.dart';
import '../views/screens/auth/register_screen.dart';
import '../views/screens/auth/registration_pending_screen.dart';
import '../views/screens/auth/splash_screen.dart';
import '../views/screens/auth/upload_documents_screen.dart';
import '../views/screens/auth/email_verification_screen.dart';
import '../views/screens/officer/account_detail_screen.dart';
import '../views/screens/officer/account_verification_list_screen.dart';
import '../views/screens/officer/admin_home_screen.dart';
import '../views/screens/officer/arrival_verification_screen.dart';
import '../views/screens/officer/departure_verification_screen.dart';
import '../views/screens/officer/edit_profile_screen.dart';
import '../views/screens/officer/notification_screen.dart';
import '../views/screens/officer/officer_report_screen.dart';
import '../views/screens/officer/submission_detail_screen.dart';
import '../views/screens/user/clearance_form_screen.dart';
import '../views/screens/user/clearance_result_screen.dart';
import '../views/screens/user/edit_agent_profile_screen.dart';
import '../views/screens/user/notification_screen.dart' as user_notif;
import '../views/screens/user/user_home_screen.dart';
import '../views/screens/user/verification_loading_screen.dart';

/// AppRoutes Class
///
/// Mengelola semua rute navigasi aplikasi secara terpusat.
/// Ini membuat kode lebih bersih, mudah dikelola, dan mengurangi risiko kesalahan pengetikan nama rute.
/// Penggunaan `onGenerateRoute` memungkinkan kita untuk meneruskan argumen ke layar
/// dengan cara yang aman dan terkontrol.
class AppRoutes {
  // === NAMA RUTE (KONSTANTA) ===
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String changePassword = '/change-password';
  static const String confirmation = '/confirmation';
  static const String uploadDocuments = '/upload-documents';
  static const String registrationPending = '/registration-pending';
  static const String emailVerification = '/email-verification';
  
  static const String userHome = '/user-home';
  static const String userNotification = '/user-notification';
  static const String editAgentProfile = '/edit-agent-profile';
  static const String clearanceForm = '/clearance-form';
  static const String verificationLoading = '/verification-loading';
  static const String clearanceResult = '/clearance-result';

  static const String adminHome = '/admin-home';
  static const String adminNotification = '/admin-notification';
  static const String editOfficerProfile = '/edit-officer-profile';
  static const String officerReport = '/officer-report';
  static const String accountVerificationList = '/account-verification-list';
  static const String accountDetail = '/account-detail';
  static const String arrivalVerification = '/arrival-verification';
  static const String departureVerification = '/departure-verification';
  static const String submissionDetail = '/submission-detail';
  
  // === GENERATOR RUTE ===
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    // Mengambil argumen jika ada
    final args = settings.arguments;

    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case forgotPassword:
         final arguments = args as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(builder: (_) => ForgotPasswordScreen(initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      case changePassword:
        final arguments = args as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(builder: (_) => ChangePasswordScreen(initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      case confirmation:
        final arguments = args as Map<String, dynamic>;
        return MaterialPageRoute(builder: (_) => ConfirmationScreen(userData: arguments['userData'], initialLanguage: arguments['initialLanguage']));
      case uploadDocuments:
        return MaterialPageRoute(builder: (_) => const UploadDocumentsScreen());
      case registrationPending:
        return MaterialPageRoute(builder: (_) => const RegistrationPendingScreen());
      case emailVerification:
        return MaterialPageRoute(builder: (_) => const EmailVerificationScreen());
      
      case userHome:
        return MaterialPageRoute(builder: (_) => const UserHomeScreen());
      case userNotification:
        final arguments = args as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(builder: (_) => user_notif.NotificationScreen(initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      case editAgentProfile:
        final arguments = args as Map<String, dynamic>;
        return MaterialPageRoute(builder: (_) => EditAgentProfileScreen(username: arguments['username'], currentName: arguments['currentName'], currentEmail: arguments['currentEmail'], initialLanguage: arguments['initialLanguage']));
      case clearanceForm:
        final arguments = args as Map<String, dynamic>;
        return MaterialPageRoute(builder: (_) => ClearanceFormScreen(type: arguments['type'], agentName: arguments['agentName'], existingApplication: arguments['existingApplication'], initialLanguage: arguments['initialLanguage']));
      case verificationLoading:
        final arguments = args as Map<String, dynamic>;
        return MaterialPageRoute(builder: (_) => VerificationLoadingScreen(application: arguments['application'], initialLanguage: arguments['initialLanguage']));
      case clearanceResult:
        final arguments = args as Map<String, dynamic>;
        return MaterialPageRoute(builder: (_) => ClearanceResultScreen(application: arguments['application'], initialLanguage: arguments['initialLanguage']));
      
      case adminHome:
        final arguments = args as Map<String, dynamic>;
        return MaterialPageRoute(builder: (_) => AdminHomeScreen(adminName: arguments['adminName'], adminUsername: arguments['adminUsername']));
      case adminNotification:
        final arguments = args as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(builder: (_) => OfficerNotificationScreen(initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      case editOfficerProfile:
        final arguments = args as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(builder: (_) => EditProfileScreen(initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      case officerReport:
        final arguments = args as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(builder: (_) => OfficerReportScreen(initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      case accountVerificationList:
        final arguments = args as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(builder: (_) => AccountVerificationListScreen(initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      case accountDetail:
        final arguments = args as Map<String, dynamic>;
        return MaterialPageRoute(builder: (_) => AccountDetailScreen(initialLanguage: arguments['initialLanguage']));
      case arrivalVerification:
        final arguments = args as Map<String, dynamic>;
        return MaterialPageRoute(builder: (_) => ArrivalVerificationScreen(adminName: arguments['adminName'], initialLanguage: arguments['initialLanguage']));
      case departureVerification:
        final arguments = args as Map<String, dynamic>;
        return MaterialPageRoute(builder: (_) => DepartureVerificationScreen(adminName: arguments['adminName'], initialLanguage: arguments['initialLanguage']));
      case submissionDetail:
        final arguments = args as Map<String, dynamic>;
        return MaterialPageRoute(builder: (_) => SubmissionDetailScreen(application: arguments['application'], adminName: arguments['adminName'], initialLanguage: arguments['initialLanguage']));

      default:
        // Halaman default jika rute tidak ditemukan
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('Rute tidak ditemukan: ${settings.name}'),
            ),
          ),
        );
    }
  }
}
// --- IGNORE ---