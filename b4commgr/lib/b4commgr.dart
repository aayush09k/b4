// Importing core libraries
import 'dart:async';
import 'dart:collection';
// import 'dart:core';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

// Importing libraries from external packages
//import 'package:flutter_webrtc/flutter_webrtc.dart';
//import 'package:http/http.dart' as http;

// Importing libraries from our packages
//import 'package:b4connection/B4connection.dart';
import 'package:b4commgr/udpPkg.dart';
import 'package:b4rttable/routingmanager.dart';
import 'package:b4rttable/b4rttable.dart';
import 'package:nodeid/src/nodeid_base.dart';
import 'endPointAddress.dart';
import 'networkInformation.dart';

// A Queue to act as the RM buffer
Queue<List> rmBufferQueue = Queue<List>();
// A Queue to act as the IM buffer
Queue<List> imBufferQueue = Queue<List>();
// A Queue to act as the CM Internal buffer
Queue<List> cmInternalBufferQueue = Queue<List>();

// A class for node to node communication.
class CommunicationManager {

    // For each of the other nodeIDs,
    // a separate connection instance is to be created, as connections are bound to nodeIDs of the other nodes.

    // Private static instance of the CommunicationManager
    static final CommunicationManager _instance = CommunicationManager._internal();

    // Private constructor
    CommunicationManager._internal();

    // Factory constructor to access the singleton instance
    factory CommunicationManager() {
        return _instance;
    }
    Socket? _socket;
    bool useProxy = false;
    Socket? _localSocket;

    int BaselayerID=0;
    int Proxy4layerID=6;
    int Proxy6layerID=7;
    int ProxyDual46layerID=8;


    // get from config
    String selfNodeHash="";
    var ipType, ipAddr, pvtStat, publicIP, publicPort;

    ProxyEndpointAddress proxy4add, proxy6add;
    ICECandidates directadd;

// Asynchronous function to get endpoint information list. It used stun server and stun port, bootstrapserver to create IPv4 and IPv6 UDP
// stunServer is a DNS name. It can be resolved to both IPv4 and IPv6 depending on how the stunServer is configured.
// We should try to use stunServer which has both IPv4 and IPv6 addresses.
  //  NetworkDetails nd=NetworkDetails();
    Future <void> socketMessage(String selfNodeHash, String bootstrapServer,String stunServer, int stunPort) async {
        try {
        // Initialize an empty list to store information about active IPs
        List<List<dynamic>> activeIPInfo = await NetworkDetails().getNetworkInfo(stunServer, stunPort);
            // Iterate through each address in the active IP list
            for(var lst1 in activeIPInfo) {
                // Iterate through each address in the active IP list
                for(var addr in lst1) {
                    // get the collected data for each IP: [IP type, IP address, private status, public IP, public port]
                    ipType = addr[0];
                    ipAddr = addr[1];
                    pvtStat = addr[2];
                    publicIP = addr[3];
                    publicPort = addr[4];


                    // If the IP address is private, try to get the public IP using the STUN server
                    if (pvtStat.startsWith("Y")) {
                        useProxy = true;
                        late String pnode;
                        // connect to bootstrap and get the list of proxy server (RT of proxy layer)
                        // find the closest proxy server node. Recursively,
                        // get the proxy server RT from current closest and find the closest Proxy server node in it.
                        // Repeat the above process till we get the closest proxy server
                        //bootstrapServer = proxy['ip'] + ':' + proxy['port'].toString();
                        //pnode = proxy['ip'] + ':' + proxy['port'].toString();
                        if (ipType == "IPv4") {
                            pnode = findClosestProxyNodeRecursively(
                                 bootstrapServer ,
                                Proxy4layerID) as String;
                        }
                        if (ipType == "IPv6") {
                            pnode = findClosestProxyNodeRecursively(
                                 bootstrapServer,
                                Proxy6layerID) as String;
                        }
                        // get the proxy server's ip address and port to be used in endpoint address of current node.

                        // Find the index of the last colon
                        int lastColonIndex = pnode.lastIndexOf(':');
                        // String before the last colon
                        String part1 = pnode.substring(0, lastColonIndex);
                        // String after the last colon
                        int part2 = pnode.substring(lastColonIndex + 1) as int;
                        //get the ip address type
                        String addtype = getAddressType(part1);
                        // set endpoint address for self node

                        // Create the TCP connection and set the proxy true with proxy ip and port.
                        _socket = connect(part1, part2) as Socket?;
                        // The proxy node, will enter the TCP socket pointer, the current nodes nodeID in the proxy forwarding table.

                        _socket!.listen(_messageHandler);

                        // Ensure that a messageHandler is registered with TCP socket to received the incoming bytes and parse the received messages.
                    }
// TBD - 20250225-1914 : proxy forwarding table related protocol on a TCP server socket is to be created.
                    // If the IP address is not private, treat it as a public IP

                    else if (pvtStat.startsWith("N")) {
                        // For IPv4 and IPv6, bind a UDP socket to determine the public port
                        if (ipType == "IPv4") {
                            String ipadd4 = InternetAddress.anyIPv4 as String;
                            UDPSocket myServer = await UDPSocket.bind(
                                InternetAddress.anyIPv4, 0);
                            publicPort = myServer.rawSocket.port;
                            _socket = await connect(ipadd4, publicPort);
                            _socket!.listen(_messageHandler);
                            //     myServer.handler((message){   });

                        } else if (ipType == "IPv6") {
                            String ipadd6 = InternetAddress.anyIPv6 as String;
                            publicPort =
                                (await UDPSocket.bind(
                                    InternetAddress.anyIPv6, 0))
                                    .rawSocket.port;
                            _socket = await connect(ipadd6, publicPort);
                            _socket!.listen(_messageHandler);
                        }
                    }
                }


            }//for2

        } catch (e) {
            // Catch and print any errors that occur during execution
            print('Error: $e');
        }

    }

