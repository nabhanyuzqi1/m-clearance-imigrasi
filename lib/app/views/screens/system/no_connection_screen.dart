import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../localization/app_localizations.dart';
import '../../../providers/connectivity_provider.dart';
import '../../widgets/bouncing_dots_loader.dart';

class NoConnectionScreen extends StatefulWidget {
  const NoConnectionScreen({super.key});

  @override
  State<NoConnectionScreen> createState() => _NoConnectionScreenState();
}

class _NoConnectionScreenState extends State<NoConnectionScreen> {
  bool _isChecking = false;

  Future<void> _retry() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    try {
      await context.read<ConnectivityProvider>().manualCheck();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Material(
      color: AppTheme.backgroundColor,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 96,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.get('connectivity.title'),
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(
                    color: AppTheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.get('connectivity.message'),
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppTheme.subtitleColor,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isChecking ? null : _retry,
                    icon: _isChecking
                        ? const BouncingDotsLoader()
                        : const Icon(Icons.refresh_rounded),
                    label: Text(
                      _isChecking
                          ? l10n.get('connectivity.checking')
                          : l10n.get('connectivity.retry'),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
