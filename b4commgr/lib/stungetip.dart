import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'udpPkg.dart'; // Assuming this contains the correctly implemented UDPSocket class

class StunClient {

    UDPSocket? _socketIpv4;
    InternetAddress? _publicIPv4;
    int? _publicPortIPv4;
    InternetAddress? _localIPv4;
    int? _localPortIPv4;
    UDPSocket? _socketIpv6;
    InternetAddress? _publicIPv6;
    int? _publicPortIPv6;
    InternetAddress? _localIPv6;
    int? _localPortIPv6;
    int? N;

    // Transaction ID for the STUN request, this should be unique for each request ideally
    final Uint8List transactionIDIpv4 = Uint8List.fromList([
                                         0x63, 0x43, 0xF6, 0x22, 0x11, 0xA1, 0x47, 0x37, 0x00, 0x00, 0x00, 0x00,
                                     ]);

    Future<void> initializeIpv4() async {

        _socketIpv4 = await UDPSocket.bind(InternetAddress.anyIPv4, 0);
        print('bound to ipv4');
        // Get the list of network interfaces
        final interfaces = await NetworkInterface.list();

        // Find the IPv4 interface with a non-loopback address
        NetworkInterface? ipv4Interface;
        for (final interface in interfaces) {
            for (final addr in interface.addresses) {
                if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
                    ipv4Interface = interface;
                    break;
                }
            }
            if (ipv4Interface != null) {
                break;
            }
        }

        // Get the local IPv4 address assigned by the router
        _localIPv4 = ipv4Interface?.addresses.first;

