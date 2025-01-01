import 'dart:async';
import 'dart:io';
import 'stungetip.dart';
import 'package:b4connection/B4connection.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;


// A class for node to node communication.
class CommunicationManager {

    // For each other nodeID,
// a separate connection instance is to be created, as connection is bound to nodeID of other node.
    // Private static instance of the buffer
    static final CommunicationManager _instance = CommunicationManager
            ._internal();

    // Private constructor
    CommunicationManager._internal();

    // Factory constructor to access the singleton instance
    factory CommunicationManager() {
        return _instance;
    }

    StunClient stunClient = StunClient();
    String? _publicIPv6;
    final Map<String, B4connection> _connections = {};

    //final Map<String, WebRTCManager> _connectionsWebrtc = {};
    Socket? socket;
    Socket? nodeSocket;

    Future startStreaming(remoteNodeID) async {
        // Map<String, dynamic> configuration = {
        //   "iceServers":
        //   [
        //     {"url": "stun:stun.l.google.com:19302"},
        //   ]
        // };


        // Check if a connection already exists
        /*if (_connectionsWebrtc.containsKey(remoteNodeID)) {
          var iceCandiDateJsonString=_connectionsWebrtc[remoteNodeID]!.getIceCandidates();
          var offer=_connectionsWebrtc[remoteNodeID]!.createOffer();
          Map<dynamic,dynamic> proposal={
            'iceCandiDateJson':iceCandiDateJsonString,
             'oFFer':offer,
          };
          sendMessage('35.185.142.164',22355, 'TP',jsonEncode(proposal) , remoteNodeID);

        } else {
          // Create a new connection if it does not exist
          _connectionsWebrtc[remoteNodeID] = WebRTCManager();
          _connectionsWebrtc[remoteNodeID]!.initiatingWebrtc();
          _connectionsWebrtc[remoteNodeID]!.PeerConnection(configuration);
          var iceCandiDateJsonString=_connectionsWebrtc[remoteNodeID]!.getIceCandidates();
          var offer=_connectionsWebrtc[remoteNodeID]!.createOffer();
          print(offer);
        }*/

    }

    // This function is used to communicate between two nodes in a end to end fashion.
    Future communicate(ip, port, type, message, remoteNodeID) async {
        // Check if a connection already exists
        if (_connections.containsKey(remoteNodeID)) {
            await _connections[remoteNodeID]!.sendMessage(
                message, type, remoteNodeID);
        } else {
            // Create a new connection if it does not exist
            _connections[remoteNodeID] = B4connection();
            _connections[remoteNodeID]!.setMyNodeId(remoteNodeID);

            await _connections[remoteNodeID]!.startConnection(
                ip, port, type, remoteNodeID);

            _connections[remoteNodeID]!.sendMessage(message, type, remoteNodeID);
        }
        try {
            // Set the onClosed callback
            _connections[remoteNodeID]!.onClosed = () {
                _connections.remove(remoteNodeID);
                print(
                    "Connection for $remoteNodeID has been removed from manager due to closure.");
            };
        }
        catch (e) {}
    }


