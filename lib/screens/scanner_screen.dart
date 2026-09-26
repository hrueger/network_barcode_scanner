import 'dart:async';
import 'dart:developer';
import 'dart:math' show max;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/hardware_scanner_service.dart';
import '../services/udp_service.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import 'settings_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final UdpService _udpService = UdpService();
  final SettingsService _settings = SettingsService();
  final SoundService _soundService = SoundService();
  final HardwareScannerService _hardware = HardwareScannerService();

  /// Only created while the camera is the active input.
  MobileScannerController? _controller;
  StreamSubscription<String>? _hardwareSubscription;

  /// Null until the input has been resolved for this device.
  bool? _useHardware;
  DeviceIdentity? _device;

  String? lastScannedCode;
  DateTime? lastScannedTime;
  final Set<String> _scannedCodesHistory = {};

  @override
  void initState() {
    super.initState();
    _udpService.startDiscovery();
    _resolveInput();
  }

  /// Decide between the hardware trigger and the camera, then start it.
  ///
  /// Android has no API that says "this device has a scan engine", so auto
  /// mode leans on two signals: the model is a known PDA, or this device has
  /// already delivered a hardware scan once.
  Future<void> _resolveInput() async {
    _device ??= await _hardware.deviceInfo();
    final useHardware = switch (ScanInputMode.parse(_settings.scanInputMode)) {
      ScanInputMode.hardware => HardwareScannerService.isSupported,
      ScanInputMode.camera => false,
      ScanInputMode.auto =>
        HardwareScannerService.isSupported &&
            ((_device?.isKnownPda ?? false) || _settings.hardwareScanSeen),
    };
    if (!mounted) return;
    await _startInput(useHardware);
  }

  Future<void> _startInput(bool useHardware) async {
    await _stopInput();
    if (useHardware) {
      await _hardware.configure(
        action: _settings.scanBroadcastAction,
        extraKey: _settings.scanBroadcastExtra,
      );
      _hardwareSubscription = _hardware.scans.listen(
        (code) => _onCode(code, fromHardware: true),
        onError: (error) => log('Hardware scanner error: $error'),
      );
    } else {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
      );
      await _requestCameraPermission();
    }
    if (mounted) setState(() => _useHardware = useHardware);
  }

  Future<void> _stopInput() async {
    await _hardwareSubscription?.cancel();
    _hardwareSubscription = null;
    await _hardware.stop();
    await _controller?.dispose();
    _controller = null;
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is required')),
        );
      }
    }
  }

  @override
  void dispose() {
    _stopInput();
    _udpService.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;
    _onCode(code);
  }

  /// The single path every decoded code takes, whichever input produced it.
  void _onCode(String code, {bool fromHardware = false}) {
    if (code.isEmpty) return;

    if (fromHardware && !_settings.hardwareScanSeen) {
      _settings.setHardwareScanSeen(true);
    }

    // Check if we should ignore this code based on settings
    if (_settings.ignoreSeenCodes && _scannedCodesHistory.contains(code)) {
      // Silently ignore - code was already scanned
      return;
    }

    // Check duplicate wait time. Never below half a second: a scan engine can
    // fire twice per trigger pull, and the camera re-reads every frame.
    if (code == lastScannedCode) {
      if (lastScannedTime != null) {
        final timeSinceLastScan = DateTime.now().difference(lastScannedTime!);
        final waitTime = Duration(
          milliseconds: max(_settings.duplicateWaitTime * 1000, 500),
        );
        if (timeSinceLastScan < waitTime) {
          // Still within wait period
          return;
        }
      }
    }

    setState(() {
      lastScannedCode = code;
      lastScannedTime = DateTime.now();
    });

    // Add to history if ignore seen codes is enabled
    if (_settings.ignoreSeenCodes) {
      _scannedCodesHistory.add(code);
    }

    // Play sound if enabled
    if (_settings.playSoundOnScan) {
      _soundService.playPling();
    }
    log("✅ sending code: $code");
    _udpService
        .sendBroadcast(code)
        .then((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              statusSnackBar(
                context,
                'Sent: $code',
                Status.success,
                duration: const Duration(seconds: 1),
              ),
            );
          }
        })
        .catchError((error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              statusSnackBar(
                context,
                'Failed to send: $error',
                Status.danger,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        });
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
    // The input mode or broadcast config may have changed.
    if (mounted) await _resolveInput();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildListenersBar(),
          Expanded(
            child: switch (_useHardware) {
              null => const Center(child: CircularProgressIndicator()),
              true => _buildHardwareBody(context),
              false => _buildCameraBody(context),
            },
          ),
        ],
      ),
    );
  }

  /// Shows who receives the scans. Without any listener found, codes only go
  /// out as a broadcast, which sandboxed macOS listeners never receive.
  Widget _buildListenersBar() {
    return ValueListenableBuilder<List<String>>(
      valueListenable: _udpService.listenerNames,
      builder: (context, names, _) {
        final found = names.isNotEmpty;
        return StatusBanner(
          status: found ? Status.success : Status.warning,
          icon: found ? Icons.computer : Icons.warning_amber,
          text: found
              ? 'Sending to: ${names.join(', ')}'
              : 'No listeners found – broadcast only',
        );
      },
    );
  }

  Widget _buildHardwareBody(BuildContext context) {
    final theme = Theme.of(context);
    final deviceLabel = _device?.label;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_scanner,
              size: 96,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text('Ready to scan', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              deviceLabel == null
                  ? 'Press the scan trigger'
                  : 'Press the scan trigger on your $deviceLabel',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            if (lastScannedCode != null) ...[
              Text('Last scanned', style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              SelectableText(
                lastScannedCode!,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCameraBody(BuildContext context) {
    final controller = _controller!;
    final scanWindow = Rect.fromCenter(
      center: MediaQuery.sizeOf(context).center(const Offset(0, -100)),
      width: 300,
      height: 200,
    );
    return Stack(
      children: [
        MobileScanner(
          controller: controller,
          onDetect: _handleBarcode,
          scanWindow: scanWindow,
          tapToFocus: true,
        ),
        IgnorePointer(
          child: BarcodeOverlay(controller: controller, boxFit: BoxFit.cover),
        ),
        IgnorePointer(
          child: ScanWindowOverlay(
            scanWindow: scanWindow,
            controller: controller,
          ),
        ),
      ],
    );
  }
}
