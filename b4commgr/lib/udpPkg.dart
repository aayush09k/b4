import 'dart:io';
import 'dart:async';
import 'package:async/async.dart';

/// A high-level wrapper around [RawDatagramSocket] for simplified UDP communication.
///
class UDPSocket {
  /// The underlying [RawDatagramSocket] instance.
  final RawDatagramSocket rawSocket;

  /// Internal stream queue to handle socket events sequentially.
  final StreamQueue _eventQueue;

  /// Creates a [UDPSocket] from a [RawDatagramSocket].
  UDPSocket(this.rawSocket) : _eventQueue = StreamQueue(rawSocket);

  /// Binds the socket to a random port assigned by the OS.
  ///
  /// Example:
  /// ```dart
  /// final socket = await UDPSocket.bindRandom(InternetAddress.anyIPv4);
  /// ```
  ///
  /// [host] must be a valid IP address or hostname.
  static Future<UDPSocket> bindRandom(dynamic host,
      {bool reuseAddress = true, bool reusePort = false, int ttl = 1}) {
    return bind(host, 0,
        reuseAddress: reuseAddress, reusePort: reusePort, ttl: ttl);
  }

  /// Binds the socket to a specific [host] and [port].
  ///
  /// Example:
  /// ```dart
  /// final socket = await UDPSocket.bind(InternetAddress.loopbackIPv4, 8080);
  /// ```
  static Future<UDPSocket> bind(dynamic host, int port,
      {bool reuseAddress = true, bool reusePort = false, int ttl = 1}) async {
    final socket = await RawDatagramSocket.bind(host, port,
        reuseAddress: reuseAddress, reusePort: reusePort, ttl: ttl);
    return UDPSocket(socket);
  }

  /// Waits to receive a single [Datagram].
  ///
  /// - [timeout] (in milliseconds) specifies the wait duration.
  /// - If [explode] is true, throws an error on timeout.
  ///
  /// Example:
  /// ```dart
  /// final datagram = await socket.receive(timeout: 2000);
  /// if (datagram != null) {
  ///   print('Received: ${String.fromCharCodes(datagram.data)}');
  /// }
  /// ```
  Future<Datagram?> receive({int? timeout, bool explode = false}) async {
    final completer = Completer<Datagram?>.sync();

    if (timeout != null) {
      Future.delayed(Duration(milliseconds: timeout)).then((_) {
        if (!completer.isCompleted) {
          if (explode) {
            completer.completeError('EasyUDP: Receive Timeout');
          } else {
            completer.complete(null);
          }
        }
      });
    }

    Future.microtask(() async {
      try {
        while (true) {
          final event = await _eventQueue.peek;
          if (event == RawSocketEvent.closed) {
            if (!completer.isCompleted) {
              completer.complete(null);
            }
            break;
          } else if (event == RawSocketEvent.read) {
            await _eventQueue.next;
            if (!completer.isCompleted) {
              var datagram = rawSocket.receive();
              completer.complete(datagram);
            }
            break;
          } else {
            await _eventQueue.next;
          }
        }
      } catch (e) {
        print('receive fail: $e');
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      }
    });

    return completer.future;
  }

  /// Sends a UDP datagram [buffer] to the specified [address] and [port].
  ///
  /// [address] can be an [InternetAddress] or a [String].
  ///
  /// Example:
  /// ```dart
  /// await socket.send(utf8.encode('Ping'), '192.168.1.5', 12345);
  /// ```
  ///
  /// Returns the number of bytes sent.
  Future<int> send(List<int> buffer, dynamic address, int port) async {
    InternetAddress addr;
    if (address is InternetAddress) {
      addr = address;
    } else if (address is String) {
      addr = (await InternetAddress.lookup(address))[0];
    } else {
      throw 'address must be either an InternetAddress or a String';
    }
    return rawSocket.send(buffer, addr, port);
  }

  /// Closes the UDP socket and cleans up resources.
  ///
  /// Example:
  /// ```dart
  /// await socket.close();
  /// ```
  Future<void> close() async {
    try {
      rawSocket.close();
      while (await _eventQueue.peek != RawSocketEvent.closed) {
        await _eventQueue.next;
      }
      await _eventQueue.cancel();
    } catch (e) {
      print('close fail: $e');
    }
  }
}