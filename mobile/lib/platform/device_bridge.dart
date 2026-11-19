import 'package:flutter/services.dart';

class DeviceBridge {
  static const channel = MethodChannel('my.linkguard/device');
  Future<Map<String, dynamic>> status() async => Map<String, dynamic>.from(
    await channel.invokeMapMethod<String, dynamic>('status') ?? {},
  );
  Future<void> update(Map<String, dynamic> values) =>
      channel.invokeMethod<void>('update', values);
  Future<void> openAccess() => channel.invokeMethod<void>('openAccess');
  Future<bool> requestWarnings() async =>
      await channel.invokeMethod<bool>('requestWarnings') ?? false;
  Future<void> openAppSettings() =>
      channel.invokeMethod<void>('openAppSettings');
  Future<void> cleanupQrImages() async {
    try {
      await channel.invokeMethod<void>('cleanupQrImages');
    } on MissingPluginException {
      // No Android cache exists when running widget tests or unsupported platforms.
    }
  }

  Future<String?> consumeShare() =>
      channel.invokeMethod<String>('consumeShare');
}
