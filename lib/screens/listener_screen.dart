import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:keypress_simulator/keypress_simulator.dart';
import '../services/udp_service.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
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
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _startListening();
    _checkAccessPermissions();
  }

  Future<void> _checkAccessPermissions() async {
    // Only check on platforms that support keyboard simulation
    if (!Platform.isMacOS && !Platform.isWindows) return;

    // Only check if auto-type is enabled
    if (!_settings.autoTypeOnReceive) return;

    try {
      final hasAccess = await keyPressSimulator.isAccessAllowed();
      if (!hasAccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Accessibility permission required for auto-type feature. Tap to grant access.',
            ),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Grant',
              textColor: Colors.white,
              onPressed: () async {
                await keyPressSimulator.requestAccess();
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('Error checking accessibility permissions: $e');
    }
  }

  Future<void> _startListening() async {
    try {
      await _udpService.startListening();
      setState(() {
        _isListening = true;
      });

      _udpService.messageStream.listen((message) async {
        if (mounted) {
          // Play sound if enabled
          if (_settings.playSoundOnReceive) {
            _soundService.playPling();
          }

          // Auto-type if enabled
          if (_settings.autoTypeOnReceive) {
            try {
              await _typeText(message);
            } catch (e) {
              print('Auto-type failed: $e');
            }
          }

          setState(() {
            // Check if this code is already in the list
            final existingIndex = _scannedCodes.indexWhere(
              (c) => c.code == message,
            );
            if (existingIndex != -1) {
              // Update timestamp if already exists
              _scannedCodes[existingIndex] = ScannedCode(
                code: message,
                timestamp: DateTime.now(),
              );
            } else {
              // Add new code
              _scannedCodes.insert(
                0,
                ScannedCode(code: message, timestamp: DateTime.now()),
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
    try {
      // Type each character by simulating key presses
      for (int i = 0; i < text.length; i++) {
        final char = text[i];
        final key = _getKeyFromChar(char);
        if (key != null) {
          await keyPressSimulator.simulateKeyDown(key);
          await keyPressSimulator.simulateKeyUp(key);
          // Small delay between characters for reliability
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }

      // Press Enter after typing
      await keyPressSimulator.simulateKeyDown(PhysicalKeyboardKey.enter);
      await keyPressSimulator.simulateKeyUp(PhysicalKeyboardKey.enter);
    } catch (e) {
      print('Error typing text: $e');
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

  PhysicalKeyboardKey? _getKeyFromChar(String char) {
    // Map common characters to their physical keys
    switch (char.toLowerCase()) {
      case 'a':
        return PhysicalKeyboardKey.keyA;
      case 'b':
        return PhysicalKeyboardKey.keyB;
      case 'c':
        return PhysicalKeyboardKey.keyC;
      case 'd':
        return PhysicalKeyboardKey.keyD;
      case 'e':
        return PhysicalKeyboardKey.keyE;
      case 'f':
        return PhysicalKeyboardKey.keyF;
      case 'g':
        return PhysicalKeyboardKey.keyG;
      case 'h':
        return PhysicalKeyboardKey.keyH;
      case 'i':
        return PhysicalKeyboardKey.keyI;
      case 'j':
        return PhysicalKeyboardKey.keyJ;
      case 'k':
        return PhysicalKeyboardKey.keyK;
      case 'l':
        return PhysicalKeyboardKey.keyL;
      case 'm':
        return PhysicalKeyboardKey.keyM;
      case 'n':
        return PhysicalKeyboardKey.keyN;
      case 'o':
        return PhysicalKeyboardKey.keyO;
      case 'p':
        return PhysicalKeyboardKey.keyP;
      case 'q':
        return PhysicalKeyboardKey.keyQ;
      case 'r':
        return PhysicalKeyboardKey.keyR;
      case 's':
        return PhysicalKeyboardKey.keyS;
      case 't':
        return PhysicalKeyboardKey.keyT;
      case 'u':
        return PhysicalKeyboardKey.keyU;
      case 'v':
        return PhysicalKeyboardKey.keyV;
      case 'w':
        return PhysicalKeyboardKey.keyW;
      case 'x':
        return PhysicalKeyboardKey.keyX;
      case 'y':
        return PhysicalKeyboardKey.keyY;
      case 'z':
        return PhysicalKeyboardKey.keyZ;
      case '0':
        return PhysicalKeyboardKey.digit0;
      case '1':
        return PhysicalKeyboardKey.digit1;
      case '2':
        return PhysicalKeyboardKey.digit2;
      case '3':
        return PhysicalKeyboardKey.digit3;
      case '4':
        return PhysicalKeyboardKey.digit4;
      case '5':
        return PhysicalKeyboardKey.digit5;
      case '6':
        return PhysicalKeyboardKey.digit6;
      case '7':
        return PhysicalKeyboardKey.digit7;
      case '8':
        return PhysicalKeyboardKey.digit8;
      case '9':
        return PhysicalKeyboardKey.digit9;
      case ' ':
        return PhysicalKeyboardKey.space;
      case '.':
        return PhysicalKeyboardKey.period;
      case ',':
        return PhysicalKeyboardKey.comma;
      case '-':
        return PhysicalKeyboardKey.minus;
      case '/':
        return PhysicalKeyboardKey.slash;
      case ':':
        return PhysicalKeyboardKey.semicolon;
      case '\\':
        return PhysicalKeyboardKey.backslash;
      default:
        return null;
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
            padding: const EdgeInsets.all(16),
            color: _isListening ? Colors.green.shade100 : Colors.red.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isListening ? Icons.wifi : Icons.wifi_off,
                  color: _isListening ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  _isListening ? 'Listening for QR codes...' : 'Not listening',
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
                            style: const TextStyle(fontFamily: 'monospace'),
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
                            onPressed: () => _copyToClipboard(scannedCode.code),
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