        // Get local port
        _localPortIPv4 = _socketIpv4!.rawSocket.port;
    }

    Future<void> fetchPublicIPIpv4(stunServer, Port) async {
        await _sendStunRequest(stunServer, Port);
    }

    Future<void> _sendStunRequest(stunServer, stunPort) async {
        var stunRequest = Uint8List.fromList([
         0x00, 0x01, 0x00, 0x00, // STUN Binding Request Header
         0x21, 0x12, 0xA4, 0x42, // Magic Cookie
                                             ]) + transactionIDIpv4; // Append the transaction ID

        if (_socketIpv4 != null) {
            await _socketIpv4!.send(stunRequest, stunServer, stunPort);
            await _processResponseIpv4();
        }
    }

    Future<void> _processResponseIpv4() async {
        if (_socketIpv4 == null) return;

        Datagram? datagram = await _socketIpv4!.receive(
            timeout: 5000); // Timeout set to 5000ms
        if (datagram != null && datagram.data.length >= 20) {
            var response = datagram.data;
            if (response[0] == 0x01 &&
                    response[1] == 0x01) { // Binding Response Success
                _parseResponseIpv4(response);
            }
        } else {
            print('No response or invalid response received from STUN server');
        }
    }

    void _parseResponseIpv4(Uint8List response) {
        int magicCookieOffset = 4; // Magic cookie starts at byte 4
        Uint8List magicCookie = response.sublist(
                                    magicCookieOffset, magicCookieOffset + 4);
        // The transaction ID is already defined at the class level

        int messageLength = (response[2] << 8) + response[3];
        int index = 20; // Starting index for attributes
        while (index < 20 + messageLength) {
            int type = (response[index] << 8) + response[index + 1];
            int length = (response[index + 2] << 8) + response[index + 3];
            index += 4; // Move past the attribute header

            if (type == 0x0001 ||
                    type == 0x0020) { // MAPPED-ADDRESS or XOR-MAPPED-ADDRESS
                int family = response[index + 1];
                int port = ((response[index + 2] << 8) +
                            response[index + 3]) ^ (magicCookie[0] << 8 | magicCookie[1]);
                InternetAddress address;

                if (family == 0x01) { // IPv4
                    address = InternetAddress([
                                                  response[index + 4] ^ magicCookie[0],
                                                  response[index + 5] ^ magicCookie[1],
                                                  response[index + 6] ^ magicCookie[2],
                                                  response[index + 7] ^ magicCookie[3]
                                              ].map((b) => b.toString()).join('.'));

                    _publicIPv4 = address;
                    _publicPortIPv4 = port;

                }
                index +=
                    length; // Move to the next attribute, adjusting for potential error in original loop increment
            } else {
                index +=
                    length; // Ensure we correctly skip over unrecognized attributes
            }
        }
    }

    bool NATcheckIpv4() {
        if (_localIPv4 != null && _publicIPv4 != null) {
            return _localIPv4 == _publicIPv4;
        }
        return false;
    }

    InternetAddress? getPublicIPv4() => _publicIPv4;

    int? getPublicPortIPv4() => _publicPortIPv4;

    InternetAddress? getLocalIPv4() => _localIPv4;

    int? getLocalPortIPv4() => _localPortIPv4;


    Future<void> closeIpv4() async {
        if (_socketIpv4 != null) await _socketIpv4!.close();
        print('closed for ipv4');
    }

    //Below code is for ipv6 .

    // Transaction ID for the STUN request, this should be unique for each request ideally
    final Uint8List transactionIDIpv6 = Uint8List.fromList([
                                         0x63, 0x43, 0xF6, 0x22, 0x11, 0xA1, 0x47, 0x37, 0x00, 0x00, 0x00, 0x00,
                                     ]);


    Future<void> initializeIpv6() async {




        _socketIpv6 = await UDPSocket.bind(InternetAddress.anyIPv6, 0);
        print('bound to ipv6');

        // Get the list of network interfaces
        final interfaces = await NetworkInterface.list();

        // Find the IPv6 interface with a non-loopback address
        NetworkInterface? ipv6Interface;
        for (final interface in interfaces) {
            for (final addr in interface.addresses) {
                if (addr.type == InternetAddressType.IPv6 && !addr.isLoopback) {
                    ipv6Interface = interface;
                    break;
                }
            }
            if (ipv6Interface != null) {
                break;
            }
        }

        // Get the local IPv6 address assigned by the router
        _localIPv6 = ipv6Interface?.addresses.first;

        // Get local port
        _localPortIPv6 = _socketIpv6!.rawSocket.port;
    }

    Future<void> fetchPublicIPIpv6(stunServer, Port) async {
        await _sendStunRequestIpv6(stunServer, Port);
    }

    Future<void> _sendStunRequestIpv6(stunServer, Port) async {
        var stunRequest = Uint8List.fromList([
         0x00, 0x01, 0x00, 0x00, // STUN Binding Request Header
         0x21, 0x12, 0xA4, 0x42, // Magic Cookie
                                             ]) + transactionIDIpv6; // Append the transaction ID

        if (_socketIpv6 != null) {
            await _socketIpv6!.send(stunRequest, stunServer, Port);
            await _processResponseIpv6();
        }
    }

    Future<void> _processResponseIpv6() async {
        if (_socketIpv6 == null) return;

        Datagram? datagram = await _socketIpv6!.receive(
            timeout: 5000); // Timeout set to 5000ms
        if (datagram != null && datagram.data.length >= 20) {
            var response = datagram.data;
            if (response[0] == 0x01 &&
                    response[1] == 0x01) { // Binding Response Success
                _parseResponseIpv6(response);
            }
        } else {
            print('No response or invalid response received from STUN server');
        }
    }

    void _parseResponseIpv6(Uint8List response) {
        int magicCookieOffset = 4; // Magic cookie starts at byte 4
        Uint8List magicCookie = response.sublist(
                                    magicCookieOffset, magicCookieOffset + 4);
        // The transaction ID is already defined at the class level

        int messageLength = (response[2] << 8) + response[3];
        int index = 20; // Starting index for attributes
        while (index < 20 + messageLength) {
            int type = (response[index] << 8) + response[index + 1];
            int length = (response[index + 2] << 8) + response[index + 3];
            index += 4; // Move past the attribute header

            if (type == 0x0001 ||
                    type == 0x0020) { // MAPPED-ADDRESS or XOR-MAPPED-ADDRESS
                int family = response[index + 1];
                int port = ((response[index + 2] << 8) +
                            response[index + 3]) ^ (magicCookie[0] << 8 | magicCookie[1]);
                InternetAddress address;

                if (family == 0x02) { // IPv6
                    List<int> xorAddr = List<int>.filled(16, 0);
                    List<int> xorKey = List.from(magicCookie)
                                       ..addAll(transactionIDIpv6);

                    for (int i = 0; i < 16; i++) {
                        xorAddr[i] = response[index + 4 + i] ^ xorKey[i % xorKey.length];
                    }

                    // Convert each byte to its hexadecimal representation
                    var addrHexParts = <String>[];
                    for (int i = 0; i < xorAddr.length; i += 2) {
                        addrHexParts.add(xorAddr.sublist(i, i + 2).map((b) =>
                                         b.toRadixString(16).padLeft(2, '0')).join());
                    }

                    // Join parts into a full IPv6 address string
                    var addressString = addrHexParts.join(':');

                    try {
                        address = InternetAddress(addressString);
                        _publicIPv6 = address;
                        _publicPortIPv6 = port;

                    } catch (e) {
                        print("Error creating InternetAddress from IPv6: $e");
                    }
                }


                index +=
                    length; // Move to the next attribute, adjusting for potential error in original loop increment
            } else {
                index +=
                    length; // Ensure we correctly skip over unrecognized attributes
            }
        }
    }


    //InternetAddress? getLocalIPv6() => _localIPv6;
    //int? getLocalPortIPv6() => _localPortIPv6;

    InternetAddress? getPublicIPv6() => _publicIPv6;

    int? getPublicPortIPv6() => _publicPortIPv6;

    Future<void> closeIpv6() async {
        if (_socketIpv6 != null) await _socketIpv6!.close();
        print('closed for ipv6');
    }
    void resetIP() {
        print('N=$N');
        switch(N) {
        case 0:
            _publicIPv4=null;
            _publicPortIPv4=null;
        case 2:
            _publicIPv6=null;
            _publicPortIPv6=null;
        case 3:
            _publicIPv6=null;
            _publicPortIPv6=null;
            _publicIPv4=null;
            _publicPortIPv4=null;
        }
    }

}