    // Utility function to find the closest node based on XOR distance
    //closestNode = proxy['ip'] + ':' + proxy['port'].toString();
    String findClosestFromPRT(List<Map<String, dynamic>> proxyRoutingTable) {
        String closestNode = '';
        int closestDistance = 160; // Max distance for 160-bit node ID

        for (var proxy in proxyRoutingTable) {
            String proxyNodeId = proxy['node_id']; // 160-bit hexadecimal node ID
            int distance = calculateDistance(selfNodeHash, proxyNodeId);

            if (distance < closestDistance) {
                closestDistance = distance;
                closestNode = proxy['ip'] + ':' + proxy['port'].toString();
            }
        }

        return closestNode;
    }

    // Function to calculate XOR distance between two node IDs
    int calculateDistance(String nodeId, String proxyNodeId) {
        // Convert hex node IDs to BigInt for comparison
        BigInt nodeBigInt = BigInt.parse(nodeId, radix: 16);
        BigInt proxyBigInt = BigInt.parse(proxyNodeId, radix: 16);
        int dist=(nodeBigInt ^ proxyBigInt).toInt();
        return dist; // XOR and convert to integer distance
    }

    // Main loop to iteratively find the closest node
    //closestNode = proxy['ip'] + ':' + proxy['port'].toString();
    Future<String> findClosestProxyNodeRecursively(String bootstrapServer, int Proxy4layerID) async {
        // Start with the Bootstrap Server (BS) as the closest node
        String closest = bootstrapServer;
        String cnode = '';

        do {
            cnode = closest;
            print('Current Node: $cnode');

            // Get the routing table for the Proxy4LayerID from the current closest node
            //List<Map<String, dynamic>> routingTable = await routingtable.getRT(Proxy4layerID, node);
            List<Map<String, dynamic>> proxyRoutingTable = await RoutingManager.getRT(cnode, Proxy4layerID);
            //getRT(Proxy4layerID, node);
            // Find the closest node from the routing table
            closest = findClosestFromPRT(proxyRoutingTable);
            print('Closest Node: $closest');

        } while (cnode != closest); // Repeat until convergence

        print('Final Closest Node: $closest');
        return closest;
    }

    // Connect to this proxy server and return the socket.
    Future<Socket> connect(String proxyIP, int proxyPort) async {
        return await Socket.connect(proxyIP, proxyPort);
    }

