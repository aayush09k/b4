//Message between two neighbors (with or without relay),if direct TCP link send directly if not use relay, Key , Nodes behind NAT} Present in this send message
//Message Formate , Routing related message(RT Update, DHT message),Query Response , Node behind NAT, Each node maintain multiple RTs for different Layer, message querry publish ,} these all are in Message Factory
//missing part cache management(Catch Expiry).
//Q. Certificate Renewal (1month pre-expiry logic)is to be implemented?
//Q. Is Layerd Routing to be implemented ?

import 'dart:typed_data';

//import 'package:b4_olm/index_mgr/messagefactory.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:b4connection/TcpConnection.dart';
import 'package:b4rttable/b4rttable.dart';
//import 'package:nodeid/nodeid_base.dart' as nodeid;
import 'package:b4utils/messagefactory.dart';
import 'package:b4commgr/endPointAddress.dart';
import 'package:nodeid/nodeid.dart' as nodeid;
import 'dart:convert';
import 'dart:io';
import 'dart:async';

class Node {
  //this node class is made to collect data from all places, represent a network node which can send a message to another node , via a relay.
  nodeid.NodeID
  nodeID; //node id is defined inside Node and get detailes of NodeID , unique ID of node which come from library of nodeid_base
  EndpointAddress
  endpoint; //to get data form endpoint , IP and Port info, were node exit in network
  bool
  isBehindNAT; //we get it from the other module , tells is T/F that is node behind NAT,not direct access
  String?
  proxyAddress; //IP address of proxy server , if behind NAT then IP and port will save here , connect through proxy
  int? proxyPort; //port number of proxy server
  String? sessionKey; //for encrypted communication
  TcpConnection? tcpConnection; //active TCP connection object
  final B4RoutingTable
  _b4RoutingTable; //routing table is required for making nextHop

  Node({
    //this conctructor initilize the node data either direct or behind NAT and inject RT use for lookup
    required this.nodeID,
    required this.endpoint,//Node ip /port info
    required B4RoutingTable b4RoutingTable,
    this.isBehindNAT = false,
    this.proxyAddress,
    this.proxyPort,
  }) : _b4RoutingTable = b4RoutingTable;
  
  // //escaping is being done here so when we put /s in start and /e at end. 
  // //there should be no similar signs inside the message so to be safe we change the sign inside if any to // slash and change it back to normal when done
  // String escapeMessage(String message) {
  //   return message
  //       .replaceAll(r'\', r'\\') // escape backslash first
  //       .replaceAll(r'\S', r'\\S') // escape start marker
  //       .replaceAll(r'\E', r'\\E'); // escape end marker
  // }

  // //de-escaping is being done here
  // String unescapeMessage(String msg) {
  //   return msg
  //       .replaceAll(r'\\E', r'\E')
  //       .replaceAll(r'\\S', r'\S')
  //       .replaceAll(r'\\', r'\');
  // }


// //need to place below code wherever sending the message
// String fullJson = jsonEncode(finalTransportMessage);
// String escaped = escapeMessage(fullJson);
// String framed = r'\S' + escaped + r'\E';

// Uint8List encoded = Uint8List.fromList(utf8.encode(framed));
// socket.write(encoded);
/*
  double computeDistance(nodeid.NodeID localID, String remoteNodeID) {
    var localBigInt = BigInt.parse(localID.hashID, radix: 16);
    var remoteBigInt = BigInt.parse(remoteNodeID, radix: 16);
    return (localBigInt ^ remoteBigInt).toDouble();
  }
*/
  String _signPayloadContent(Map<String, dynamic> payload) {
    final contentToSign = jsonEncode(payload);
    var signature = CryptoUtils.ecSign(
      nodeID.keyp.privateKey,
      utf8.encode(contentToSign),
    );
    return jsonEncode({
      'r': signature.r.toString(),
      's': signature.s.toString(),
    });
  }
// what is not present here: connection to bootstrap,
//exchange of proxy tabels,
//finding own proxy node, registration at proxy ,
//set up tcp connection with proxy
//and tables maintained at proxy

