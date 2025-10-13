import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../config/routes.dart';
import '../../../config/theme.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/account_session.dart';
import '../../../models/security_settings.dart';
import '../../../providers/language_provider.dart';
import '../../../services/logging_service.dart';
import '../../../services/security_service.dart';
import '../../widgets/custom_app_bar.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  final SecurityService _securityService = SecurityService();
  late Future<SecuritySettings> _settingsFuture;
  StreamSubscription<List<AccountSession>>? _sessionSubscription;
  final List<AccountSession> _sessions = [];

  bool _isUpdatingSettings = false;
  bool _showDeviceHistory = false;
  SecuritySettings? _cachedSettings;
  String? _errorMessage;

  String _tr(String key) {
    Provider.of<LanguageProvider>(context, listen: false).locale.languageCode;
    return AppLocalizations.of(context).get('privacySecurity.$key');
  }

  @override
  void initState() {
    super.initState();
    _settingsFuture = _securityService.fetchSettings();
    _listenSessions();
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    super.dispose();
  }

  void _listenSessions() {
    _sessionSubscription?.cancel();
    _sessionSubscription = _securityService
        .streamSessions(includeRevoked: _showDeviceHistory)
        .listen(
          (sessions) {
            if (!mounted) return;
            setState(() {
              _sessions
                ..clear()
                ..addAll(sessions);
            });
          },
          onError: (error) {
            LoggingService().warning(
              '[PrivacySecurityScreen] Failed to stream sessions',
              error,
            );
          },
        );
  }

  Future<void> _refreshSettings() async {
    setState(() {
      _settingsFuture = _securityService.fetchSettings();
      _errorMessage = null;
    });
    await _settingsFuture;
  }

  Future<void> _updateSettings(SecuritySettings newSettings) async {
    setState(() {
      _isUpdatingSettings = true;
      _cachedSettings = newSettings;
      _settingsFuture = Future.value(newSettings);
      _errorMessage = null;
    });

    try {
      await _securityService.updateSettings(newSettings);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('settings_saved')),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (error, stackTrace) {
      LoggingService().error(
        '[PrivacySecurityScreen] Failed to update settings',
        error,
        stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _errorMessage = _tr('settings_save_failed');
        _settingsFuture = Future.value(_cachedSettings);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('settings_save_failed')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingSettings = false);
      }
    }
  }

  Future<void> _handleRevokeSession(AccountSession session) async {
    if (session.isRevoked) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_tr('revoke_session_title')),
          content: Text(
            _tr(
              'revoke_session_message',
            ).replaceFirst('%s', session.deviceName),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_tr('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_tr('revoke')),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;

    try {
      await _securityService.revokeSession(session.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('session_revoked')),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('session_revoke_failed')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _signOutOtherDevices() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_tr('revoke_all_title')),
          content: Text(_tr('revoke_all_message')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_tr('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_tr('revoke')),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;

    try {
      await _securityService.revokeAllOtherSessions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('all_sessions_revoked')),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('all_sessions_revoke_failed')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _promptRecoveryEmail(SecuritySettings settings) async {
    final controller = TextEditingController(
      text: settings.recoveryEmail ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_tr('recovery_email_title')),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: _tr('recovery_email_label'),
              hintText: 'name@example.com',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_tr('cancel')),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: Text(_tr('save')),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    final updated = settings.copyWith(
      recoveryEmail: result.isEmpty ? null : result,
    );
    await _updateSettings(updated);
  }

  Widget _buildDeviceList(ColorScheme colorScheme, TextTheme textTheme) {
    if (_sessions.isEmpty) {
      return _SectionCard(
        icon: Icons.devices_other_outlined,
        color: colorScheme,
        header: _tr('devices_title'),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Text(
            _tr('no_devices'),
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final cards = _sessions.map((session) {
      final icon =
          session.platform.toLowerCase().contains('ios') ||
              session.platform.toLowerCase().contains('android')
          ? Icons.phone_iphone
          : Icons.computer;
      final currentColor = session.isCurrent
          ? colorScheme.primary
          : colorScheme.onSurfaceVariant;
      final revokeLabel = session.isRevoked
          ? _tr('session_revoked_label')
          : session.isCurrent
          ? _tr('current_session')
          : _tr('revoke');

      final subtitle = <String>[
        if (session.location != '—') session.location,
        if (session.ipAddress != '—') 'IP ${session.ipAddress}',
      ].join(' • ');

      return Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          side: BorderSide(
            color: session.isCurrent
                ? _alpha(colorScheme.primary, 0.4)
                : colorScheme.outlineVariant,
          ),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: _alpha(currentColor, 0.12),
            child: Icon(icon, color: currentColor),
          ),
          title: Text(
            session.deviceName,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: session.isCurrent
                  ? colorScheme.primary
                  : colorScheme.onSurface,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _tr(
                  'last_active',
                ).replaceFirst('%s', _formatTimestamp(session.lastActive)),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          trailing: TextButton(
            onPressed: session.isCurrent || session.isRevoked
                ? null
                : () => _handleRevokeSession(session),
            child: Text(revokeLabel),
          ),
        ),
      );
    }).toList();

    return _SectionCard(
      icon: Icons.devices_other_outlined,
      color: colorScheme,
      header: _tr('devices_title'),
      action: TextButton.icon(
        onPressed: _sessions.where((s) => !s.isCurrent && s.isActive).isNotEmpty
            ? _signOutOtherDevices
            : null,
        icon: const Icon(Icons.logout),
        label: Text(_tr('sign_out_others')),
      ),
      footer: Row(
        children: [
          Expanded(
            child: Text(
              _tr('include_history'),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Switch(
            value: _showDeviceHistory,
            onChanged: (value) {
              setState(() => _showDeviceHistory = value);
              _listenSessions();
            },
          ),
        ],
      ),
      child: Column(children: cards),
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    final locale = AppLocalizations.of(context).languageCode;
    final formatter = DateFormat.yMMMd(locale).add_Hm();
    return formatter.format(dateTime.toLocal());
  }

  Color _alpha(Color color, double opacity) {
    final clamped = opacity.clamp(0.0, 1.0);
    return color.withAlpha((clamped * 255).round());
  }

  @override
  Widget build(BuildContext context) {
    LoggingService().debug('Building PrivacySecurityScreen');
    final screenWidth = MediaQuery.of(context).size.width;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: CustomAppBar(titleText: _tr('title'), centerTitle: true),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshSettings,
          child: FutureBuilder<SecuritySettings>(
            future: _settingsFuture,
            builder: (context, snapshot) {
              final settings = snapshot.data ?? _cachedSettings;
              final isLoading =
                  snapshot.connectionState != ConnectionState.done &&
                  settings == null;

              if (isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              final effectiveSettings = settings ?? SecuritySettings.defaults();
              _cachedSettings ??= effectiveSettings;

              return ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth > 600
                      ? AppTheme.spacing32
                      : AppTheme.spacing16,
                  vertical: AppTheme.spacing24,
                ),
                children: [
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppTheme.spacing16,
                      ),
                      child: _ErrorBanner(message: _errorMessage!),
                    ),
                  _SectionCard(
                    icon: Icons.security_outlined,
                    color: colorScheme,
                    header: _tr('account_security'),
                    footer: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacing8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppTheme.spacing8),
                          Expanded(
                            child: Text(
                              _tr('two_factor_hint'),
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        _SecurityToggleTile(
                          title: _tr('two_factor_title'),
                          subtitle:
                              '${_tr('two_factor_subtitle')} (${_tr('coming_soon')})',
                          value: effectiveSettings.twoFactorEnabled,
                          onChanged: null,
                        ),
                        _SecurityToggleTile(
                          title: _tr('device_approval_title'),
                          subtitle:
                              '${_tr('device_approval_subtitle')} (${_tr('coming_soon')})',
                          value: effectiveSettings.deviceApprovalRequired,
                          onChanged: null,
                        ),
                        _SecurityToggleTile(
                          title: _tr('login_alerts_title'),
                          subtitle: _tr('login_alerts_subtitle'),
                          value: effectiveSettings.loginAlertsEnabled,
                          onChanged: _isUpdatingSettings
                              ? null
                              : (value) {
                                  final updated = effectiveSettings.copyWith(
                                    loginAlertsEnabled: value,
                                  );
                                  _updateSettings(updated);
                                },
                        ),
                        _SecurityToggleTile(
                          title: _tr('biometric_title'),
                          subtitle:
                              '${_tr('biometric_subtitle')} (${_tr('coming_soon')})',
                          value: effectiveSettings.biometricLockEnabled,
                          onChanged: null,
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.mail_outline,
                            color: colorScheme.primary,
                          ),
                          title: Text(_tr('recovery_email_title')),
                          subtitle: Text(
                            effectiveSettings.recoveryEmail ??
                                _tr('recovery_email_missing'),
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: TextButton(
                            onPressed: _isUpdatingSettings
                                ? null
                                : () => _promptRecoveryEmail(effectiveSettings),
                            child: Text(_tr('update')),
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.verified_user_outlined,
                            color: colorScheme.primary,
                          ),
                          title: Text(_tr('remember_devices_title')),
                          subtitle: Text(
                            _tr('remember_devices_subtitle').replaceFirst(
                              '%d',
                              effectiveSettings.rememberDeviceDays.toString(),
                            ),
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: DropdownButton<int>(
                            value: effectiveSettings.rememberDeviceDays,
                            onChanged: _isUpdatingSettings
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    final updated = effectiveSettings.copyWith(
                                      rememberDeviceDays: value,
                                    );
                                    _updateSettings(updated);
                                  },
                            items: [7, 15, 30, 60, 90]
                                .map(
                                  (days) => DropdownMenuItem<int>(
                                    value: days,
                                    child: Text('$days ${_tr('days_suffix')}'),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  _buildDeviceList(colorScheme, textTheme),
                  const SizedBox(height: AppTheme.spacing16),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            Icons.article_outlined,
                            color: colorScheme.primary,
                          ),
                          title: Text(_tr('link_terms')),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              Navigator.pushNamed(context, AppRoutes.terms),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(
                            Icons.privacy_tip_outlined,
                            color: colorScheme.primary,
                          ),
                          title: Text(_tr('link_privacy')),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              Navigator.pushNamed(context, AppRoutes.privacy),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.support_agent_outlined,
                        color: colorScheme.primary,
                      ),
                      title: Text(
                        _tr('contact_title'),
                        style: textTheme.titleMedium,
                      ),
                      subtitle: StreamBuilder<String>(
                        stream: _securityService.supportEmailStream(),
                        initialData: 'mclearanceisam@gmail.com',
                        builder: (context, snapshot) {
                          final email = snapshot.data ?? 'mclearanceisam@gmail.com';
                          return Text(
                            _tr('contact_body').replaceFirst('{email}', email),
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.color,
    required this.header,
    required this.child,
    this.footer,
    this.action,
  });

  final IconData icon;
  final ColorScheme color;
  final String header;
  final Widget child;
  final Widget? footer;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        side: BorderSide(color: color.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.primaryContainer.withAlpha(64),
                  child: Icon(icon, color: color.primary),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Text(
                    header,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: AppTheme.spacing16),
            child,
            if (footer != null) ...[
              const SizedBox(height: AppTheme.spacing12),
              Divider(color: color.outlineVariant),
              const SizedBox(height: AppTheme.spacing8),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}

class _SecurityToggleTile extends StatelessWidget {
  const _SecurityToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return Column(
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: false,
          controlAffinity: ListTileControlAffinity.trailing,
          title: Text(
            title,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            subtitle,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          value: value,
          onChanged: onChanged,
        ),
        Divider(color: colorScheme.outlineVariant.withAlpha(64)),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
