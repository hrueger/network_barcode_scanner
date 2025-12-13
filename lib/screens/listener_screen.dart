import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/udp_service.dart';

class ListenerScreen extends StatefulWidget {
  const ListenerScreen({super.key});

  @override
  State<ListenerScreen> createState() => _ListenerScreenState();
}

class _ListenerScreenState extends State<ListenerScreen> {
  final UdpService _udpService = UdpService();
  final List<ScannedCode> _scannedCodes = [];
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  Future<void> _startListening() async {
    try {
      await _udpService.startListening();
      setState(() {
        _isListening = true;
      });

      _udpService.messageStream.listen((message) {
        if (mounted) {
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
