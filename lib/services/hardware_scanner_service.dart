import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// How the scanner screen gets its codes.
enum ScanInputMode {
  /// Hardware trigger on a known PDA, camera everywhere else.
  auto,

  /// Only the device's built-in scan engine (broadcast Intents).
  hardware,

  /// Only the camera.
  camera;

  static ScanInputMode parse(String? name) =>
      ScanInputMode.values.where((m) => m.name == name).firstOrNull ??
      ScanInputMode.auto;
}

/// What an Android device calls itself, from `Build`.
class DeviceIdentity {
  const DeviceIdentity({
    required this.manufacturer,
    required this.brand,
    required this.model,
  });

  final String manufacturer;
  final String brand;
  final String model;

  /// Handhelds known to ship a hardware scan engine that emits broadcasts.
  ///
  /// The Chainway C90 is matched by model as well as by maker because
  /// resellers (e.g. Munbyn) rebrand it and only the model string survives.
  bool get isKnownPda {
    final maker = '$manufacturer $brand'.toLowerCase();
    if (maker.contains('chainway') || maker.contains('sunmi')) return true;
    return model.toLowerCase().contains('c90');
  }

  /// Human-readable name, e.g. "Chainway C90". Vendors often report the
  /// manufacturer in lowercase.
  String get label {
    final name = model.trim();
    final maker = manufacturer.trim();
    if (maker.isEmpty) return name;
    if (name.toLowerCase().startsWith(maker.toLowerCase())) return name;
    final capitalized = maker[0].toUpperCase() + maker.substring(1);
    return '$capitalized $name'.trim();
  }
}

/// Talks to the Kotlin BroadcastReceiver that listens for the PDA's scan
/// engine. Android only; every call is a no-op elsewhere.
class HardwareScannerService {
  static final HardwareScannerService _instance =
      HardwareScannerService._internal();
  factory HardwareScannerService() => _instance;
  HardwareScannerService._internal();

  static const _method = MethodChannel('network_barcode_scanner/scanner');
  static const _scans = EventChannel('network_barcode_scanner/scanner/scans');

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  StreamController<String>? _controller;
  StreamSubscription<dynamic>? _platformSubscription;
  DeviceIdentity? _device;

  /// Decoded barcodes from the hardware trigger.
  ///
  /// The platform stream is subscribed once and kept: `receiveBroadcastStream`
  /// re-fires onListen/onCancel per subscriber, so per-screen subscriptions
  /// would clobber each other's sink.
  Stream<String> get scans {
    if (!isSupported) return const Stream<String>.empty();
    final controller = _controller ??= StreamController<String>.broadcast();
    _platformSubscription ??= _scans.receiveBroadcastStream().listen(
      (event) => controller.add(event as String),
      onError: controller.addError,
    );
    return controller.stream;
  }

  /// Register the receiver for [action], reading the code from [extraKey].
  Future<void> configure({
    required String action,
    required String extraKey,
  }) async {
    if (!isSupported) return;
    await _method.invokeMethod<void>('configure', {
      'actions': [action],
      'extraKeys': [extraKey],
    });
  }

  Future<void> stop() async {
    if (!isSupported) return;
    await _method.invokeMethod<void>('stop');
  }

  /// Cached after the first call. Null wherever there is no bridge to ask.
  Future<DeviceIdentity?> deviceInfo() async {
    if (!isSupported) return null;
    if (_device != null) return _device;
    final map = await _method.invokeMapMethod<String, String>('deviceInfo');
    if (map == null) return null;
    return _device = DeviceIdentity(
      manufacturer: map['manufacturer'] ?? '',
      brand: map['brand'] ?? '',
      model: map['model'] ?? '',
    );
  }
}
