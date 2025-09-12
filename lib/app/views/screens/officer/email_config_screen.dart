import 'package:flutter/material.dart';
import '../../../localization/app_strings.dart';
import '../../../models/email_config.dart';
import '../../../services/email_config_service.dart';
import '../../../services/logging_service.dart';
import '../../../config/theme.dart';
import '../../widgets/custom_app_bar.dart';

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
    LoggingService().info('EmailConfigScreen initialized with language: ${widget.initialLanguage}');
    _selectedLanguage = widget.initialLanguage;
    _loadEmailConfig();
  }

  Future<void> _loadEmailConfig() async {
    setState(() => _isLoading = true);
    try {
      LoggingService().info('Loading email configuration...');
      _emailConfig = await _configService.getEmailConfig();
      if (_emailConfig == null) {
        LoggingService().info('No config found, initializing default config...');
        // Initialize with default config
        await _configService.initializeDefaultConfig();
        _emailConfig = await _configService.getEmailConfig();
      }
      _populateControllers();
      LoggingService().info('Successfully loaded config: ${_emailConfig?.smtpHost}');
    } catch (e) {
      LoggingService().error('Error loading email config: $e', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.tr(
              context: context,
              screenKey: 'emailConfig',
              stringKey: 'error_loading',
              langCode: _selectedLanguage,
            )),
            backgroundColor: AppTheme.errorColor,
          ),
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
      LoggingService().info('Saving email configuration...');
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
        LoggingService().info('Successfully saved email config');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_tr('emailConfig', 'config_saved')),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } else {
        throw Exception('Failed to save configuration');
      }
    } catch (e) {
      LoggingService().error('Error saving email config: $e', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.tr(
              context: context,
              screenKey: 'emailConfig',
              stringKey: 'error_saving',
              langCode: _selectedLanguage,
            )),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.whiteColor,
      appBar: CustomAppBar(
        title: LogoTitle(
          text: AppStrings.tr(
            context: context,
            screenKey: 'splash',
            stringKey: 'app_name',
            langCode: _selectedLanguage,
          ),
        ),
        backgroundColor: AppTheme.whiteColor,
        foregroundColor: AppTheme.blackColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : _saveConfig,
              child: _isSaving
                  ? SizedBox(
                      width: AppTheme.spacing20,
                      height: AppTheme.spacing20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                    )
                  : Text(
                      _tr('emailConfig', 'save'),
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : SingleChildScrollView(
              padding: EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(_tr('emailConfig', 'smtp_settings')),
                  _buildTextField(_tr('emailConfig', 'smtp_host'), _smtpHostController),
                  _buildTextField(_tr('emailConfig', 'smtp_port'), _smtpPortController, keyboardType: TextInputType.number),
                  _buildTextField(_tr('emailConfig', 'smtp_username'), _smtpUsernameController),
                  _buildTextField(_tr('emailConfig', 'smtp_password'), _smtpPasswordController, obscureText: true),
                  _buildSwitchField(_tr('emailConfig', 'use_tls'), _smtpUseTls, (value) => setState(() => _smtpUseTls = value)),

                  SizedBox(height: AppTheme.spacing24),
                  _buildSectionTitle(_tr('emailConfig', 'sender_info')),
                  _buildTextField(_tr('emailConfig', 'from_email'), _fromEmailController, keyboardType: TextInputType.emailAddress),
                  _buildTextField(_tr('emailConfig', 'from_name'), _fromNameController),

                  SizedBox(height: AppTheme.spacing24),
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

                  SizedBox(height: AppTheme.spacing32),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacing8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: AppTheme.fontSizeH6,
          fontWeight: FontWeight.w600,
          color: AppTheme.onSurface,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text, bool obscureText = false, int maxLines = 1}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacing8),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        maxLines: maxLines,
        style: TextStyle(
          color: AppTheme.onSurface,
          fontFamily: 'Poppins',
        ),
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            borderSide: BorderSide(color: AppTheme.greyShade400),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            borderSide: BorderSide(color: AppTheme.greyShade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
          ),
          filled: true,
          fillColor: AppTheme.greyShade50,
          labelStyle: TextStyle(
            color: AppTheme.subtitleColor,
            fontFamily: 'Poppins',
          ),
          hintStyle: TextStyle(
            color: AppTheme.subtitleColor,
            fontFamily: 'Poppins',
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchField(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacing8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody1,
              color: AppTheme.onSurface,
              fontFamily: 'Poppins',
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primaryColor,
            activeTrackColor: AppTheme.primaryColor.withAlpha(128),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    LoggingService().debug('Disposing EmailConfigScreen resources');
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