    // Message handler to process incoming messages from the proxy
    void _messageHandler(List<int> data) {
        String message = utf8.decode(data);

        print("Received message from proxy: $message");

        try {
            var decodedMessage = jsonDecode(message);
            if (decodedMessage is List) {
                // get the destination hash from destination node
                String dhash = decodedMessage[2].nodeID.nodeID;
                print("Destination Module: $dhash");
                //match the destination hash with self node hash
                if (dhash == selfNodeHash) {
                    //if destination hash matched with node
                    //get the destination module
                    String dmodule = decodedMessage[1] ?? 'Unknown Module';
                    print(
                        "Received a destination module name: ${decodedMessage[1]}");
                    print("Destination Module: $dmodule");

                    // Handle specific module actions
                    if (dmodule == 'RM') {
                        //put message to RM buffer
                        rmBufferQueue.add(message as List);
                    } else if (dmodule == 'IM') {
                        //put message to IM buffer
                        imBufferQueue.add(message as List);
                    }
                }else {
                    //if destination hash not matched with node
                    //get the next hop hash from rm for destination node
                    List<Map<String, dynamic>> localRoutingTable = RoutingManager.getRT(selfNodeHash, BaselayerID);
                    dynamic nexthop=B4RoutingTable().nextHop(dhash,localRoutingTable) ;
                    //get the next hop hash
                    dynamic nexthophash= nexthop.nodeID.nodeID;

                    // set the next hop hash as destination hash in message
                    decodedMessage[0].destinationNodeHash = nexthophash;
                    //add the next hop hash as next destination hash in message

                    //put this message to cm send buffer to sending to the next hop
                    cmInternalBufferQueue.add(decodedMessage);
                }
            } else {
                print("Message format is invalid: $message");
            }
        } catch (e) {
            print("Error processing message: $e");
        }
    }

    // Function to check if an IP address type
    String getAddressType(String address) {
      // Check if it's IPv4
      if (isIPv4(address)) {
            return 'IPv4';
        }

      // Check if it's IPv6
      else if (isIPv6(address)) {
        // Check if the IPv6 is in the private range (ULA) or loopback
            return 'IPv6';
      }
      return 'Invalid address';
    }

    // Check if the address is a valid IPv4
    bool isIPv4(String address) {
      final ipv4Regex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
      return ipv4Regex.hasMatch(address);
    }

    // Check if the address is a valid IPv6
    bool isIPv6(String address) {
      final ipv6Regex = RegExp(r'^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$');
      return ipv6Regex.hasMatch(address);
    }
    
