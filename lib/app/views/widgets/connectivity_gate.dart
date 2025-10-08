import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../localization/app_localizations.dart';
import '../../providers/connectivity_provider.dart';

class ConnectivityGate extends StatefulWidget {
  const ConnectivityGate({super.key, required this.child});

  final Widget child;

  @override
  State<ConnectivityGate> createState() => _ConnectivityGateState();
}

class _ConnectivityGateState extends State<ConnectivityGate> {
  bool _wasOffline = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConnectivityProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleConnectivityChange(provider);
    });
    return widget.child;
  }

  void _handleConnectivityChange(ConnectivityProvider provider) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final isOffline = provider.isInitialized && provider.isOnline == false;

    if (isOffline) {
      if (!_wasOffline) {
        final l10n = AppLocalizations.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    provider.isInitialized
                        ? l10n.get('connectivity.title')
                        : l10n.get('connectivity.checking'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(days: 1),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
        _wasOffline = true;
      }
    } else if (_wasOffline) {
      messenger.hideCurrentSnackBar();
      _wasOffline = false;
    }
  }
}
