import 'package:flutter/material.dart';
import '../../../localization/app_strings.dart';
import '../../../models/email_config.dart';
import '../../../services/email_config_service.dart';

class EmailConfigScreen extends StatefulWidget {
  final String initialLanguage;

  const EmailConfigScreen({super.key, required this.initialLanguage});

  @override
  State<EmailConfigScreen> createState() => _EmailConfigScreenState();
}

class _EmailConfigScreenState extends State<EmailConfigScreen> {
  final EmailConfigService _configService = EmailConfigService();
  EmailConfig? _emailConfig;
  bool _isLoading = true;
  bool _isSaving = false;

  late String _selectedLanguage;

  // Controllers for form fields
  final TextEditingController _smtpHostController = TextEditingController();
  final TextEditingController _smtpPortController = TextEditingController();
  final TextEditingController _smtpUsernameController = TextEditingController();
  final TextEditingController _smtpPasswordController = TextEditingController();
  final TextEditingController _fromEmailController = TextEditingController();
  final TextEditingController _fromNameController = TextEditingController();
  final TextEditingController _verificationSubjectController = TextEditingController();
  final TextEditingController _verificationBodyController = TextEditingController();
  final TextEditingController _verificationTemplateIdController = TextEditingController();
  final TextEditingController _passwordResetSubjectController = TextEditingController();
  final TextEditingController _passwordResetBodyController = TextEditingController();
  final TextEditingController _passwordResetTemplateIdController = TextEditingController();
  final TextEditingController _approvalSubjectController = TextEditingController();
  final TextEditingController _approvalBodyController = TextEditingController();
  final TextEditingController _approvalTemplateIdController = TextEditingController();
  final TextEditingController _rejectionSubjectController = TextEditingController();
  final TextEditingController _rejectionBodyController = TextEditingController();
  final TextEditingController _rejectionTemplateIdController = TextEditingController();

  bool _smtpUseTls = true;

