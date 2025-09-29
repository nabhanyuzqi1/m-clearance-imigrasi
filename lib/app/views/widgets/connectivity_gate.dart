import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/connectivity_provider.dart';
import '../screens/system/no_connection_screen.dart';

class ConnectivityGate extends StatelessWidget {
  const ConnectivityGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityProvider>();
    final showOverlay =
        connectivity.isInitialized && connectivity.isOnline == false;

    if (!showOverlay) {
      return child;
    }

    return Stack(
      children: [
        Positioned.fill(child: child),
        const Positioned.fill(child: NoConnectionScreen()),
      ],
    );
  }
}