    // Below function can be use to identify the network environment.
    Future<int?> getNetworkInformation(stunIp, stunPort) async {
        var natStatus = 5;
        //Start connection with STUN server for all the network information.
        // Try to connect to stun server by ipv4 and ipv6 both one by one.

        try {
            await stunClient.initializeIpv4();
            await stunClient.fetchPublicIPIpv4(stunIp, stunPort);
            await stunClient
            .closeIpv4(); //After getting information closed immediately.
            stunClient.N = 2;
            stunClient.resetIP();
            // For current situation we do not need this.
            // try {
            //   await stunClient.initializeIpv6();
            //   await stunClient.fetchPublicIPIpv6(stunIp, stunPort);
            //   await stunClient
            //       .closeIpv6(); //After getting information closed immediately.
            // }
            // catch (e) {
            //   print(
            //       'Node can not bind to both at a time . Node is not on dual network ');
            //   stunClient.N = 2;
            //   stunClient.resetIP();
            // }
        }
        catch (e) {
            print("Error with IPv4 STUN client: $e");
            try {
                //error connecting by ipv4 hence shift to ipv6.
                await stunClient.initializeIpv6();
                await stunClient.fetchPublicIPIpv6(stunIp, stunPort);
                await stunClient
                .closeIpv6(); //After getting information closed immediately.
                //Below logic is implemented to making previous values of ip and port null.
                stunClient.N = 0;
                stunClient.resetIP();
            }
            catch (e) {
                print("Error with IPv6 STUN client: $e");
                stunClient.N = 3;
                stunClient.resetIP();
            }
        }
        await _getIpv6();


        if (_publicIPv6 != null) {
            natStatus = 2;
        }
        else {
            switch (stunClient.NATcheckIpv4()) {
            case true:
            {
                natStatus = 1;
                break;
            }
            case false:
            {
                natStatus = 0;
                break;
            }
            }
        }
        return natStatus;
    }


    // According to the information gathered it will start Listening for connection or
    // else it will be connected to provided  braHasPaTi node.
    Future<void> activateNode(communicatorIp, communicatorPort, listeningPort,
                              natStatus, remoteNodeID) async {
        switch (natStatus) {
        case 0:
            await _createInstanceCorrespondingToNodeId(listeningPort);
            await communicate(
                communicatorIp, communicatorPort, 'MP', null, remoteNodeID);


        case 1: // only listen for the connection.
            await _createInstanceCorrespondingToNodeId(listeningPort);
        case 2: // Here we do both listen for the connection. relay registration.

            await _createInstanceCorrespondingToNodeId(listeningPort);
            await communicate(
                communicatorIp, communicatorPort, 'MP', null, remoteNodeID);


        default:
            print('natStatus is not defined');
        }
    }


    Future _createInstanceCorrespondingToNodeId(listeningPort) async {
        B4connection b4connection = B4connection();
        await b4connection.startNodeLiseNing(listeningPort);

        b4connection.receiveSocketAndCorrespondingNodeID((nodeId, socket,
        active) async {
            if (active) {
                if (nodeId == null) {}
                else {
                    if (_connections.containsKey(nodeId)) {
                        print('Instance corresponding to $nodeId is present.');
                    }
                    else {
                        // Whenever we receive socket from the any cNode we create a b4connection instance corresponding to that nodeID.
                        // then we set _nodeIdSocket of created instance = socket received.
                        // It is important because we use it to send message in that b4connection instance.
                        _connections[nodeId] = B4connection();
                        _connections[nodeId]!.setNodeSocket(socket);
                    }
                }
            }
            else {
                while (true) {
                    if (_connections[nodeId] == null) {
                        break;
                    }
                    _connections.remove(nodeId);
                    print(
                        "Connection for $nodeId has been removed from manager due to closure.");
                }
            }
        });
    }






    Future<void> getNetworkAddress() async {
      try {
        var interfaces = await NetworkInterface.list(includeLinkLocal: true);
   //     print('Available Network Interfaces:');
        for (var interface in interfaces) {
    //      print('== Interface: ${interface.name} ==');
          for (var addr in interface.addresses) {
            String type = addr.type == InternetAddressType.IPv4 ? 'IPv4' : 'IPv6';
            bool isPrivate = isPrivateIP(addr.address);
            print('$type Address: ${addr.address} (${isPrivate ? "Private" : "Public"})');
          }
        }
      } catch (e) {
        print('Error retrieving network interfaces: $e');
      }
    }

