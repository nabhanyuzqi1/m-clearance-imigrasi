import 'package:flutter/material.dart';
import '../../../localization/app_strings.dart';
import '../../../config/theme.dart';
import '../../../services/logging_service.dart';
import '../../../services/functions_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/bouncing_dots_loader.dart';

class OfficerVerificationScreen extends StatefulWidget {
  final String initialLanguage;

  const OfficerVerificationScreen({super.key, required this.initialLanguage});

  @override
  State<OfficerVerificationScreen> createState() =>
      _OfficerVerificationScreenState();
}

class _OfficerVerificationScreenState extends State<OfficerVerificationScreen> {
  late String _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
    LoggingService().info('OfficerVerificationScreen initialized');
  }

  String _tr(String stringKey) => AppStrings.tr(
    screenKey: 'officerSettings',
    stringKey: stringKey,
    langCode: _selectedLanguage,
  );

  Future<Map<String, dynamic>> _getVerificationStats() async {
    try {
      final functions = FunctionsService();
      return await functions.getOfficerDashboardStats();
    } catch (e) {
      LoggingService().error('Failed to load verification stats: $e');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    LoggingService().debug(
      'Building OfficerVerificationScreen with language: $_selectedLanguage',
    );
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.06;
    final maxWidth = screenWidth > 600 ? 600.0 : double.infinity;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: CustomAppBar(titleText: _tr('verification_statistics')),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: FutureBuilder<Map<String, dynamic>>(
              future: _getVerificationStats(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: BouncingDotsLoader());
                }

                final stats = snapshot.data ?? {};
                return Column(
                  children: [
                    _buildStatsCard(
                      title: _tr('pending_arrivals'),
                      value: stats['pendingArrival']?.toString() ?? '0',
                      icon: Icons.anchor,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    _buildStatsCard(
                      title: _tr('pending_departures'),
                      value: stats['pendingDeparture']?.toString() ?? '0',
                      icon: Icons.directions_boat,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    _buildStatsCard(
                      title: _tr('pending_accounts'),
                      value: stats['pendingAccounts']?.toString() ?? '0',
                      icon: Icons.person_add,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: AppTheme.responsiveFontSize(
                        context,
                        mobile: AppTheme.fontSizeBody1,
                        tablet: AppTheme.fontSizeH6,
                        desktop: AppTheme.fontSizeH6,
                      ),
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: AppTheme.responsiveFontSize(
                        context,
                        mobile: AppTheme.fontSizeH4,
                        tablet: AppTheme.fontSizeH3,
                        desktop: AppTheme.fontSizeH2,
                      ),
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
