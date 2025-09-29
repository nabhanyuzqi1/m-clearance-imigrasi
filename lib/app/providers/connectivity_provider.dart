import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityProvider extends ChangeNotifier {
  ConnectivityProvider({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity() {
    _initialize();
  }

  final Connectivity _connectivity;
  StreamSubscription<dynamic>? _subscription;
  bool _isOnline = true;
  bool _isInitialized = false;

  bool get isOnline => _isOnline;
  bool get isInitialized => _isInitialized;

  Future<void> manualCheck() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateStatusFrom(result);
    } catch (_) {
      _setStatus(false);
    }
  }

  Future<void> _initialize() async {
    await manualCheck();
    _subscription = _connectivity.onConnectivityChanged.listen((
      dynamic status,
    ) {
      _updateStatusFrom(status);
    }, onError: (_) => _setStatus(false));
  }

  void _updateStatusFrom(dynamic status) {
    bool hasConnection = true;
    if (status is ConnectivityResult) {
      hasConnection = status != ConnectivityResult.none;
    } else if (status is List<ConnectivityResult>) {
      hasConnection =
          status.isNotEmpty &&
          status.any((res) => res != ConnectivityResult.none);
    }
    _setStatus(hasConnection);
  }

  void _setStatus(bool online) {
    if (_isOnline != online || !_isInitialized) {
      _isOnline = online;
      _isInitialized = true;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
