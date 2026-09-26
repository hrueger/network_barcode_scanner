import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:math' hide log;
import 'dart:developer';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';

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

/// Scanners find listeners over Bonjour and send each code to every one of
/// them by unicast. The broadcast to 255.255.255.255 stays as a fallback for
/// older app versions, but a sandboxed macOS app never receives it, and iOS
/// may only send it with Apple's multicast entitlement.
class UdpService {
  static const int port = 38765;
  static const String serviceType = '_barcodescan._udp';
  RawDatagramSocket? _socket;
  BonsoirBroadcast? _advertisement;
  BonsoirDiscovery? _discovery;

  /// Resolved listeners by Bonjour service name
  final Map<String, List<InternetAddress>> _listeners = {};

  /// Names of the listeners codes currently go to, for the scanner UI
  final ValueNotifier<List<String>> listenerNames = ValueNotifier([]);

  void _publishListeners() {
    listenerNames.value = _listeners.keys.toList()..sort();
  }

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

      // Listeners drop the copies by message id
      final targets = {
        for (final addresses in _listeners.values) ...addresses,
        InternetAddress('255.255.255.255'),
      };
      for (final target in targets) {
        socket.send(data, target, port);
      }

      await Future.delayed(const Duration(milliseconds: 100));
      socket.close();

      log('Sent to ${targets.map((t) => t.address).join(', ')}: $jsonString');
    } catch (e) {
      log('Error sending broadcast: $e');
      rethrow;
    }
  }

  /// Scanner side: keeps [_listeners] current for [sendBroadcast].
  Future<void> startDiscovery() async {
    try {
      final discovery = BonsoirDiscovery(type: serviceType);
      _discovery = discovery;
      await discovery.initialize();
      discovery.eventStream!.listen((event) async {
        switch (event) {
          case BonsoirDiscoveryServiceFoundEvent():
            await discovery.serviceResolver.resolveService(event.service);
          case BonsoirDiscoveryServiceResolvedEvent():
          case BonsoirDiscoveryServiceUpdatedEvent():
            final service = event.service!;
            final addresses = await _ipv4Addresses(service);
            if (addresses.isNotEmpty) _listeners[service.name] = addresses;
            _publishListeners();
            log('Listener ${service.name}: ${addresses.map((a) => a.address)}');
          case BonsoirDiscoveryServiceLostEvent():
            _listeners.remove(event.service.name);
            _publishListeners();
            log('Listener lost: ${event.service.name}');
          default:
            break;
        }
      });
      await discovery.start();
    } catch (e) {
      // Broadcast still works without discovery
      log('Error starting discovery: $e');
    }
  }

  /// The send socket is IPv4 only. Platforms report addresses, a `.local`
  /// hostname or both, so fall back to looking the hostname up.
  Future<List<InternetAddress>> _ipv4Addresses(BonsoirService service) async {
    final addresses = service.hostAddresses
        .map(InternetAddress.tryParse)
        .whereType<InternetAddress>()
        .where((a) => a.type == InternetAddressType.IPv4)
        .toList();
    final hostname = service.hostname;
    if (addresses.isNotEmpty || hostname == null) return addresses;
    try {
      return await InternetAddress.lookup(
        hostname,
        type: InternetAddressType.IPv4,
      );
    } catch (e) {
      log('Could not resolve $hostname: $e');
      return [];
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
      await _advertise();

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

  /// Listener side: lets scanners find this device.
  Future<void> _advertise() async {
    try {
      final advertisement = BonsoirBroadcast(
        service: BonsoirService(
          name: Platform.localHostname.split('.').first,
          type: serviceType,
          port: port,
        ),
      );
      _advertisement = advertisement;
      await advertisement.initialize();
      await advertisement.start();
    } catch (e) {
      // Scanners still reach this listener by broadcast where it gets through
      log('Error advertising listener: $e');
    }
  }

  void stopListening() {
    _advertisement?.stop();
    _advertisement = null;
    _socket?.close();
    _socket = null;
    log('Stopped listening');
  }

  void dispose() {
    stopListening();
    _discovery?.stop();
    _discovery = null;
    listenerNames.dispose();
    _messageController.close();
  }
}
