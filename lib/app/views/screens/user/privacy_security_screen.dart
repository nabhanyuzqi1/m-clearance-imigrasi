import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/routes.dart';
import '../../../config/theme.dart';
import '../../../localization/app_localizations.dart';
import '../../../providers/language_provider.dart';
import '../../../services/logging_service.dart';
import '../../widgets/custom_app_bar.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  String _tr(String key) {
    Provider.of<LanguageProvider>(context, listen: false).locale.languageCode;
    return AppLocalizations.of(context).get('privacySecurity.$key');
  }

  @override
  Widget build(BuildContext context) {
    LoggingService().debug('Building PrivacySecurityScreen');
    final screenWidth = MediaQuery.of(context).size.width;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final sections = [
      _PrivacySection(
        icon: Icons.shield_outlined,
        title: _tr('data_protection_title'),
        points: _points(_tr('data_protection_points')),
      ),
      _PrivacySection(
        icon: Icons.settings_suggest_outlined,
        title: _tr('security_tools_title'),
        points: _points(_tr('security_tools_points')),
      ),
      _PrivacySection(
        icon: Icons.lightbulb_outline,
        title: _tr('best_practices_title'),
        points: _points(_tr('best_practices_points')),
      ),
    ];

    return Scaffold(
      appBar: CustomAppBar(titleText: _tr('title'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth > 600
                ? AppTheme.spacing32
                : AppTheme.spacing16,
            vertical: AppTheme.spacing24,
          ),
          children: [
            Text(
              _tr('content'),
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTheme.spacing24),
            ...sections.map((section) => _PrivacySectionCard(section: section)),
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
                    onTap: () => Navigator.pushNamed(context, AppRoutes.terms),
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
                title: Text(_tr('contact_title'), style: textTheme.titleMedium),
                subtitle: Text(
                  _tr('contact_body'),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _points(String raw) => raw
      .split('|')
      .map((point) => point.trim())
      .where((point) => point.isNotEmpty)
      .toList();
}

class _PrivacySection {
  const _PrivacySection({
    required this.icon,
    required this.title,
    required this.points,
  });

  final IconData icon;
  final String title;
  final List<String> points;
}

class _PrivacySectionCard extends StatelessWidget {
  const _PrivacySectionCard({required this.section});

  final _PrivacySection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppTheme.spacing16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colorScheme.primary.withAlpha(31),
                  child: Icon(section.icon, color: colorScheme.primary),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Text(
                    section.title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),
            ...section.points.map(
              (point) => Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Expanded(
                      child: Text(
                        point,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