  Future<void> sendMessage(
    String targetHash,
    Map<String, dynamic> logicalMessage,
    bool relayRequired, {
    bool useDHT = false,
    String? hashID,
  }) async {
    // Step 1: Determine next hop
    final nextHopNodeId = _b4RoutingTable.nextHop(
      targetHash,
      _b4RoutingTable.RoutingTable,

    );
    // useDHT: useDHT,

    // Step 2: Lookup node details
    final nextHopNode = _b4RoutingTable.findNode(nextHopNodeId, _b4RoutingTable.RoutingTable);
    if (nextHopNode == null) {
      print("No route to $targetHash");
      return;
    }

    // Step 3: Determine relay usage (override passed `relayRequired` if needed)
    final useRelay = nextHopNode.nodeID.natStatus != 0;

    // Step 4: Prepare endpoint
    //final ip = useRelay ? nextHopNode.endpointAddress.relayIP : nextHopNode.endpointAddress.directIP;
    final ip = useRelay ? nextHopNode.endpointAddress.publicipv4 : nextHopNode.endpointAddress.publicipv6;

    final port = useRelay
        ? nextHopNode.endpointAddress.publicipv4port
        : nextHopNode.endpointAddress.publicipv6port;
  //  final port = useRelay
  //      ? nextHopNode.endpointAddress.relayPort
  //      : nextHopNode.endpointAddress.directPort;
    if (ip == null || port == null) {
      print("Invalid endpoint information for node $nextHopNodeId");
      return;
    }

    // Step 5: Build signed message
    final signature = _signPayloadContent(logicalMessage);
    final signedPayload = {
      "type": logicalMessage["type"],
      "source_node_id": nodeID.hashID,
      "source_endpoint_address": endpoint.toJson(),
      "leaf_or_core": logicalMessage["leaf_or_core"] ?? "leaf",
      "layer_id": logicalMessage["layer_id"] ?? 1,
      "arguments": logicalMessage["arguments"],
      "signature": signature,
    };

    // Step 6: Wrap in DHT if needed using the MessageFactory
    final wrapped = MessageFactory.wrapDHTMessageIfNeeded(
      signedPayload,
      useDHT,
      hashID ?? targetHash,
    );

    // Step 7: Wrap in relay envelope if needed
    final transportMessage = MessageFactory.wrapTransportMessage(
      useRelay: useRelay,
      message: wrapped,
      hashID: nodeID.hashID,
    );

    // ---- AMENDMENT: Add endpoint address as header ----
    final endpointHeader = "$ip:$port";
    Map<String, dynamic> finaltransportMessage;
    if (useRelay) {
      finaltransportMessage = {
        'relay_endpoint': endpointHeader,
        ...transportMessage,
      };
    } else {
      finaltransportMessage = {
        'next_hop_endpoint': endpointHeader,
        ...transportMessage,
      };
    }
    // //need to place below code wherever sending the message
    // String fullJson = jsonEncode(finalTransportMessage);
    // String escaped = escapeMessage(fullJson);
    // String framed = r'\S' + escaped + r'\E';

    // Uint8List encoded = Uint8List.fromList(utf8.encode(framed));
    // socket.write(encoded);
    final fullJson = jsonEncode(finaltransportMessage);
    final encodedBytes = Uint8List.fromList(utf8.encode(fullJson));
    // Step 8: Establish TCP connection & send
    try {
      tcpConnection ??= TcpConnection(); // ✅ Use factory method
      await tcpConnection!.connect(ip, port); // Connect to target
      await tcpConnection!.send(
          "message",
          Uint8List.fromList(encodedBytes)
              as Socket); // Send data // ✅ Send as Uint8List
      print("✅ Message sent to $ip:$port via ${useRelay ? 'relay' : 'direct'}");
    } catch (e) {
      print("❌ Failed to send message to $ip:$port — $e");

    /* //_b4RoutingTable.removeNode(nextHopNodeId); */
    }
  }
}

