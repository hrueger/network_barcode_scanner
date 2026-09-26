import 'package:flutter/services.dart';

/// Auto-type on macOS, backed by MainFlutterWindow.swift. The only grant it
/// needs is PostEvent, which macOS applies after a relaunch.
class MacKeyboardService {
  static const _channel = MethodChannel('network_barcode_scanner/keyboard');

  Future<bool> canPostEvents() async =>
      await _channel.invokeMethod<bool>('canPostEvents') ?? false;

  /// Shows the system prompt the first time; afterwards macOS stays silent.
  Future<void> requestPostEvents() =>
      _channel.invokeMethod('requestPostEvents');

  Future<void> openSettings() => _channel.invokeMethod('openSettings');

  Future<void> relaunch() => _channel.invokeMethod('relaunch');

  Future<void> typeText(String text) => _channel.invokeMethod('typeText', text);

  /// [key] is 'tab' or 'enter'.
  Future<void> pressKey(String key) => _channel.invokeMethod('pressKey', key);
}
