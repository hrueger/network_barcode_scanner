import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:keypress_simulator/keypress_simulator.dart';
import 'package:bixat_key_mouse/bixat_key_mouse.dart';
import '../services/udp_service.dart';
import '../services/settings_service.dart';
import '../services/mac_keyboard_service.dart';
import '../services/sound_service.dart';
import 'auto_type_permission_view.dart';
import 'settings_screen.dart';

class ListenerScreen extends StatefulWidget {
  const ListenerScreen({super.key});

  @override
  State<ListenerScreen> createState() => _ListenerScreenState();
}

class _ListenerScreenState extends State<ListenerScreen> {
  final UdpService _udpService = UdpService();
  final SettingsService _settings = SettingsService();
  final SoundService _soundService = SoundService();
  final List<ScannedCode> _scannedCodes = [];
  final Set<String> _seenMessageIds = {};

  /// When each code was last accepted, so the same code arriving again within
  /// [_echoWindow] is dropped even if it carries a fresh message id (a second
  /// device scanning the same label, or a scanner engine firing twice).
  final Map<String, DateTime> _lastAcceptedAt = {};
  static const Duration _echoWindow = Duration(milliseconds: 1500);

  /// Typing runs strictly one code after another. The stream callback is
  /// async, so without this two arrivals would type interleaved keystrokes.
  Future<void> _typeQueue = Future.value();
  bool _isListening = false;

  final MacKeyboardService _macKeyboard = MacKeyboardService();

  /// Only ever false on macOS, until the app may post keystrokes
  bool _canType = true;

  @override
  void initState() {
    super.initState();
    _startListening();
    _initTyping();
  }

  Future<void> _initTyping() async {
    if (Platform.isMacOS) {
      await _refreshCanType();
    } else if (Platform.isLinux || Platform.isWindows) {
      await BixatKeyMouse.initialize();
    }
  }

  Future<void> _refreshCanType() async {
    if (!Platform.isMacOS) return;
    try {
      final canType = await _macKeyboard.canPostEvents();
      if (mounted) setState(() => _canType = canType);
    } catch (e) {
      log('Error checking keystroke permission: $e');
    }
  }

  bool get _needsPermission => _settings.autoTypeOnReceive && !_canType;

  Future<void> _disableAutoType() async {
    await _settings.setAutoTypeOnReceive(false);
    if (mounted) setState(() {});
  }

  Future<void> _startListening() async {
    try {
      await _udpService.startListening();
      setState(() {
        _isListening = true;
      });

      _udpService.messageStream.listen((qrMessage) async {
        if (mounted) {
          // Ignore if we've already seen this message ID
          if (_seenMessageIds.contains(qrMessage.id)) {
            log('Ignoring duplicate message ID: ${qrMessage.id}');
            return;
          }

          // Add to seen IDs
          _seenMessageIds.add(qrMessage.id);

          // Drop echoes of a code accepted a moment ago
          final now = DateTime.now();
          final lastAccepted = _lastAcceptedAt[qrMessage.code];
          if (lastAccepted != null &&
              now.difference(lastAccepted) < _echoWindow) {
            log('Ignoring echo of code within echo window: ${qrMessage.code}');
            return;
          }
          _lastAcceptedAt[qrMessage.code] = now;

          // Play sound if enabled
          if (_settings.playSoundOnReceive) {
            _soundService.playPling();
          }

          // Auto-type if enabled, one code at a time
          if (_settings.autoTypeOnReceive) {
            _typeQueue = _typeQueue.then((_) => _typeText(qrMessage.code));
            try {
              await _typeQueue;
            } catch (e) {
              log('Auto-type failed: $e');
            }
          }

          setState(() {
            // Check if this code is already in the list
            final existingIndex = _scannedCodes.indexWhere(
              (c) => c.code == qrMessage.code,
            );
            if (existingIndex != -1) {
              // Update timestamp if already exists
              _scannedCodes[existingIndex] = ScannedCode(
                code: qrMessage.code,
                timestamp: DateTime.now(),
              );
            } else {
              // Add new code
              _scannedCodes.insert(
                0,
                ScannedCode(code: qrMessage.code, timestamp: DateTime.now()),
              );
            }
          });
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting listener: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _typeText(String text) async {
    log("🎉 Typing text: $text");
    try {
      final endKeyType = _settings.autoTypeEndKey;

      if (Platform.isMacOS) {
        await _macKeyboard.typeText(text);
        if (endKeyType != 'none') await _macKeyboard.pressKey(endKeyType);
        return;
      }

      // enigo posts the text as a Unicode string, so case and symbols come out
      // right whatever keyboard layout is active. Mapping characters to
      // physical keys assumed a US layout and dropped the case.
      BixatKeyMouse.enterText(text: text);

      // Press configured end key after typing
      if (endKeyType != 'none') {
        if (Platform.isLinux) {
          if (endKeyType == 'tab') {
            BixatKeyMouse.simulateKey(key: UniversalKey.tab);
          } else {
            BixatKeyMouse.enterText(text: "\n");
          }
        } else {
          // Tab and Enter sit on the same physical key on every layout
          final endKey = endKeyType == 'tab'
              ? PhysicalKeyboardKey.tab
              : PhysicalKeyboardKey.enter;
          await keyPressSimulator.simulateKeyDown(endKey);
          await keyPressSimulator.simulateKeyUp(endKey);
        }
      }
    } catch (e) {
      log('Error typing text: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-type failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _udpService.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _clearAll() {
    setState(() {
      _scannedCodes.clear();
    });
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listener'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_scannedCodes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearAll,
              tooltip: 'Clear all',
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              // Auto-type may have just been switched on or off
              await _refreshCanType();
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _needsPermission
          ? AutoTypePermissionView(
              keyboard: _macKeyboard,
              onDisableAutoType: _disableAutoType,
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: _isListening
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isListening ? Icons.wifi : Icons.wifi_off,
                        color: _isListening ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isListening
                            ? 'Listening for QR codes...'
                            : 'Not listening',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isListening
                              ? Colors.green.shade900
                              : Colors.red.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _scannedCodes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.qr_code_2,
                                size: 80,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No codes received yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Waiting for scanner broadcasts...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _scannedCodes.length,
                          itemBuilder: (context, index) {
                            final scannedCode = _scannedCodes[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.qr_code_2),
                                ),
                                title: Text(
                                  scannedCode.code,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                subtitle: Text(
                                  _formatTimestamp(scannedCode.timestamp),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () =>
                                      _copyToClipboard(scannedCode.code),
                                  tooltip: 'Copy',
                                ),
                                onTap: () => _copyToClipboard(scannedCode.code),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class ScannedCode {
  final String code;
  final DateTime timestamp;

  ScannedCode({required this.code, required this.timestamp});
}