  String _tr(String screenKey, String stringKey) => AppStrings.tr(
        context: context,
        screenKey: screenKey,
        stringKey: stringKey,
        langCode: _selectedLanguage,
      );

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
    _loadEmailConfig();
  }

  Future<void> _loadEmailConfig() async {
    setState(() => _isLoading = true);
    try {
      print('[EmailConfigScreen] Loading email configuration...');
      _emailConfig = await _configService.getEmailConfig();
      if (_emailConfig == null) {
        print('[EmailConfigScreen] No config found, initializing default config...');
        // Initialize with default config
        await _configService.initializeDefaultConfig();
        _emailConfig = await _configService.getEmailConfig();
      }
      _populateControllers();
      print('[EmailConfigScreen] Successfully loaded config: ${_emailConfig?.smtpHost}');
    } catch (e) {
      print('[EmailConfigScreen] Error loading config: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading config: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _populateControllers() {
    if (_emailConfig != null) {
      _smtpHostController.text = _emailConfig!.smtpHost;
      _smtpPortController.text = _emailConfig!.smtpPort.toString();
      _smtpUsernameController.text = _emailConfig!.smtpUsername;
      _smtpPasswordController.text = _emailConfig!.smtpPassword;
      _smtpUseTls = _emailConfig!.smtpUseTls;
      _fromEmailController.text = _emailConfig!.fromEmail;
      _fromNameController.text = _emailConfig!.fromName;
      _verificationSubjectController.text = _emailConfig!.verificationSubject;
      _verificationBodyController.text = _emailConfig!.verificationBody;
      _verificationTemplateIdController.text = _emailConfig!.verificationTemplateId;
      _passwordResetSubjectController.text = _emailConfig!.passwordResetSubject;
      _passwordResetBodyController.text = _emailConfig!.passwordResetBody;
      _passwordResetTemplateIdController.text = _emailConfig!.passwordResetTemplateId;
      _approvalSubjectController.text = _emailConfig!.approvalSubject;
      _approvalBodyController.text = _emailConfig!.approvalBody;
      _approvalTemplateIdController.text = _emailConfig!.approvalTemplateId;
      _rejectionSubjectController.text = _emailConfig!.rejectionSubject;
      _rejectionBodyController.text = _emailConfig!.rejectionBody;
      _rejectionTemplateIdController.text = _emailConfig!.rejectionTemplateId;
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);
    try {
      print('[EmailConfigScreen] Saving email configuration...');
      final updatedConfig = EmailConfig(
        smtpHost: _smtpHostController.text,
        smtpPort: int.tryParse(_smtpPortController.text) ?? 587,
        smtpUsername: _smtpUsernameController.text,
        smtpPassword: _smtpPasswordController.text,
        smtpUseTls: _smtpUseTls,
        fromEmail: _fromEmailController.text,
        fromName: _fromNameController.text,
        verificationSubject: _verificationSubjectController.text,
        verificationBody: _verificationBodyController.text,
        verificationTemplateId: _verificationTemplateIdController.text,
        passwordResetSubject: _passwordResetSubjectController.text,
        passwordResetBody: _passwordResetBodyController.text,
        passwordResetTemplateId: _passwordResetTemplateIdController.text,
        approvalSubject: _approvalSubjectController.text,
        approvalBody: _approvalBodyController.text,
        approvalTemplateId: _approvalTemplateIdController.text,
        rejectionSubject: _rejectionSubjectController.text,
        rejectionBody: _rejectionBodyController.text,
        rejectionTemplateId: _rejectionTemplateIdController.text,
        updatedAt: DateTime.now(),
      );

      final success = await _configService.updateEmailConfig(updatedConfig);
      if (success) {
        setState(() => _emailConfig = updatedConfig);
        print('[EmailConfigScreen] Successfully saved config');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_tr('emailConfig', 'config_saved'))),
          );
        }
      } else {
        throw Exception('Failed to save configuration');
      }
    } catch (e) {
      print('[EmailConfigScreen] Error saving config: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving config: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _tr('emailConfig', 'email_configuration'),
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : _saveConfig,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _tr('emailConfig', 'save'),
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(_tr('emailConfig', 'smtp_settings')),
                  _buildTextField(_tr('emailConfig', 'smtp_host'), _smtpHostController),
                  _buildTextField(_tr('emailConfig', 'smtp_port'), _smtpPortController, keyboardType: TextInputType.number),
                  _buildTextField(_tr('emailConfig', 'smtp_username'), _smtpUsernameController),
                  _buildTextField(_tr('emailConfig', 'smtp_password'), _smtpPasswordController, obscureText: true),
                  _buildSwitchField(_tr('emailConfig', 'use_tls'), _smtpUseTls, (value) => setState(() => _smtpUseTls = value)),

                  const SizedBox(height: 24),
                  _buildSectionTitle(_tr('emailConfig', 'sender_info')),
                  _buildTextField(_tr('emailConfig', 'from_email'), _fromEmailController, keyboardType: TextInputType.emailAddress),
                  _buildTextField(_tr('emailConfig', 'from_name'), _fromNameController),

                  const SizedBox(height: 24),
                  _buildSectionTitle(_tr('emailConfig', 'email_templates')),
                  _buildTextField(_tr('emailConfig', 'verification_subject'), _verificationSubjectController),
                  _buildTextField(_tr('emailConfig', 'verification_body'), _verificationBodyController, maxLines: 3),
                  _buildTextField(_tr('emailConfig', 'verification_template_id'), _verificationTemplateIdController),
                  _buildTextField(_tr('emailConfig', 'password_reset_subject'), _passwordResetSubjectController),
                  _buildTextField(_tr('emailConfig', 'password_reset_body'), _passwordResetBodyController, maxLines: 3),
                  _buildTextField(_tr('emailConfig', 'password_reset_template_id'), _passwordResetTemplateIdController),
                  _buildTextField(_tr('emailConfig', 'approval_subject'), _approvalSubjectController),
                  _buildTextField(_tr('emailConfig', 'approval_body'), _approvalBodyController, maxLines: 3),
                  _buildTextField(_tr('emailConfig', 'approval_template_id'), _approvalTemplateIdController),
                  _buildTextField(_tr('emailConfig', 'rejection_subject'), _rejectionSubjectController),
                  _buildTextField(_tr('emailConfig', 'rejection_body'), _rejectionBodyController, maxLines: 3),
                  _buildTextField(_tr('emailConfig', 'rejection_template_id'), _rejectionTemplateIdController),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text, bool obscureText = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
    );
  }

  Widget _buildSwitchField(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: Colors.blue,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _smtpHostController.dispose();
    _smtpPortController.dispose();
    _smtpUsernameController.dispose();
    _smtpPasswordController.dispose();
    _fromEmailController.dispose();
    _fromNameController.dispose();
    _verificationSubjectController.dispose();
    _verificationBodyController.dispose();
    _verificationTemplateIdController.dispose();
    _passwordResetSubjectController.dispose();
    _passwordResetBodyController.dispose();
    _passwordResetTemplateIdController.dispose();
    _approvalSubjectController.dispose();
    _approvalBodyController.dispose();
    _approvalTemplateIdController.dispose();
    _rejectionSubjectController.dispose();
    _rejectionBodyController.dispose();
    _rejectionTemplateIdController.dispose();
    super.dispose();
  }
}