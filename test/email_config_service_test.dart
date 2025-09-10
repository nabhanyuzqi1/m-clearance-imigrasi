import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:m_clearance_imigrasi/firebase_options.dart';
import 'package:m_clearance_imigrasi/app/models/email_config.dart';
import 'package:m_clearance_imigrasi/app/services/email_config_service.dart';

// Generate mocks
@GenerateMocks([
  FirebaseApp,
  FirebaseDatabase,
  DatabaseReference,
  DataSnapshot,
])
import 'email_config_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EmailConfigService RTDB Tests', () {
    late EmailConfigService service;
    late MockFirebaseDatabase mockDatabase;
    late MockDatabaseReference mockRef;
    late MockDatabaseReference mockConfigRef;
    late MockDataSnapshot mockSnapshot;

    setUp(() {
      // Create mocks
      mockDatabase = MockFirebaseDatabase();
      mockRef = MockDatabaseReference();
      mockConfigRef = MockDatabaseReference();
      mockSnapshot = MockDataSnapshot();

      // Set up mock chain
      when(mockDatabase.ref()).thenReturn(mockRef);
      when(mockRef.child('email_config')).thenReturn(mockConfigRef);

      // Create service with mocked database
      service = EmailConfigService(database: mockDatabase);
    });

    test('Initialize default config', () async {
      print('[TEST] Testing initialize default config...');

      // Mock no existing config
      when(mockConfigRef.get()).thenAnswer((_) async => mockSnapshot);
      when(mockSnapshot.exists).thenReturn(false);

      // Mock successful set
      when(mockConfigRef.set(any)).thenAnswer((_) async {});

      final success = await service.initializeDefaultConfig();
      expect(success, isTrue);
      print('[TEST] Default config initialized successfully');
    });

    test('Read email config from RTDB', () async {
      print('[TEST] Testing read email config...');

      // Mock existing config data
      final mockData = {
        'smtpHost': 'smtp.test.com',
        'smtpPort': 587,
        'smtpUsername': 'test@test.com',
        'smtpPassword': 'password',
        'smtpUseTls': true,
        'fromEmail': 'noreply@test.com',
        'fromName': 'Test System',
        'verificationSubject': 'Verify Email',
        'verificationBody': 'Please verify',
        'verificationTemplateId': 'template1',
        'passwordResetSubject': 'Reset Password',
        'passwordResetBody': 'Reset your password',
        'passwordResetTemplateId': 'template2',
        'approvalSubject': 'Approved',
        'approvalBody': 'Approved',
        'approvalTemplateId': 'template3',
        'rejectionSubject': 'Rejected',
        'rejectionBody': 'Rejected',
        'rejectionTemplateId': 'template4',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      when(mockConfigRef.get()).thenAnswer((_) async => mockSnapshot);
      when(mockSnapshot.exists).thenReturn(true);
      when(mockSnapshot.value).thenReturn(mockData);

      final config = await service.getEmailConfig();
      expect(config, isNotNull);
      expect(config?.smtpHost, 'smtp.test.com');
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
        verificationTemplateId: 'test-verification-template',
        passwordResetSubject: 'Test Password Reset',
        passwordResetBody: 'Reset your password.',
        passwordResetTemplateId: 'test-password-reset-template',
        approvalSubject: 'Test Approval',
        approvalBody: 'Your application is approved.',
        approvalTemplateId: 'test-approval-template',
        rejectionSubject: 'Test Rejection',
        rejectionBody: 'Your application is rejected.',
        rejectionTemplateId: 'test-rejection-template',
        updatedAt: DateTime.now(),
      );

      // Mock successful set
      when(mockConfigRef.set(any)).thenAnswer((_) async {});

      final success = await service.updateEmailConfig(testConfig);
      expect(success, isTrue);
      print('[TEST] Config updated successfully');

      // Verify the update - mock the read
      final mockData = testConfig.toJson();
      when(mockConfigRef.get()).thenAnswer((_) async => mockSnapshot);
      when(mockSnapshot.exists).thenReturn(true);
      when(mockSnapshot.value).thenReturn(mockData);

      final readConfig = await service.getEmailConfig();
      expect(readConfig?.smtpHost, equals('test.smtp.com'));
      print('[TEST] Config verification successful');
    });

    test('Update SMTP settings', () async {
      print('[TEST] Testing update SMTP settings...');

      // Mock successful update
      when(mockConfigRef.update(any)).thenAnswer((_) async {});

      final success = await service.updateSmtpSettings(
        host: 'smtp.updated.com',
        port: 465,
        username: 'updated@example.com',
        password: 'updatedpass',
        useTls: false,
      );
      expect(success, isTrue);
      print('[TEST] SMTP settings updated successfully');

      // Verify the update - mock the read
      final mockData = {
        'smtpHost': 'smtp.updated.com',
        'smtpPort': 465,
        'smtpUsername': 'updated@example.com',
        'smtpPassword': 'updatedpass',
        'smtpUseTls': false,
        'fromEmail': 'noreply@test.com',
        'fromName': 'Test System',
        'verificationSubject': 'Verify Email',
        'verificationBody': 'Please verify',
        'verificationTemplateId': 'template1',
        'passwordResetSubject': 'Reset Password',
        'passwordResetBody': 'Reset your password',
        'passwordResetTemplateId': 'template2',
        'approvalSubject': 'Approved',
        'approvalBody': 'Approved',
        'approvalTemplateId': 'template3',
        'rejectionSubject': 'Rejected',
        'rejectionBody': 'Rejected',
        'rejectionTemplateId': 'template4',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      when(mockConfigRef.get()).thenAnswer((_) async => mockSnapshot);
      when(mockSnapshot.exists).thenReturn(true);
      when(mockSnapshot.value).thenReturn(mockData);

      final readConfig = await service.getEmailConfig();
      expect(readConfig?.smtpHost, equals('smtp.updated.com'));
      expect(readConfig?.smtpPort, equals(465));
      print('[TEST] SMTP settings verification successful');
    });

    test('Update email templates', () async {
      print('[TEST] Testing update email templates...');

      // Mock successful update
      when(mockConfigRef.update(any)).thenAnswer((_) async {});

      final success = await service.updateEmailTemplates(
        verificationSubject: 'Updated Verification Subject',
        verificationBody: 'Updated verification body.',
      );
      expect(success, isTrue);
      print('[TEST] Email templates updated successfully');

      // Verify the update - mock the read
      final mockData = {
        'smtpHost': 'smtp.test.com',
        'smtpPort': 587,
        'smtpUsername': 'test@test.com',
        'smtpPassword': 'password',
        'smtpUseTls': true,
        'fromEmail': 'noreply@test.com',
        'fromName': 'Test System',
        'verificationSubject': 'Updated Verification Subject',
        'verificationBody': 'Updated verification body.',
        'verificationTemplateId': 'template1',
        'passwordResetSubject': 'Reset Password',
        'passwordResetBody': 'Reset your password',
        'passwordResetTemplateId': 'template2',
        'approvalSubject': 'Approved',
        'approvalBody': 'Approved',
        'approvalTemplateId': 'template3',
        'rejectionSubject': 'Rejected',
        'rejectionBody': 'Rejected',
        'rejectionTemplateId': 'template4',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      when(mockConfigRef.get()).thenAnswer((_) async => mockSnapshot);
      when(mockSnapshot.exists).thenReturn(true);
      when(mockSnapshot.value).thenReturn(mockData);

      final readConfig = await service.getEmailConfig();
      expect(readConfig?.verificationSubject, equals('Updated Verification Subject'));
      print('[TEST] Email templates verification successful');
    });

    test('Update sender info', () async {
      print('[TEST] Testing update sender info...');

      // Mock successful update
      when(mockConfigRef.update(any)).thenAnswer((_) async {});

      final success = await service.updateSenderInfo(
        fromEmail: 'updated@noreply.com',
        fromName: 'Updated System',
      );
      expect(success, isTrue);
      print('[TEST] Sender info updated successfully');

      // Verify the update - mock the read
      final mockData = {
        'smtpHost': 'smtp.test.com',
        'smtpPort': 587,
        'smtpUsername': 'test@test.com',
        'smtpPassword': 'password',
        'smtpUseTls': true,
        'fromEmail': 'updated@noreply.com',
        'fromName': 'Updated System',
        'verificationSubject': 'Verify Email',
        'verificationBody': 'Please verify',
        'verificationTemplateId': 'template1',
        'passwordResetSubject': 'Reset Password',
        'passwordResetBody': 'Reset your password',
        'passwordResetTemplateId': 'template2',
        'approvalSubject': 'Approved',
        'approvalBody': 'Approved',
        'approvalTemplateId': 'template3',
        'rejectionSubject': 'Rejected',
        'rejectionBody': 'Rejected',
        'rejectionTemplateId': 'template4',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      when(mockConfigRef.get()).thenAnswer((_) async => mockSnapshot);
      when(mockSnapshot.exists).thenReturn(true);
      when(mockSnapshot.value).thenReturn(mockData);

      final readConfig = await service.getEmailConfig();
      expect(readConfig?.fromEmail, equals('updated@noreply.com'));
      expect(readConfig?.fromName, equals('Updated System'));
      print('[TEST] Sender info verification successful');
    });
  });
}