// // import 'dart:math';
// // import 'dart:typed_data';
// // import 'package:convert/convert.dart';
// import 'package:b4_olm/index_mgr/messagefactory.dart';
// import 'package:basic_utils/basic_utils.dart';
// //import 'package:indexmgr/indexmgr.dart';
// //import 'package:sqlite3/sqlite3.dart';
// //import 'package:logging/logging.dart';
// //import 'package:b4auth/b4auth.dart';
// // import 'package:b4commgr/b4commgr.dart';
// //import 'package:b4commgr/networkInformation.dart';
// import 'package:b4connection/TcpConnection.dart';
// // import 'package:b4rttable/routingmanager.dart';
// import 'package:b4rttable/b4rttable.dart';
// //import 'package:b4commgr/webrtcmanager.dart';
// // import 'package:b4rttable/UpdateNodeID.dart';
// // import 'package:nodeid/nodeid.dart';
// import 'package:b4commgr/endpointAddress.dart';
// import 'package:nodeid/nodeid_base.dart' as nodeid;
// //import 'package:b4_olm/index_mgr/integrationindexmgr.dart';
// import 'dart:convert';
// import 'dart:io';
// import 'dart:async';

// class Node {
//   nodeid.NodeID nodeID;
//   EndpointAddress endpoint;
//   bool isBehindNAT;
//   String? proxyAddress;
//   int? proxyPort;
//   String? sessionKey;
//   TcpConnection? tcpConnection;
//   // final RoutingManager _routingManager;
//   final B4RoutingTable _b4RoutingTable;
//   Node({
//     required this.nodeID,
//     required this.endpoint,
//     // required RoutingManager routingManager,
//     required B4RoutingTable b4RoutingTable,
//     this.isBehindNAT = false,
//     this.proxyAddress,
//     this.proxyPort,
//   }) : _b4RoutingTable = b4RoutingTable;
//   // _routingManager = routingManager;

//   double computeDistance(nodeid.NodeID localID, String remoteNodeID) {
//     var localBigInt = BigInt.parse(localID.hashID, radix: 16);
//     var remoteBigInt = BigInt.parse(remoteNodeID, radix: 16);
//     return (localBigInt ^ remoteBigInt).toDouble();
//   }

//   String _signPayloadContent(Map<String, dynamic> payload) {
//     final contentToSign = jsonEncode(payload);
//     var signature = CryptoUtils.ecSign(
//       nodeID.keyp.privateKey,
//       utf8.encode(contentToSign),
//     );
//     return jsonEncode({
//       'r': signature.r.toString(),
//       's': signature.s.toString(),
//     });
//   }

// // helper functions for sending the message
// // this part looks after DHT vs non DHT messages
//   // Map<String, dynamic> _formatWrappedMessage(
//   //     Map<String, dynamic> logicalMessage, bool useDHT, String? hashID) {
//   //   if (useDHT) {
//   //     return {
//   //       "type": "DHT",
//   //       "hash_id": hashID,
//   //       "message": logicalMessage,
//   //     };
//   //   }
//   //   return logicalMessage;
//   // }

//   // String signMessage(String message) {
//   //   var messageBytes = utf8.encode(message);
//   //   var signature = CryptoUtils.ecSign(nodeID.keyp.privateKey, messageBytes);
//   //   return jsonEncode({
//   //     'message': message,
//   //     'signature': {
//   //       'r': signature.r.toString(),
//   //       's': signature.s.toString(),
//   //     }
//   //   });
//   // }

//   // Map<String, dynamic> _signPayload(Map<String, dynamic> payload) {
//   //   final signed = jsonDecode(signMessage(jsonEncode(payload)));
//   //   return {
//   //     "type": payload["type"],
//   //     "source_node_id": nodeID.hashID,
//   //     "destination_node_id": payload["destination_node_id"] ?? "",
//   //     "data": payload["message"] ?? payload["payload"] ?? payload,
//   //     "signature": signed["signature"]
//   //   };
//   // }