  /*
                extra code
                     EndpointAddress endpoint = pnode.endpointAddress;
                    if (endpoint.publicipv6 != null && endpoint.publicipv6port != null) {
                        print('IPv6 Address: ${endpoint.publicipv6}');
                        ipv6add=endpoint.publicipv6;
                        print('IPv6 Port: ${endpoint.publicipv6port}');
                        ipv6port=endpoint.publicipv6port;
                      } else if (endpoint.publicipv4 != null && endpoint.publicipv4port != null) {
                        print('IPv4 Address: ${endpoint.publicipv4}');
                        ipv4add=endpoint.publicipv4;
                        print('IPv4 Port: ${endpoint.publicipv4port}');
                        ipv4port=endpoint.publicipv4port;
                      } else {
                        print('IPv4 Address or Port not available.');
                      }

        // Determines the NAT type by performing multiple NAT tests using a STUN server
    Future<String> determineNATType(String stunServer, int stunPort) async {
        try {
            // Perform NAT tests and determine the NAT type
            String natType = await _performNATTests(stunServer, stunPort);
            return natType;
        } catch (e) {
            // If an error occurs, print the error message
            print("Error determining NAT Type: $e");
        }
        // Return 'Null' if any error occurs
        return "Null";
    }

    // Performs various NAT tests to determine the NAT type using a STUN server
    Future<String> _performNATTests(String stunServer, int stunPort) async {
        // Test I: Send request without changing IP or port
        String mappedAddressTest1 = await _stunTest(stunServer, stunPort, changeIP: false, changePort: false);
        if (mappedAddressTest1.isEmpty) {
            // If no address is mapped, return "No UDP connectivity"
            return "No UDP connectivity";
        }

        // Parse the mapped address from Test I
        var parts = mappedAddressTest1.split(':');

        // Check if the response format is valid
        if (parts.length != 2) return "Invalid response in Test I";
        String publicIP1 = parts[0];
        int publicPort1 = int.parse(parts[1]);

        // List network interfaces and check if the device is behind NAT
        List<NetworkInterface> interfaces = await NetworkInterface.list();
        bool isNatted = true;

        // Iterate over each network interface.
        for (var interface in interfaces) {
            // Iterate over each address of the current network interface.
            for (var address in interface.addresses) {
                // If the public IP matches an interface IP, it's not behind NAT
                if (address.address == publicIP1) {
                    isNatted = false;
                    break;
                }
            }
        }

        // If not behind NAT, return "No NAT"
        if (!isNatted) {
            return "No NAT";
        }

        // Test II: Changing both IP and port
        String test2Response = await _stunTest(stunServer, stunPort, changeIP: true, changePort: true);
        // If the response is not empty, it indicates a Full Cone NAT. In this case, the NAT allows any external host to send data to the internal host.
        if (test2Response.isNotEmpty) {
            return "Full Cone NAT";
        }

        // Test III: Changing only the port
        String test3Response = await _stunTest(stunServer, stunPort, changeIP: false, changePort: true);
        // If the response is not empty, it indicates a Restricted Cone NAT. This type of NAT restricts incoming traffic to the internal host only from addresses that the internal host has previously sent data to.
        if (test3Response.isNotEmpty) {
            return "Restricted Cone NAT";
        }

        // Re-running Test I to check for Symmetric NAT
        String mappedAddressTest1Again = await _stunTest(stunServer, stunPort, changeIP: false, changePort: false);
        // If the mapped address changes between the first and second test, it indicates a Symmetric NAT. Symmetric NAT assigns a different public port for each external host.
        if (mappedAddressTest1Again != mappedAddressTest1) {
            return "Symmetric NAT";
        }
        // If none of the above conditions are met, it must be Port Restricted Cone NAT.
        // This type of NAT behaves similarly to Restricted Cone NAT, but it also restricts incoming traffic based on both IP and port.
        return "Port Restricted Cone NAT";
    }
    // Magic cookie for STUN requests
    final _magicCookie = [0x21, 0x12, 0xA4, 0x42];

    // Performs a STUN test to get the public IP and port using stun server
    Future<String> _stunTest(String stunServer, int stunPort, {bool changeIP = false, bool changePort = false}) async {
        // Bind socket to any IPv4 address and port
        final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        // Generate transaction ID and construct STUN request message
        final transactionId = List<int>.generate(12, (i) => i);
        final stunMessage = Uint8List.fromList([
         0x00, 0x01, // Message Type: Binding Request
         0x00, 0x08, // Message length
         ..._magicCookie, // Magic cookie
         ...transactionId, // Transaction ID
         0x00, 0x03, // Message Attributes
         0x00, 0x04, // Change IP and/or port flags
         0x00, 0x00, 0x00, (changeIP ? 0x04 : 0x00) | (changePort ? 0x02 : 0x00), // Flags to indicate if IP/Port should change
                                               ]);

        // Resolve the STUN server's address using the domain name (stunServer) and filter for IPv4 addresses.
        final stunServerAddress = (await InternetAddress.lookup(stunServer))
        .where((addr) => addr.type == InternetAddressType.IPv4)
        .toList();
        // If no valid IPv4 address is found for the STUN server, print an error message and return an empty string.
        if (stunServerAddress.isEmpty) {
            // Return empty string if the STUN server can't be resolved
            print('Failed to resolve STUN server address.');
            return '';
        }

        // Select the first resolved IPv4 address as the STUN server's IP address.
        final stunServerIP = stunServerAddress.first;
        // Send the STUN request message to the STUN server using the selected IP and port.
        socket.send(stunMessage, stunServerIP, stunPort);

        // Send the STUN request message to the STUN server using the selected IP and port.
        String? publicIP;
        // Declare a variable to hold the public port returned by the STUN server.
        int? publicPort;

        // Wait for events from the socket (e.g., reading incoming data).
        await for (var event in socket) {
            // Check if the event is a "read" event, which means we have received data.
            if (event == RawSocketEvent.read) {
                // Receive the incoming datagram (network packet).
                final datagram = socket.receive();
                // If a datagram is received (i.e., not null), process its data.
                if (datagram != null) {
                    // Extract the response data from the datagram.
                    final response = datagram.data;
                    // Ensure that the response data length is greater than 20 bytes (to ensure valid data).
                    if (response.length > 20) {
                        // Extract the address family from the response (byte 25).
                        final addressFamily = response[25];
                        // Check if the address family is IPv4 (0x01 indicates IPv4).
                        if (addressFamily == 0x01) { // IPv4
                            // Extract the public port from the response (bytes 26 and 27).
                            // The port is XOR-ed with the magic cookie for additional obfuscation.
                            publicPort = (response[26] << 8 | response[27]) ^ (_magicCookie[0] << 8 | _magicCookie[1]);
                            // Parse the public IP address from bytes 28 to 31, XOR-ing with the magic cookie.
                            // This is required because the STUN protocol obfuscates the IP address using the magic cookie.
                            final ip = [
                                response[28] ^ _magicCookie[0],
                                response[29] ^ _magicCookie[1],
                                response[30] ^ _magicCookie[2],
                                response[31] ^ _magicCookie[3],
                            ].join('.');
                            // The final parsed public IP is stored in the `publicIP` variable.
                            publicIP = ip;

                        } else {
                            // If the address family is not IPv4, print a message indicating that the response is not IPv4.
                            print('Received a non-IPv4 response.');
                        }
                    }
                }
                // Break the loop after receiving the first valid response.
                break;
            }
        }
        // Close the socket after receiving the response
        socket.close();
        // Return the public IP and port
        return publicIP != null && publicPort != null ? '$publicIP:$publicPort' : '';
    }

// This function checks if the device is behind a NAT (Network Address Translation) based on its public IP address.
    Future<bool> checkIfBehindNAT(String publicIP) async {
        // Get a list of all network interfaces (e.g., Wi-Fi, Ethernet) on the device.
        List<NetworkInterface> interfaces = await NetworkInterface.list();
        // Loop through each network interface (e.g., Wi-Fi, Ethernet).
        for (var interface in interfaces) {
            // Loop through each address associated with this network interface (e.g., IP addresses).
            for (var address in interface.addresses) {
                // Check if the current address is not a private IP and matches the public IP.
                // A private IP (like 192.168.x.x, 10.x.x.x, etc.) would indicate the device is behind NAT.
                if (!isPrivateIP(address.address) && address.address == publicIP) {
                    // If the public IP matches any of the device's interface IPs, return false (device is not behind NAT).
                    return false;
                }
            }
        }
        // If no matching interface IP is found, return true (device is behind NAT).
        return true;
    }




    // Function returns the first IPv4 address found, which is the resolved address of the STUN server.
    Future stunIpAddress4(String stunServer) async {
        // Perform a DNS lookup to resolve the STUN server address for IPv4
        final stunServerAddress = (await InternetAddress.lookup(stunServer))
        .where((addr) => addr.type == InternetAddressType.IPv4)
        .toList();
        // Check if the STUN server address could not be resolved
        if (stunServerAddress.isEmpty) {
            print('Failed to resolve STUN server address.');
            // Exit the function if the server address could not be resolved
            exit;
            // return '';
        }

        //print(stunServerAddress);
        // Get the first IPv4 address (as there's usually only one)
        final stunServerIP = stunServerAddress.first;
        //  final stunServerIP4=stunServerIP.address;
        // Print out the type and the resolved STUN server IP address
        print('${stunServerIP.type} Stun Address: ${stunServerIP.address}');
        // Return the resolved STUN server IP address
        return stunServerIP;
    }

    // function returns the first IPv6 address found, which is the resolved address of the STUN server.
    Future stunIpAddress6(String stunServer) async {
        // Perform a DNS lookup to resolve the STUN server address for IPv6
        final stunServerAddress = (await InternetAddress.lookup(stunServer))
        .where((addr) => addr.type == InternetAddressType.IPv6)
        .toList();
        // Check if the STUN server address could not be resolved
        if (stunServerAddress.isEmpty) {
            print('Failed to resolve STUN server address.');
            // Exit the function if the server address could not be resolved
            exit;
            // return '';
        }
        //  print(stunServerAddress);
        // Get the first IPv6 address (as there's usually only one)
        final stunServerIP = stunServerAddress.first;
        //  InternetAddress stunServerIP6=stunServerIP.address as InternetAddress;
        // Print out the type and the resolved STUN server IP address
        print('${stunServerIP.type} Stun Address: ${stunServerIP.address}');
        // Return the resolved STUN server IP address
        return stunServerIP;
    }
*/

}
