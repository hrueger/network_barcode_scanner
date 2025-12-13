import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
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
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );
  final UdpService _udpService = UdpService();
  final SettingsService _settings = SettingsService();
  final SoundService _soundService = SoundService();
  String? lastScannedCode;
  DateTime? lastScannedTime;
  final Set<String> _scannedCodesHistory = {};

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
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
    controller.dispose();
    _udpService.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    // Check if we should ignore this code based on settings
    if (_settings.ignoreSeenCodes && _scannedCodesHistory.contains(code)) {
      // Silently ignore - code was already scanned
      return;
    }

    // Check duplicate wait time
    if (code == lastScannedCode) {
      if (lastScannedTime != null) {
        final timeSinceLastScan = DateTime.now().difference(lastScannedTime!);
        final waitTime = Duration(seconds: _settings.duplicateWaitTime);
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
              SnackBar(
                content: Text('Sent: $code'),
                duration: const Duration(seconds: 1),
                backgroundColor: Colors.green,
              ),
            );
          }
        })
        .catchError((error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to send: $error'),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    late final scanWindow = Rect.fromCenter(
      center: MediaQuery.sizeOf(context).center(const Offset(0, -100)),
      width: 300,
      height: 200,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Scanner'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Stack(
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
      ),
    );
  }
}
