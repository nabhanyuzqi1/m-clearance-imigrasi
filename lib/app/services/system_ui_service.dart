import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SystemUiService {
  SystemUiService._();

  static final SystemUiService instance = SystemUiService._();

  static const MethodChannel _channel =
      MethodChannel('com.android.imigrasi/system_ui');

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> setSystemBarsAppearance({
    bool? lightStatusBars,
    bool? lightNavigationBars,
  }) async {
    if (!_isAndroid) {
      return;
    }

    final payload = <String, dynamic>{};
    if (lightStatusBars != null) {
      payload['lightStatusBars'] = lightStatusBars;
    }
    if (lightNavigationBars != null) {
      payload['lightNavigationBars'] = lightNavigationBars;
    }

    if (payload.isEmpty) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('setSystemBarsAppearance', payload);
    } on PlatformException catch (error) {
      debugPrint('[SystemUiService] Failed to set system bars appearance: $error');
    }
  }
}