//   // /// this portion looks after relay part
//   // Map<String, dynamic> _buildTransportMessage(
//   //   Map<String, dynamic> signedPayload, {
//   //   required bool useRelay,
//   //   required bool isDHT,
//   //   String? hashID,
//   // }) {
//   //   if (useRelay) {
//   //     if (isDHT) {
//   //       return {
//   //         "relay": true,
//   //         "node_id": nodeID.hashID,
//   //         "type": "DHT",
//   //         "hash_id": hashID,
//   //         "message": signedPayload,
//   //       };
//   //     } else {
//   //       return {
//   //         "relay": true,
//   //         "node_id": nodeID.hashID,
//   //         ...signedPayload,
//   //       };
//   //     }
//   //   } else {
//   //     if (isDHT) {
//   //       return {
//   //         "relay": false,
//   //         "type": "DHT",
//   //         "hash_id": hashID,
//   //         "message": signedPayload,
//   //       };
//   //     } else {
//   //       return {
//   //         "relay": false,
//   //         ...signedPayload,
//   //       };
//   //     }
//   //   }
//   // }

// // this part of setting up a connection over tcp to the next node
// // will be taken from Mr Nagendra. we have the info about the relay
// // address from the routing table entry regarding the node.
//   // Future<void> _sendOverTCP({
//   //   required String message,
//   //   required bool useRelay,
//   //   String? relayIP,
//   //   int? relayPort,
//   //   String? destIP,
//   //   int? destPort,
//   // }) async {
//   //   try {
//   //     if (!useRelay && destIP != null && destPort != null) {
//   //       tcpConnection ??=
//   //           (await TcpConnection.connect(destIP, destPort)) as TcpConnection?;
//   //     } else if (useRelay && relayIP != null && relayPort != null) {
//   //       tcpConnection ??=
//   //           (await TcpConnection.connect(relayIP, relayPort)) as TcpConnection?;
//   //     }

//   //     tcpConnection?.send(message);
//   //     print("Sent message successfully.");
//   //   } catch (e) {
//   //     print(" Message send failed: $e");
//   //   }
//   // }

// // function for sending message
//   Future<void> sendMessage(
//     String targetHash,
//     Map<String, dynamic> logicalMessage,
//     bool useRelay, {
//     bool useDHT = false,
//     String? hashID,
//     String? relayIP,
//     int? relayPort,
//     String? destIP,
//     int? destPort,
//   }) async {
//     // 1. Get next hop from B4RoutingTable
//     final nextHopNodeId = _b4RoutingTable
//         .nextHop(targetHash, _b4RoutingTable.RoutingTable, useDHT: useDHT);

//     // 2. Find node details
//     final nextHopNode = _b4RoutingTable.findNode(
//         nextHopNodeId); // this findnode needs to be added in b4rttable or to be replaced with suitable function from b4rttable
//     if (nextHopNode == null) {
//       print("No route to $targetHash");
//       return;
//     }
//     // nodeid.NodeID? nextHopNode;
//     // for (final row in _b4RoutingTable.RoutingTable) {
//     //   for (final node in row) {
//     //     if (node != null && node.hashID == nextHopNodeId) {
//     //       nextHopNode = node as nodeid.NodeID?;
//     //       break;
//     //     }
//     //   }
//     //   if (nextHopNode != null) break;
//     // }

//     // if (nextHopNode == null) {
//     //   print("No route to $targetHash");
//     //   return;
//     // }

//     // 3. Determine relay requirement
//     final useRelay = nextHopNode.natStatus != 0;

//     // 4. Get endpoint from node metadata
//     final endpoint = useRelay
//         ? "${nextHopNode.relayIP}:${nextHopNode.relayPort}"
//         : "${nextHopNode.directIP}:${nextHopNode.directPort}";

//     // 5. Extract connection parameters
//     final (ip, port) =
//         _getConnectionParameters(useRelay, endpoint as EndpointAddress);
//     if (ip == null || port == null) {
//       print("No valid connection parameters found");
//       return;
//     }
//     // // Update routing info for useRelay
//     // final useRelay = routingDecision.requiresRelay;
//     // final selectedIP = routingDecision.endpoint.ip;
//     // final selectedPort = routingDecision.endpoint.port;

