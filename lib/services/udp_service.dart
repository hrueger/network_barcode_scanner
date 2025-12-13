import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:math' hide log;
import 'dart:developer';

class QrMessage {
  final String id;
  final String code;
  final int timestamp;

  QrMessage({required this.id, required this.code, required this.timestamp});

  factory QrMessage.fromJson(Map<String, dynamic> json) {
    return QrMessage(
      id: json['id'] as String,
      code: json['code'] as String,
      timestamp: json['timestamp'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'code': code, 'timestamp': timestamp};
  }
}

class UdpService {
  static const int port = 38765;
  RawDatagramSocket? _socket;
  final StreamController<QrMessage> _messageController =
      StreamController<QrMessage>.broadcast();

  Stream<QrMessage> get messageStream => _messageController.stream;

  Future<void> sendBroadcast(String message) async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      // Create QrMessage with unique ID
      final qrMessage = QrMessage(
        id: _generateUniqueId(),
        code: message,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      final jsonString = jsonEncode(qrMessage.toJson());
      final data = utf8.encode(jsonString);
      socket.send(data, InternetAddress('255.255.255.255'), port);

      await Future.delayed(const Duration(milliseconds: 100));
      socket.close();

      log('Sent broadcast: $jsonString');
    } catch (e) {
      log('Error sending broadcast: $e');
      rethrow;
    }
  }

  String _generateUniqueId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(999999);
    return '$timestamp-$randomPart';
  }

  Future<void> startListening() async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
      _socket!.broadcastEnabled = true;

      log('Listening on port $port');

      _socket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            try {
              final message = utf8.decode(datagram.data);
              log('Received: $message');
              // Parse as JSON and create QrMessage
              final jsonData = jsonDecode(message) as Map<String, dynamic>;
              final qrMessage = QrMessage.fromJson(jsonData);
              _messageController.add(qrMessage);
            } catch (e) {
              // If JSON parsing fails, ignore the message
              log('Failed to parse JSON, ignoring message: $e');
            }
          }
        }
      });
    } catch (e) {
      log('Error starting listener: $e');
      rethrow;
    }
  }

  void stopListening() {
    _socket?.close();
    _socket = null;
    log('Stopped listening');
  }

  void dispose() {
    stopListening();
    _messageController.close();
  }
}
