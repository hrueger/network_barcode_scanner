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

/// Canned state for the store screenshots. With it the scanner shows these
/// values and starts no camera, scan engine or network discovery.
class ScannerPreview {
  final List<String> listeners;
  final String? lastScannedCode;

  /// Shows the handheld screen for this device; null shows the camera.
  final String? handheld;

  /// Stands in for the camera image.
  final Widget? cameraBackdrop;

  const ScannerPreview({
    this.listeners = const [],
    this.lastScannedCode,
    this.handheld,
    this.cameraBackdrop,
  });
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key, @visibleForTesting this.preview});

  final ScannerPreview? preview;

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

  /// Restarts the camera when the user comes back from granting access in
  /// the system settings.
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    final preview = widget.preview;
    if (preview != null) {
      _udpService.listenerNames.value = preview.listeners;
      lastScannedCode = preview.lastScannedCode;
      _useHardware = preview.handheld != null;
      if (preview.handheld != null) {
        _device = DeviceIdentity(
          manufacturer: '',
          brand: '',
          model: preview.handheld!,
        );
      }
      return;
    }
    _udpService.startDiscovery();
    _lifecycle = AppLifecycleListener(onResume: _retryCameraAfterPermission);
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
      // The scanner asks for camera access itself once its widget is built.
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
      );
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

  /// Once Android stops showing the permission dialog, only the system
  /// settings can grant camera access.
  Future<void> _retryCamera(MobileScannerException error) async {
    if (error.errorCode == MobileScannerErrorCode.permissionDenied &&
        await Permission.camera.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }
    await _controller?.start();
  }

  Future<void> _retryCameraAfterPermission() async {
    final controller = _controller;
    if (controller?.value.error?.errorCode !=
        MobileScannerErrorCode.permissionDenied) {
      return;
    }
    if (await Permission.camera.isGranted) await controller?.start();
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    if (widget.preview == null) _stopInput();
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
    final scanWindow = Rect.fromCenter(
      center: MediaQuery.sizeOf(context).center(const Offset(0, -100)),
      width: 300,
      height: 200,
    );
    final preview = widget.preview;
    if (preview != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          preview.cameraBackdrop ?? const ColoredBox(color: Colors.black),
          CustomPaint(painter: _ScanWindowPainter(scanWindow)),
        ],
      );
    }
    final controller = _controller!;
    return Stack(
      children: [
        MobileScanner(
          controller: controller,
          onDetect: _handleBarcode,
          scanWindow: scanWindow,
          tapToFocus: true,
          placeholderBuilder: (context) => const ColoredBox(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator()),
          ),
          errorBuilder: (context, error) =>
              CameraErrorView(error: error, onRetry: () => _retryCamera(error)),
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

/// Says why the camera could not start and offers the fix. mobile_scanner's
/// own error widget shows "An unexpected error occurred." for every cause in
/// release builds.
class CameraErrorView extends StatelessWidget {
  final MobileScannerException error;
  final VoidCallback onRetry;

  const CameraErrorView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, title, detail, action) = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied => (
        Icons.no_photography_outlined,
        'Camera access needed',
        'Allow camera access to scan barcodes.',
        'Allow camera',
      ),
      MobileScannerErrorCode.unsupported => (
        Icons.videocam_off_outlined,
        'No camera found',
        HardwareScannerService.isSupported
            ? 'This device has no camera to scan with. On a handheld '
                  'scanner, pick "Hardware trigger" under Settings > Scan '
                  'Input.'
            : 'This device has no camera to scan with.',
        null,
      ),
      _ => (
        Icons.error_outline,
        'Camera could not start',
        error.errorDetails?.message ??
            'Close other apps that use the camera and try again.',
        'Try again',
      ),
    };
    final theme = Theme.of(context);
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: 24),
                FilledButton(onPressed: onRetry, child: Text(action)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The camera overlay for screenshots: dims everything outside the scan
/// window, like mobile_scanner's ScanWindowOverlay, which needs a live camera.
class _ScanWindowPainter extends CustomPainter {
  final Rect window;

  const _ScanWindowPainter(this.window);

  @override
  void paint(Canvas canvas, Size size) {
    final rounded = RRect.fromRectAndRadius(window, const Radius.circular(12));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(rounded),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );
    canvas.drawRRect(
      rounded,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_ScanWindowPainter old) => old.window != window;
}
