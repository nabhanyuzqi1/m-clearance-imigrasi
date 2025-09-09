import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:m_clearance_imigrasi/firebase_options.dart';
import 'package:m_clearance_imigrasi/app/models/email_config.dart';
import 'package:m_clearance_imigrasi/app/services/email_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Initialize Firebase for testing
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  });

  group('EmailConfigService RTDB Tests', () {
    late EmailConfigService service;

    setUp(() {
      service = EmailConfigService();
    });

    test('Initialize default config', () async {
      print('[TEST] Testing initialize default config...');
      final success = await service.initializeDefaultConfig();
      expect(success, isTrue);
      print('[TEST] Default config initialized successfully');
    });

    test('Read email config from RTDB', () async {
      print('[TEST] Testing read email config...');
      final config = await service.getEmailConfig();
      expect(config, isNotNull);
      print('[TEST] Config read successfully: ${config?.smtpHost}');
    });

    test('Update email config in RTDB', () async {
      print('[TEST] Testing update email config...');
      final testConfig = EmailConfig(
        smtpHost: 'test.smtp.com',
        smtpPort: 587,
        smtpUsername: 'test@example.com',
        smtpPassword: 'testpass',
        smtpUseTls: true,
        fromEmail: 'noreply@test.com',
        fromName: 'Test System',
        verificationSubject: 'Test Verification',
        verificationBody: 'Please verify your email.',
        passwordResetSubject: 'Test Password Reset',
        passwordResetBody: 'Reset your password.',
        approvalSubject: 'Test Approval',
        approvalBody: 'Your application is approved.',
        rejectionSubject: 'Test Rejection',
        rejectionBody: 'Your application is rejected.',
        updatedAt: DateTime.now(),
      );

      final success = await service.updateEmailConfig(testConfig);
      expect(success, isTrue);
      print('[TEST] Config updated successfully');

      // Verify the update
      final readConfig = await service.getEmailConfig();
      expect(readConfig?.smtpHost, equals('test.smtp.com'));
      print('[TEST] Config verification successful');
    });

    test('Update SMTP settings', () async {
      print('[TEST] Testing update SMTP settings...');
      final success = await service.updateSmtpSettings(
        host: 'smtp.updated.com',
        port: 465,
        username: 'updated@example.com',
        password: 'updatedpass',
        useTls: false,
      );
      expect(success, isTrue);
      print('[TEST] SMTP settings updated successfully');

      // Verify the update
      final readConfig = await service.getEmailConfig();
      expect(readConfig?.smtpHost, equals('smtp.updated.com'));
      expect(readConfig?.smtpPort, equals(465));
      print('[TEST] SMTP settings verification successful');
    });

    test('Update email templates', () async {
      print('[TEST] Testing update email templates...');
      final success = await service.updateEmailTemplates(
        verificationSubject: 'Updated Verification Subject',
        verificationBody: 'Updated verification body.',
      );
      expect(success, isTrue);
      print('[TEST] Email templates updated successfully');

      // Verify the update
      final readConfig = await service.getEmailConfig();
      expect(readConfig?.verificationSubject, equals('Updated Verification Subject'));
      print('[TEST] Email templates verification successful');
    });

    test('Update sender info', () async {
      print('[TEST] Testing update sender info...');
      final success = await service.updateSenderInfo(
        fromEmail: 'updated@noreply.com',
        fromName: 'Updated System',
      );
      expect(success, isTrue);
      print('[TEST] Sender info updated successfully');

      // Verify the update
      final readConfig = await service.getEmailConfig();
      expect(readConfig?.fromEmail, equals('updated@noreply.com'));
      expect(readConfig?.fromName, equals('Updated System'));
      print('[TEST] Sender info verification successful');
    });
  });
}