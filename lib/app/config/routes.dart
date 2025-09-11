import 'package:flutter/material.dart';
import 'package:m_clearance_imigrasi/app/config/fade_route.dart';
import '../models/clearance_application.dart';
import '../views/screens/auth/change_password_screen.dart';
import '../views/screens/auth/confirmation_screen.dart';
import '../views/screens/auth/forgot_password_screen.dart';
import '../views/screens/auth/login_screen.dart' as auth;
import '../views/screens/auth/register_screen.dart';
import '../views/screens/auth/registration_pending_screen.dart';
import '../views/screens/auth/splash_screen.dart';
import '../views/screens/auth/upload_documents_screen.dart';
// import '../views/screens/auth/email_verification_screen.dart';
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
import '../views/screens/user/submission_sent_screen.dart';
import '../views/screens/user/submission_waiting_screen.dart';
import '../views/screens/officer/email_config_screen.dart';

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
  static const String submissionSent = '/submission-sent';
  static const String submissionWaiting = '/submission-waiting';

  static const String adminHome = '/admin-home';
  static const String adminNotification = '/admin-notification';
  static const String editOfficerProfile = '/edit-officer-profile';
  static const String officerReport = '/officer-report';
  static const String accountVerificationList = '/account-verification-list';
  static const String accountDetail = '/account-detail';
  static const String arrivalVerification = '/arrival-verification';
  static const String departureVerification = '/departure-verification';
  static const String submissionDetail = '/submission-detail';
  static const String emailConfig = '/email-config';
  
  // === GENERATOR RUTE ===
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    // Mengambil argumen jika ada
    final args = settings.arguments;

    switch (settings.name) {
      case splash:
        return FadeRoute(page: const SplashScreen());
      case login:
        return FadeRoute(page: const auth.LoginScreen());
      case register:
        final arguments = args as Map<String, dynamic>? ?? {};
        return FadeRoute(page: RegisterScreen(initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      case forgotPassword:
         final arguments = args as Map<String, dynamic>? ?? {};
        return FadeRoute(page: ForgotPasswordScreen(initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      case changePassword:
        final arguments = args as Map<String, dynamic>? ?? {};
        return FadeRoute(page: ChangePasswordScreen(initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      case confirmation:
        final arguments = args as Map<String, dynamic>? ?? {};
        return FadeRoute(page: ConfirmationScreen(userData: arguments['userData'], initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      case uploadDocuments:
        final arguments = args as Map<String, dynamic>? ?? {};
        return FadeRoute(page: UploadDocumentsScreen(initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      case registrationPending:
        final arguments = args as Map<String, dynamic>? ?? {};
        return FadeRoute(page: RegistrationPendingScreen(initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      case emailVerification:
        // Backwards compatibility: route to code confirmation flow instead of link method.
        final arguments = args as Map<String, dynamic>? ?? {};
        return FadeRoute(page: ConfirmationScreen(userData: (arguments['userData'] as Map<String, String>?) ?? const {}, initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      
      case userHome:
        return FadeRoute(page: const UserHomeScreen());
      case userNotification:
        final arguments = args as Map<String, dynamic>? ?? {};
        return FadeRoute(page: user_notif.NotificationScreen(initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      case editAgentProfile:
        final arguments = args as Map<String, dynamic>? ?? {};
        return FadeRoute(page: EditAgentProfileScreen(username: arguments['username'] ?? '', currentName: arguments['currentName'] ?? '', currentEmail: arguments['currentEmail'] ?? '', currentProfileImageUrl: arguments['currentProfileImageUrl'], initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      case clearanceForm:
        final arguments = args as Map<String, dynamic>? ?? {};
        return FadeRoute(page: ClearanceFormScreen(type: arguments['type'], agentName: arguments['agentName'], existingApplication: arguments['existingApplication'], initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      case verificationLoading:
        final arguments = args as Map<String, dynamic>? ?? {};
        return FadeRoute(page: VerificationLoadingScreen(application: arguments['application'], initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      case clearanceResult:
        final arguments = args as Map<String, dynamic>? ?? {};
        return FadeRoute(page: ClearanceResultScreen(application: arguments['application'], initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      case submissionSent:
        final arguments = args as Map<String, dynamic>? ?? {};
        return FadeRoute(page: SubmissionSentScreen(initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      case submissionWaiting:
        final arguments = args as Map<String, dynamic>? ?? {};
        return FadeRoute(page: SubmissionWaitingScreen(initialLanguage: arguments['initialLanguage'] ?? 'EN'));

      case adminHome:
        final arguments = args as Map<String, dynamic>? ?? {};
        return FadeRoute(page: AdminHomeScreen(adminName: arguments['adminName'] ?? '', adminUsername: arguments['adminUsername'] ?? '', initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      case adminNotification:
        final arguments = args as Map<String, dynamic>? ?? {};
        return FadeRoute(page: OfficerNotificationScreen(initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      case editOfficerProfile:
        final arguments = args as Map<String, dynamic>? ?? {};
        return FadeRoute(page: EditProfileScreen(initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      case officerReport:
        final arguments = args as Map<String, dynamic>? ?? {};
        return FadeRoute(page: OfficerReportScreen(initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      case accountVerificationList:
        final arguments = args as Map<String, dynamic>? ?? {};
        return FadeRoute(page: AccountVerificationListScreen(initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      case accountDetail:
        final arguments = args as Map<String, dynamic>? ?? {};
        return FadeRoute(
          page: AccountDetailScreen(
            uid: arguments['uid'] ?? '',
            initialLanguage: arguments['initialLanguage'] ?? 'EN',
          ),
        );
      case arrivalVerification:
        final arguments = args as Map<String, dynamic>? ?? {};
        return FadeRoute(page: ArrivalVerificationScreen(adminName: arguments['adminName'] ?? '', initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      case departureVerification:
        final arguments = args as Map<String, dynamic>? ?? {};
        return FadeRoute(page: DepartureVerificationScreen(adminName: arguments['adminName'] ?? '', initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      case submissionDetail:
        final arguments = args as Map<String, dynamic>? ?? {};
        return FadeRoute(page: SubmissionDetailScreen(application: arguments['application'], adminName: arguments['adminName'] ?? '', initialLanguage: arguments['initialLanguage'] ?? 'EN'));
      case emailConfig:
        final arguments = args as Map<String, dynamic>? ?? {};
        return FadeRoute(page: EmailConfigScreen(initialLanguage: arguments['initialLanguage'] ?? 'EN'));

      default:
        // Halaman default jika rute tidak ditemukan
        return FadeRoute(
          page: Scaffold(
            body: Center(
              child: Text('Rute tidak ditemukan: ${settings.name}'),
            ),
          ),
        );
    }
  }
}
// --- IGNORE ---