//     // if (useRelay) {
//     //   relayIP = selectedIP;
//     //   relayPort = selectedPort;
//     // } else {
//     //   destIP = selectedIP;
//     //   destPort = selectedPort;
//     // }

//     // // Step 1: Format message (DHT or non-DHT)
//     // final formatted = MessageFactory.wrapDHTMessageIfNeeded(logicalMessage, useDHT, hashID);

//     // // Step 2: Sign the message
//     // final signed = _signPayload(formatted);

//     // // Step 3: Construct transport message with proper headers
//     // final transportMessage =  MessageFactory.wrapTransportMessage(
//     //   useRelay: useRelay,
//     //   message: signedMessage,
//     //   relayIP: endpoint.ip,
//     //   relayPort: endpoint.port,
//     //   destIP: endpoint.ip,
//     //   destPort: endpoint.port,
//     // );

//     // 6. Apply DHT wrapping if needed
//     final dhtMessage = useDHT
//         ? MessageFactory.wrapDHTMessageIfNeeded(logicalMessage, true, hashID)
//         : logicalMessage;

//     // 7. Add signature
//     final signedMessage = {
//       ...dhtMessage,
//       'signature': _signPayloadContent(dhtMessage['payload']),
//       'source_node_id': nodeID.hashID,
//       'timestamp': DateTime.now().toIso8601String(),
//     };

//     // 8. Apply transport layer wrapping
//     final transportMessage = MessageFactory.wrapTransportMessage(
//       useRelay: useRelay,
//       message: signedMessage,
//       relayIP: ip,
//       relayPort: port,
//       destIP: ip,
//       destPort: port,
//     );
//     //  Step 9: Send over TCP to relay or next-hop node

//     // 9(a). Prepare the message as a string
//     String messageToSend = jsonEncode(transportMessage);

//     // 9(b). Create an instance of TcpConnection
//     TcpConnection tcpConnection = TcpConnection();

//     // 9(c). Connect and get the Socket (do NOT call as static)
//     Socket? socket = await tcpConnection.connect(ip, port);

//     if (socket == null) {
//       print("Could not connect to $ip:$port");
//       return;
//     }

//     // 9(d). Send the message using the TcpConnection instance
//     await tcpConnection.send(messageToSend, socket);

//     print("Message sent to $ip:$port");
//   }

//   //   // 7. Send over TCP
//   //   try {
//   //     final connection =
//   //         await TcpConnection.connect(ip, port);
//   //     connection.send(jsonEncode(transportMessage));
//   //     print("Message sent via ${useRelay ? 'relay' : 'direct'} connection");
//   //   } catch (e) {
//   //     print("Message send failed: $e");
//   //     // Implement retry logic here if needed
//   //   }
//   // }
//   (String?, int?) _getConnectionParameters(
//       bool useRelay, EndpointAddress endpoint) {
//     if (useRelay) {
//       // Prefer IPv4 proxy first
//       if (endpoint.proxyipv4 == true) {
//         return (endpoint.publicipv4, endpoint.publicipv4port);
//       }
//       // Fallback to IPv6 proxy
//       if (endpoint.proxyipv6 == true) {
//         return (endpoint.publicipv6, endpoint.publicipv6port);
//       }
//     } else {
//       // Prefer direct IPv4 connection
//       if (endpoint.publicipv4 != null) {
//         return (endpoint.publicipv4, endpoint.publicipv4port);
//       }
//       // Fallback to direct IPv6 connection
//       if (endpoint.publicipv6 != null) {
//         return (endpoint.publicipv6, endpoint.publicipv6port);
//       }
//     }
//     return (null, null);
//   }
// }
//   // Future<void> _sendOverTCP({
//   //   required String message,
//   //   required String ip,
//   //   required int port,
//   // }) async {
//   //   tcpConnection ??= (await TcpConnection.connect(ip, port)) as TcpConnection?;
//   //   tcpConnection?.send(message);
//   // }
