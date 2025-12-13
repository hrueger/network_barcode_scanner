import 'dart:io';
import 'dart:convert';
import 'dart:async';

class UdpService {
  static const int port = 38765;
  RawDatagramSocket? _socket;
  final StreamController<String> _messageController =
      StreamController<String>.broadcast();

  Stream<String> get messageStream => _messageController.stream;

  Future<void> sendBroadcast(String message) async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final data = utf8.encode(message);
      socket.send(data, InternetAddress('255.255.255.255'), port);

      await Future.delayed(const Duration(milliseconds: 100));
      socket.close();

      print('Sent broadcast: $message');
    } catch (e) {
      print('Error sending broadcast: $e');
      rethrow;
    }
  }

  Future<void> startListening() async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
      _socket!.broadcastEnabled = true;

      print('Listening on port $port');

      _socket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            final message = utf8.decode(datagram.data);
            print('Received: $message');
            _messageController.add(message);
          }
        }
      });
    } catch (e) {
      print('Error starting listener: $e');
      rethrow;
    }
  }

  void stopListening() {
    _socket?.close();
    _socket = null;
    print('Stopped listening');
  }

  void dispose() {
    stopListening();
    _messageController.close();
  }
}