    // Check if the given IP address is private (indicating NAT)
    bool isPrivateIP(String ip) {
      final privateRanges = [
        '10.', '172.16.','172.17.','172.18.','172.19.','172.20.','172.21.','172.22.','172.23.','172.24.','172.25.','172.26.','172.27.','172.28.','172.29.','172.30.','172.31.', '192.168.', // Private IPv4 ranges
        'fc00::', 'fd00::' // Private IPv6 ranges
      ];

      for (var range in privateRanges) {
        if (ip.startsWith(range)) {
          return true; // NAT detected (private IP)
        }
      }
      return false; // Public IP
    }

    // Use Google STUN server to get the public IP address
    Future<String?> getPublicIP(String stunServer, int stunPort) async {
      try {
  //      print('Using STUN protocol to fetch public IP...');
        var stunServerAddress = (await InternetAddress.lookup(stunServer))
            .where((addr) => addr.type == InternetAddressType.IPv4)
            .toList();

        if (stunServerAddress.isEmpty) {
          print('Failed to resolve STUN server address.');
          return null;
        }

        final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  //      print('Using local port: ${socket.port} to communicate with $stunServer:$stunPort');

        // STUN binding request
        final transactionId = List<int>.generate(12, (i) => i);
        final stunMessage = Uint8List.fromList([
          0x00, 0x01, 0x00, 0x00,
          0x21, 0x12, 0xA4, 0x42,
          ...transactionId,
        ]);

        socket.send(stunMessage, stunServerAddress.first, stunPort);
       // print('STUN request sent to ${stunServerAddress.first}:$stunPort.');

        String? publicIP;

        await for (var event in socket) {
          if (event == RawSocketEvent.read) {
            final datagram = socket.receive();
            if (datagram != null) {
              final response = datagram.data;
              if (response.length >= 28) {
                final addressFamily = response[25];
                if (addressFamily == 0x01) {
                  final ip = [
                    response[28] ^ 0x21,
                    response[29] ^ 0x12,
                    response[30] ^ 0xA4,
                    response[31] ^ 0x42
                  ].join('.');
                  publicIP = ip;
        //          print('Public IP retrieved: $ip');
                  break;
                }
              }
            }
          }
        }

        socket.close();
        return publicIP;
      } catch (e) {
        print('Error retrieving public IP via STUN: $e');
        return null;
      }
    }

    // Check if the device is behind a NAT
    Future<bool> checkIfBehindNAT(String publicIP) async {
      List<NetworkInterface> interfaces = await NetworkInterface.list();

      for (var interface in interfaces) {
        for (var address in interface.addresses) {
          if (!isPrivateIP(address.address) && address.address == publicIP) {
            return false;
          }
        }
      }
      return true;
    }


    Future stunIpAddress4(String stunServer) async {
      final stunServerAddress = (await InternetAddress.lookup(stunServer))
          .where((addr) => addr.type == InternetAddressType.IPv4)
          .toList();

      if (stunServerAddress.isEmpty) {
        print('Failed to resolve STUN server address.');
        exit;
        // return '';
      }

      //print(stunServerAddress);
      final stunServerIP = stunServerAddress.first;
      //  final stunServerIP4=stunServerIP.address;
      print('${stunServerIP.type} Stun Address: ${stunServerIP.address}');

      return stunServerIP;
    }

    Future stunIpAddress6(String stunServer) async {
      final stunServerAddress = (await InternetAddress.lookup(stunServer))
          .where((addr) => addr.type == InternetAddressType.IPv6)
          .toList();

      if (stunServerAddress.isEmpty) {
        print('Failed to resolve STUN server address.');
        exit;
        // return '';
      }
      //  print(stunServerAddress);

      final stunServerIP = stunServerAddress.first;
      //  InternetAddress stunServerIP6=stunServerIP.address as InternetAddress;
      print('${stunServerIP.type} Stun Address: ${stunServerIP.address}');
      return stunServerIP;
    }

    //void setBootstrapNode(){}

   // void getProxyLayerRT() {


  //  }

    sendMessage(endpointaddress, message, nodeidobj){ // endpointaddress=bootstrap, message= "getRT,LayerId,"
      //get the nexthop from RT
      //

    }

