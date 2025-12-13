import 'package:flutter/material.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
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
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
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
  void reassemble() {
    super.reassemble();
    if (controller != null) {
      controller!.pauseCamera();
      controller!.resumeCamera();
    }
  }

  @override
  void dispose() {
    _udpService.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      final code = scanData.code;
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

      try {
        // Play sound if enabled
        if (_settings.playSoundOnScan) {
          _soundService.playPling();
        }

        await _udpService.sendBroadcast(code);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sent: $code'),
              duration: const Duration(seconds: 1),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
      body: Column(
        children: [
          Container(
            color: Colors.black87,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (lastScannedCode != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Last scanned: $lastScannedCode',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    const Text(
                      'Scan a QR code to send via network',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
              overlay: QrScannerOverlayShape(
                borderColor: Colors.blue,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 300,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
