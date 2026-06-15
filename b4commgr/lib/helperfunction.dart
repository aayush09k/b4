import 'dart:io';
import 'dart:typed_data';

// Standard STUN Magic Cookie from your professor's architecture specs
final List<int> _magicCookie = [0x21, 0x12, 0xA4, 0x42];

/// Checks if an IP address string belongs to a private subnet range
bool isPrivateIP(String ip) {
  try {
    final address = InternetAddress(ip);

    // Handles loopback addresses (127.0.0.1, ::1) natively
    if (address.isLoopback) return true;

    // Check IPv4 private subnets using raw numeric byte values
    if (address.type == InternetAddressType.IPv4) {
      final bytes = address.rawAddress;

      // 10.0.0.0/8
      if (bytes[0] == 10) return true;

      // 172.16.0.0/12
      if (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) return true;

      // 192.168.0.0/16
      if (bytes[0] == 192 && bytes[1] == 168) return true;
    }
    return false;
  } catch (_) {
    return false;
  }
}

/// Low-Level STUN Test: Sends a raw UDP packet
/// and decodes the obfuscated network response using binary XOR.
Future<String> performStunTest(String stunServer, int stunPort,
    {bool changeIP = false, bool changePort = false}) async {
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

  final transactionId = List<int>.generate(12, (i) => i);
  final stunMessage = Uint8List.fromList([
    0x00, 0x01, // Message Type: Binding Request
    0x00, 0x08, // Message length
    ..._magicCookie, // Injection of the STUN Magic Cookie
    ...transactionId, // Unique transaction ID sequence
    0x00, 0x03, // Message Attributes
    0x00, 0x04, // Change parameters flags attribute block
    0x00, 0x00, 0x00,
    (changeIP ? 0x04 : 0x00) | (changePort ? 0x02 : 0x00), // Action Flags
  ]);

  final stunServerAddress = (await InternetAddress.lookup(stunServer))
      .where((addr) => addr.type == InternetAddressType.IPv4)
      .toList();

  if (stunServerAddress.isEmpty) {
    print('Failed to resolve STUN server address.');
    socket.close();
    return '';
  }

  final stunServerIP = stunServerAddress.first;
  socket.send(stunMessage, stunServerIP, stunPort);

  String? publicIP;
  int? publicPort;

  await for (var event in socket) {
    if (event == RawSocketEvent.read) {
      final datagram = socket.receive();
      if (datagram != null) {
        final response = datagram.data;
        if (response.length > 20) {
          final addressFamily = response[25];
          if (addressFamily == 0x01) {
            // IPv4 validation check

            // Bitwise shift and cookie mask XOR decode to obtain mapped UDP public port
            publicPort = (response[26] << 8 | response[27]) ^
                (_magicCookie[0] << 8 | _magicCookie[1]);

            // De-obfuscate external network IP payload bytes using matching Magic Cookie indices
            final ip = [
              response[28] ^ _magicCookie[0],
              response[29] ^ _magicCookie[1],
              response[30] ^ _magicCookie[2],
              response[31] ^ _magicCookie[3],
            ].join('.');

            publicIP = ip;
          }
        }
      }
      break;
    }
  }

  socket.close();
  return publicIP != null && publicPort != null ? '$publicIP:$publicPort' : '';
}
