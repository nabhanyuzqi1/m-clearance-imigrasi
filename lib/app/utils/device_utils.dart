import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:crypto/crypto.dart' as crypto;

class DeviceIdentity {
  const DeviceIdentity({
    required this.fingerprint,
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.osVersion,
    required this.locale,
    required this.brand,
    required this.model,
    required this.isPhysicalDevice,
    required this.timestamp,
  });

  final String fingerprint;
  final String deviceId;
  final String deviceName;
  final String platform;
  final String osVersion;
  final String locale;
  final String brand;
  final String model;
  final bool isPhysicalDevice;
  final String timestamp;

  Map<String, dynamic> toMap() {
    return {
      'fingerprint': fingerprint,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'platform': platform,
      'osVersion': osVersion,
      'locale': locale,
      'brand': brand,
      'model': model,
      'isPhysicalDevice': isPhysicalDevice,
      'timestamp': timestamp,
    };
  }
}

class DeviceUtils {
  const DeviceUtils._();

  static Future<DeviceIdentity> resolveIdentity() async {
    final deviceInfo = DeviceInfoPlugin();
    final now = DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'")
        .format(DateTime.now().toUtc());
    final locale = Intl.getCurrentLocale();

    if (kIsWeb) {
      final webInfo = await deviceInfo.webBrowserInfo;
      final rawId = '${webInfo.vendor ?? 'browser'}|'
          '${webInfo.userAgent ?? ''}|${webInfo.hardwareConcurrency ?? 0}';
      return DeviceIdentity(
        fingerprint: _hash(rawId),
        deviceId: _hash(rawId),
        deviceName: webInfo.vendor ?? 'Web Browser',
        platform: 'web',
        osVersion: webInfo.appVersion ?? 'unknown',
        locale: locale,
        brand: webInfo.vendor ?? 'Browser',
        model: webInfo.browserName.name,
        isPhysicalDevice: true,
        timestamp: now,
      );
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final android = await deviceInfo.androidInfo;
      final rawId = '${android.id}|${android.brand}|${android.model}|'
          '${android.hardware}|${android.version.sdkInt}';
      final name = android.device.isNotEmpty
          ? android.device
          : android.model.isNotEmpty
              ? android.model
              : 'Android Device';
      return DeviceIdentity(
        fingerprint: _hash(rawId),
        deviceId: android.id,
        deviceName: name,
        platform: 'android',
        osVersion: 'Android ${android.version.release}',
        locale: locale,
        brand: android.brand,
        model: android.model,
        isPhysicalDevice: android.isPhysicalDevice,
        timestamp: now,
      );
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = await deviceInfo.iosInfo;
      final rawId = '${ios.identifierForVendor}|${ios.name}|${ios.model}';
      final name = ios.name.isNotEmpty
          ? ios.name
          : (ios.model.isNotEmpty ? ios.model : 'iOS Device');
      return DeviceIdentity(
        fingerprint: _hash(rawId),
        deviceId: ios.identifierForVendor ?? _hash(rawId),
        deviceName: name,
        platform: 'ios',
        osVersion: '${ios.systemName} ${ios.systemVersion}',
        locale: locale,
        brand: 'Apple',
        model: ios.model,
        isPhysicalDevice: ios.isPhysicalDevice,
        timestamp: now,
      );
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      final mac = await deviceInfo.macOsInfo;
      final rawId = '${mac.systemGUID}|${mac.computerName}|${mac.model}';
      final name = mac.computerName.isNotEmpty
          ? mac.computerName
          : 'macOS Device';
      final macModel = mac.model.isNotEmpty ? mac.model : 'Mac';
      return DeviceIdentity(
        fingerprint: _hash(rawId),
        deviceId: mac.systemGUID ?? _hash(rawId),
        deviceName: name,
        platform: 'macos',
        osVersion: mac.osRelease,
        locale: locale,
        brand: 'Apple',
        model: macModel,
        isPhysicalDevice: true,
        timestamp: now,
      );
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      final windows = await deviceInfo.windowsInfo;
      final rawId = '${windows.deviceId}|${windows.computerName}|'
          '${windows.numberOfCores}';
      return DeviceIdentity(
        fingerprint: _hash(rawId),
        deviceId: windows.deviceId,
        deviceName: windows.computerName,
        platform: 'windows',
        osVersion: windows.productName,
        locale: locale,
        brand: 'Microsoft',
        model: windows.productName,
        isPhysicalDevice: true,
        timestamp: now,
      );
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
      final linux = await deviceInfo.linuxInfo;
      final rawId = '${linux.machineId}|${linux.name}|${linux.versionCodename}';
      final deviceName = linux.prettyName.isNotEmpty
          ? linux.prettyName
          : 'Linux Device';
      final version = linux.version?.isNotEmpty == true
          ? linux.version!
          : 'Linux';
      final variant = linux.variant?.isNotEmpty == true
          ? linux.variant!
          : 'Linux';
      final machineId = (linux.machineId?.isNotEmpty ?? false)
          ? linux.machineId!
          : _hash(rawId);
      return DeviceIdentity(
        fingerprint: _hash(rawId),
        deviceId: machineId,
        deviceName: deviceName,
        platform: 'linux',
        osVersion: version,
        locale: locale,
        brand: linux.id.isNotEmpty ? linux.id : 'Linux',
        model: variant,
        isPhysicalDevice: true,
        timestamp: now,
      );
    }

    final fallbackId = 'unknown|$locale';
    return DeviceIdentity(
      fingerprint: _hash(fallbackId),
      deviceId: _hash(fallbackId),
      deviceName: 'Unknown Device',
      platform: 'unknown',
      osVersion: 'unknown',
      locale: locale,
      brand: 'unknown',
      model: 'unknown',
      isPhysicalDevice: true,
      timestamp: now,
    );
  }

  static String _hash(String input) {
    final digest = crypto.sha256.convert(utf8.encode(input));
    return base64Url.encode(digest.bytes);
  }
}