    receiveMessage(){
      //    received message with node id object
      //parse the node id object get the required values like endpoint address
      // parse the message
      //generate responce
     // send the responce to buffer

    }




/*
    Future<void> getIps() async {
        List<NetworkInterface> interfaces = await NetworkInterface.list( includeLoopback: false, includeLinkLocal: false);

        for (var interface in interfaces) {
          //print('Network Interface: ${interface.name}');
            if (interface.addresses.isNotEmpty) {
     //       print('== Interface: ${interface.name} ==');
                for (var address in interface.addresses) {
         //         print("Address type  $address");
                  print(address.type);
                    if (address.type == InternetAddressType.IPv6) {
                      //     print('IPv6 Address: ${address.address}');
                      String ip6 = address.address;
                      String ip6Type = address.type == InternetAddressType.IPv6 ? "IPv6" : "IPv4";
                      bool isPrivate = isPrivateIP(ip6);
                      print('$ip6Type Address: $ip6 (${isPrivate ? "Private" : "Public"})');
                    }
                    if (address.type == InternetAddressType.IPv4) {
                     //   print('IPv4 Address: ${address.address}');
                        String ip4 = address.address;
                        String ip4Type = address.type == InternetAddressType.IPv6 ? "IPv6" : "IPv4";
                        bool isPrivate = isPrivateIP(ip4);
                        print('$ip4Type Address: $ip4 (${isPrivate ? "Private" : "Public"})');
                    }
                }
            }
        }
    }
*/
/*
    bool isPrivateIP(String ip) {
        final parts = ip.split('.');
        if (parts.length != 4) return false;

        final first = int.tryParse(parts[0]) ?? -1;
        final second = int.tryParse(parts[1]) ?? -1;

        if (first == 10) return true; // 10.0.0.0 - 10.255.255.255
        if (first == 172 && second >= 16 && second <= 31) return true; // 172.16.0.0 - 172.31.255.255
        if (first == 192 && second == 168) return true; // 192.168.0.0 - 192.168.255.255
        if (ip == "127.0.0.1") return true;
        return false;
    }
    */

/*
     Future<String> getPublicIP(String stunServer, int stunPort) async {
        final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
 //       print('Using local port: ${socket.port} to communicate with $stunServer:$stunPort');

        final transactionId = List<int>.generate(12, (i) => i);
        final stunMessage = Uint8List.fromList([
            0x00, 0x01,
            0x00, 0x00,
            0x21, 0x12, 0xA4, 0x42,
            ...transactionId,
         ]);

        final stunServerAddress = (await InternetAddress.lookup(stunServer))
        .where((addr) => addr.type == InternetAddressType.IPv4)
        .toList();

        if (stunServerAddress.isEmpty) {
          print('Failed to resolve STUN server address.');
          return '';
        }


        final stunServerIP = stunServerAddress.first;

        socket.send(stunMessage, stunServerIP, stunPort);
  //      print('STUN request sent to $stunServerIP:$stunPort');

        String? publicIP;

        await for (var event in socket) {
          if (event == RawSocketEvent.read) {
            final datagram = socket.receive();
            if (datagram != null) {
              final response = datagram.data;
              if (response.length > 20) {
                final addressFamily = response[25];
                if (addressFamily == 0x01) { // IPv4
                  final magicCookie = [0x21, 0x12, 0xA4, 0x42];
                  final ip = [
                    response[28] ^ magicCookie[0],
                    response[29] ^ magicCookie[1],
                    response[30] ^ magicCookie[2],
                    response[31] ^ magicCookie[3],
                  ].join('.');
                  publicIP = ip;
        //          print('Public IP: $ip');
                } else {
                  print('Received a non-IPv4 response.');
                }
              } else {
                print('Invalid STUN response.');
              }
              break;
            }
          }
        }

        socket.close();
        return publicIP ?? '';
  }


    Future<String> getPublicIP6(String stunServer, int stunPort) async {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv6, 0);
      //       print('Using local port: ${socket.port} to communicate with $stunServer:$stunPort');

      final transactionId = List<int>.generate(12, (i) => i);
      final stunMessage = Uint8List.fromList([
        0x00, 0x01,
        0x00, 0x00,
        0x21, 0x12, 0xA4, 0x42,
        ...transactionId,
      ]);

      final stunServerAddress6 = (await InternetAddress.lookup(stunServer))
          .where((addr) => addr.type == InternetAddressType.IPv6)
          .toList();

      if (stunServerAddress6.isEmpty) {
        print('Failed to resolve STUN server address.');
        return '';
      }


      final stunServerIP = stunServerAddress6.first;

      socket.send(stunMessage, stunServerIP, stunPort);
      //      print('STUN request sent to $stunServerIP:$stunPort');

      String? publicIP6;

      await for (var event in socket) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            final response = datagram.data;
            if (response.length > 20) {
              final addressFamily = response[25];
              if (addressFamily == 0x01) { // IPv4
                final magicCookie = [0x21, 0x12, 0xA4, 0x42];
                final ip = [
                  response[28] ^ magicCookie[0],
                  response[29] ^ magicCookie[1],
                  response[30] ^ magicCookie[2],
                  response[31] ^ magicCookie[3],
                ].join('.');
                publicIP6 = ip;
                //          print('Public IP: $ip');
              } else {
                print('Received a non-IPv6 response.');
              }
            } else {
              print('Invalid STUN response.');
            }
            break;
          }
        }
      }

      socket.close();
      return publicIP6 ?? '';
    }
*/
    Future<void> getStunPublicIPAddresses(final stunServer) async {
      // Public STUN server (supports both IPv4 and IPv6)

     final stunServerIP4=stunIpAddress4(stunServer);
     final stunServerIP6=stunIpAddress6(stunServer);
    //  print(stunServerIP6.address);
   //  final stunServer = 'stun.l.google.com';
//     final stunPort = 19302;
 //       InternetAddress ipv4=InternetAddress("172.26.82.17");
      // Create a UDP Datagram socket for both IPv4 and IPv6
//      await _getPublicIP(stunServerIP4, stunPort, ipv4 ); // For IPv4
 //     await _getPublicIP(stunServer, stunPort, ipv4 ); // For IPv6
   //   await _getPublicIP(stunServer, stunPort, InternetAddress.anyIPv6); // For IPv6
    }

/*


  Future<void> _getPublicIP(final stunServer, int stunPort, InternetAddress bindAddress)  async {
      try {
        // Create a RawDatagramSocket (UDP socket) that binds to either IPv4 or IPv6 address
        final socket = await RawDatagramSocket.bind(bindAddress, 0);
        print('Socket bound to ${bindAddress.address}');

        // Prepare the STUN binding request (simple request for getting the public IP address)
        final request = _createStunBindingRequest();
        print('create request to $request');

      // Send the STUN binding request to the server
        socket.send(request, InternetAddress(stunServer), stunPort);
      //  socket.send(request, stunServer, stunPort);
        print('Sent STUN binding request to $stunServer:$stunPort');

        // Listen for the STUN response
        socket.listen((RawSocketEvent event) async {
          if (event == RawSocketEvent.read) {
            final datagram = socket.receive();
            if (datagram != null) {
              final response = datagram.data;

              // Parse the STUN response to extract the public IP address
            //  final publicIP = _parseStunResponse(response);
              final publicInfo = _parseStunResponse(response);
             var _publicAddress = publicInfo['address'];
             var  _publicPort = publicInfo['port'];
              print("public ip  $_publicAddress");
              print("public ip  $_publicPort");
              if (_publicAddress != null) {
                print('Public IP address (from $bindAddress): $_publicAddress');
              } else {
                print('Failed to parse STUN response');
              }
            }
          }
        });
      } catch (e) {
        print('Error while getting public IP: $e');
      }
    }





  // Function to create a basic STUN Binding Request
  Uint8List _createStunBindingRequest() {
    final transactionId =
    List<int>.generate(12, (index) => index); // Dummy transaction ID
    final request = Uint8List(20); // Header is 20 bytes
    final buffer = ByteData.sublistView(request);

    buffer.setUint16(0, 0x0001); // Type: Binding request
    buffer.setUint16(2, 0x0000); // Length: 0
    buffer.setUint32(4, 0x2112A442); // Magic cookie
    for (int i = 0; i < transactionId.length; i++) {
      request[8 + i] = transactionId[i];
    }

    return request;
  }
  Map<String, dynamic> _parseStunResponse(Uint8List response) {
    final buffer = ByteData.sublistView(response);
    for (int i = 20; i < response.length - 4;) {
      final attributeType = buffer.getUint16(i);
      final attributeLength = buffer.getUint16(i + 2);
      if (attributeType == 0x0001 || attributeType == 0x0020) {
        final port = (attributeType == 0x0020)
            ? buffer.getUint16(i + 6) ^ 0x2112
            : buffer.getUint16(i + 6);
        final addressBytes = response.sublist(i + 8, i + 8 + 4);
        final address = (attributeType == 0x0020)
            ? InternetAddress.fromRawAddress(Uint8List.fromList(
            addressBytes.map((b) => b ^ 0x21).toList()))
            .address
            : InternetAddress.fromRawAddress(Uint8List.fromList(addressBytes))
            .address;
        return {'address': address, 'port': port};
      }
      i += 4 + attributeLength;
    }

    throw Exception(
        'No MAPPED-ADDRESS or XOR-MAPPED-ADDRESS attribute in STUN response.');
  }
*/
// Function to create a basic STUN Binding Request
 /* Uint8List _createStunBindingRequest() {
    final request = Uint8List(20);

    // STUN Message Type: Binding Request (0x0001)
    request[0] = 0x00;
    request[1] = 0x01;

    // Transaction ID (random 12 bytes)
    final transactionId = List<int>.generate(12, (index) => index);
    for (int i = 0; i < 12; i++) {
      request[4 + i] = transactionId[i];
    }

    return request;
  }
*/
// Function to parse the STUN response and extract the mapped IP address
 /*  String? _parseStunResponse(Uint8List response) {
    if (response.length < 20) {
      print('Invalid STUN response (too short)');
      return null;
    }

    // Check if the message is a valid Binding Response (0x0101)
    if (response[0] == 0x01 && response[1] == 0x01) {
      // Extract the mapped address (IPv4 or IPv6)
    //  final addressFamily = response[3];
      final addressFamily = response[25];// Should be either 0x01 (IPv4) or 0x02 (IPv6)
      final startByte = 28;

      // For IPv4, the mapped address will be in the next 4 bytes (total 8 bytes for address + port)
      if (addressFamily == 0x01 && response.length >= startByte + 8) {
        final mappedAddress = response.sublist(startByte, startByte + 4);
        print(InternetAddress.fromRawAddress(mappedAddress).address);
        return InternetAddress.fromRawAddress(mappedAddress).address;
      }
      // For IPv6, the mapped address will be in the next 16 bytes (total 20 bytes for address + port)
      else if (addressFamily == 0x02 && response.length >= startByte + 20) {
        final mappedAddress = response.sublist(startByte, startByte + 16);
        print(InternetAddress.fromRawAddress(mappedAddress).address);
        return InternetAddress.fromRawAddress(mappedAddress).address;
      } else {
        print('Invalid STUN response: unsupported address family or unexpected data length');
        return null;
      }
    }

    print('Invalid STUN response type');
    return null;
  }

*/
  Future<void> _getIpv6() async {
        try {
            if (stunClient.getPublicIPv6() != null) {
                _publicIPv6 = stunClient.getPublicIPv6()!.address;
            }
        }
        catch (e) {}
    }
}