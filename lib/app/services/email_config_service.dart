import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:m_clearance_imigrasi/app/models/email_config.dart';

class EmailConfigService {
  final FirebaseDatabase _database;
  static const String _configPath = 'email_config';

  EmailConfigService({
    FirebaseDatabase? database,
  }) : _database = database ?? FirebaseDatabase.instance;

  DatabaseReference get _configRef => _database.ref().child(_configPath);

  /// Get current email configuration
  Future<EmailConfig?> getEmailConfig() async {
    try {
      print('[EmailConfigService] Attempting to read from RTDB path: $_configPath');
      final snapshot = await _configRef.get();
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        print('[EmailConfigService] Successfully read config from RTDB: ${data.keys}');
        return EmailConfig.fromJson(data);
      }
      print('[EmailConfigService] No config found in RTDB at path: $_configPath');
      return null;
    } catch (e) {
      print('[EmailConfigService] Error getting email config: $e');
      return null;
    }
  }

  /// Update email configuration
  Future<bool> updateEmailConfig(EmailConfig config) async {
    try {
      final updatedConfig = config.copyWith(updatedAt: DateTime.now());
      print('[EmailConfigService] Attempting to write config to RTDB path: $_configPath');
      await _configRef.set(updatedConfig.toJson());
      print('[EmailConfigService] Successfully updated config in RTDB');
      return true;
    } catch (e) {
      print('[EmailConfigService] Error updating email config: $e');
      return false;
    }
  }

  /// Listen to email configuration changes
  Stream<EmailConfig?> onEmailConfigChanged() {
    return _configRef.onValue.map((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        return EmailConfig.fromJson(data);
      }
      return null;
    });
  }

  /// Update specific SMTP settings
  Future<bool> updateSmtpSettings({
    required String host,
    required int port,
    required String username,
    required String password,
    required bool useTls,
  }) async {
    try {
      final updates = {
        'smtpHost': host,
        'smtpPort': port,
        'smtpUsername': username,
        'smtpPassword': password,
        'smtpUseTls': useTls,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };
      await _configRef.update(updates);
      return true;
    } catch (e) {
      print('Error updating SMTP settings: $e');
      return false;
    }
  }

  /// Update email templates
  Future<bool> updateEmailTemplates({
    String? verificationSubject,
    String? verificationBody,
    String? verificationTemplateId,
    String? passwordResetSubject,
    String? passwordResetBody,
    String? passwordResetTemplateId,
    String? approvalSubject,
    String? approvalBody,
    String? approvalTemplateId,
    String? rejectionSubject,
    String? rejectionBody,
    String? rejectionTemplateId,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      if (verificationSubject != null) updates['verificationSubject'] = verificationSubject;
      if (verificationBody != null) updates['verificationBody'] = verificationBody;
      if (verificationTemplateId != null) updates['verificationTemplateId'] = verificationTemplateId;
      if (passwordResetSubject != null) updates['passwordResetSubject'] = passwordResetSubject;
      if (passwordResetBody != null) updates['passwordResetBody'] = passwordResetBody;
      if (passwordResetTemplateId != null) updates['passwordResetTemplateId'] = passwordResetTemplateId;
      if (approvalSubject != null) updates['approvalSubject'] = approvalSubject;
      if (approvalBody != null) updates['approvalBody'] = approvalBody;
      if (approvalTemplateId != null) updates['approvalTemplateId'] = approvalTemplateId;
      if (rejectionSubject != null) updates['rejectionSubject'] = rejectionSubject;
      if (rejectionBody != null) updates['rejectionBody'] = rejectionBody;
      if (rejectionTemplateId != null) updates['rejectionTemplateId'] = rejectionTemplateId;

      await _configRef.update(updates);
      return true;
    } catch (e) {
      print('Error updating email templates: $e');
      return false;
    }
  }

  /// Update sender information
  Future<bool> updateSenderInfo({
    required String fromEmail,
    required String fromName,
  }) async {
    try {
      final updates = {
        'fromEmail': fromEmail,
        'fromName': fromName,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };
      await _configRef.update(updates);
      return true;
    } catch (e) {
      print('Error updating sender info: $e');
      return false;
    }
  }

  /// Initialize default email configuration if none exists
  Future<bool> initializeDefaultConfig() async {
    try {
      final existing = await getEmailConfig();
      if (existing != null) return true;

      final defaultConfig = EmailConfig(
        smtpHost: 'smtp.gmail.com',
        smtpPort: 587,
        smtpUsername: '',
        smtpPassword: '',
        smtpUseTls: true,
        fromEmail: 'noreply@mclearance.com',
        fromName: 'M-Clearance System',
        verificationSubject: 'Verify Your Email - M-Clearance',
        verificationBody: 'Please click the link to verify your email address.',
        verificationTemplateId: '',
        passwordResetSubject: 'Reset Your Password - M-Clearance',
        passwordResetBody: 'Please click the link to reset your password.',
        passwordResetTemplateId: '',
        approvalSubject: 'Application Approved - M-Clearance',
        approvalBody: 'Congratulations! Your clearance application has been approved.',
        approvalTemplateId: '',
        rejectionSubject: 'Application Update - M-Clearance',
        rejectionBody: 'We regret to inform you that your application requires additional information.',
        rejectionTemplateId: '',
        updatedAt: DateTime.now(),
      );

      return await updateEmailConfig(defaultConfig);
    } catch (e) {
      print('Error initializing default config: $e');
      return false;
    }
  }

  /// Delete email configuration
  Future<bool> deleteEmailConfig() async {
    try {
      await _configRef.remove();
      return true;
    } catch (e) {
      print('Error deleting email config: $e');
      return false;
    }
  }
}