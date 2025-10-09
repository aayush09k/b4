// Importing core libraries
import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io';

// Importing libraries from external packages
import 'package:basic_utils/basic_utils.dart';
import 'package:path/path.dart' as p;

// Importing libraries from our packages
import 'package:nodeid/nodeid.dart';
import 'package:b4commgr/b4commgr.dart';
import 'package:b4rttable/b4rttable.dart';
import 'package:b4utils/bufferdata.dart';
import 'package:b4utils/connectivity_monitor.dart';
import 'package:b4commgr/endPointAddress.dart';
//import 'package:b4rttable/config.dart';

class RoutingManager {

  String? filePath; // Get file path from AppConfig.
  String? receiveMessage;
  String? rtFilePath; //
  int? natStatus;
  int? layers;
  late Node _localNode;
  Map<String, B4RoutingTable> routingTables = {};

  /*
    0 - Base layer
    1 - IPv4 non-NATed layer
    2 - IPv6 non-NATed layer
    3 - IPv4/IPv6 dual stack non-NATed layer
    4 - file storage layer
    5 - file storage reputation layer
    */

  Map<String, B4RoutingTable> neighbourTables = {};
  Map<String, B4RoutingTable> latLongTables = {};
  CommunicationManager manager = CommunicationManager();
  ConnectivityMonitor monitor = ConnectivityMonitor();
  DataBuffer dataBuffer = DataBuffer();

  bool flag = false;

  RoutingManager._internal(String filePath,int layers,int port, String nodeId,dynamic nodeIdSign, dynamic nodeIdPubK, dynamic publicIpv4, dynamic publicIpv6, dynamic localIpv4, Map bsNode) {
    rtFilePath = "${filePath}rtTable.json"; // the path where routing table file will be stored as json.
    // comment the code 
    //_localNodeID = LocalNodeID();
    _localNode.nodeID.hashID = nodeId;
    _localNode.nodeID.pubKey=nodeIdPubK;
    _localNode.nodeID.sign=nodeIdSign;

    //_localNodeID.nodeid.listeningPort = port;

    layers=layers;
//flag for bootstrap
    if (flag == true) {
      // we have to get this from auth manager, for testing change this ib b4rtTable class also at line no. 30
      // Call the init() function when the instance is created
   //   _localNodeID.nodeid.sign =nodeIdSign;
      _localNode.nodeID.publicKeyPem ="-----BEGIN PUBLIC KEY-----\n${nodeIdPubK}\n-----END PUBLIC KEY-----";
      _localNode.endpointAddress.publicipv4 = publicIpv4;
      _localNode.endpointAddress.publicipv4port = port;
      _localNode.endpointAddress.publicipv6 = publicIpv6;
      _localNode.endpointAddress.publicipv6port=port;
      _localNode.endpointAddress.proxyipv4=true;
      _localNode.endpointAddress.proxyipv6=false;
      _localNode.endpointAddress.protocol="TCP";

    }
//the above code  for setting the bootstrap node id
    init(rtFilePath!, layers, bsNode);
  }

  Node get localNode => _localNode;
 // LocalNodeID get localNodeID => _localNodeID;
  static RoutingManager? _instance;
  // Getter to access the singleton instance
factory RoutingManager(String filePath,int layers,int port, String nodeId, dynamic nodeIdSign, dynamic nodeIdPubK, dynamic publicIpv4, dynamic publicIpv6, dynamic localIpv4, Map bsNode) {
  _instance ??= RoutingManager._internal(filePath, layers, port, nodeId, nodeIdSign, nodeIdPubK, publicIpv4, publicIpv6, localIpv4, bsNode);
  return _instance!;
  }



  Future<void> init(String filePath, int layers, Map bsNode) async {
    // Check if the file exists;
    NodeID? bootStrapNodeID;

    if (File(filePath).existsSync()) {

      // Perform actions related to the existing file,check liveliness of nodes.
    } else {

      for (int i = 0; i <= layers; i++) {
        routingTables[i.toString()] = B4RoutingTable(_localNode.nodeID as LocalNodeID?);
      }
    }

    // Skip as flag=true for botsTrapNode.
    if (flag == false) {
      bootStrapNodeID = NodeID.createFromTable(
      bsNode['bSPublicKeyPem'],
      bsNode['bSNodeIdSign'],
      bsNode['bSHash'],
      bsNode['bSPub'],
      bsNode['bSIP4'],
      bsNode['bSPublicIpv4'],
      bsNode['bSPublicIpv6'],
      bsNode['bSnatStatus'],
      bsNode['bSPort'],
      bsNode['bSpublicIpv4Port'],
      bsNode['bSpublicIpv6Port'],
      bsNode['bSCommunicatorIP'],
      bsNode['bSCommunicatorPort'],
      bsNode['bSListeningPort']);
    }

    // not required this can be taken place when socket opens in com mgr
    if (flag == true) {
      //  manager.activateNode(null, null, localNodeID.nodeid.listeningPort, 1, null,null);
    }

    // un comment this line for normal nodes.This line will remain comment for bootstrap.
    if (flag == false) {

    //  await manager.activateNode(bootStrapNodeID!.publicIpv4,bootStrapNodeID.listeningPort,localNodeID.nodeid.listeningPort, natStatus, bootStrapNodeID.hashID,null); // hard code boots
      await Future.delayed(const Duration(seconds: 3));
      await sendMessageRM(
          'RM',
          "D",
          localNodeID.nodeid,
          "hashID",
          "s",
          "current",
          "natStatus",
          bootStrapNodeID!,
          "myEndpoint",
          "0",
          'Y');
    }

    checkForMessagesCMExecution();
    Timer.periodic(const Duration(minutes: 5),
            (Timer t) => sendPeriodicUpdate(routingTables["0"]!.RoutingTable));
  }

  String createMessageRM(String rM,
      String reLay,
      NodeID myNodeID,
      String hashID,
      String s,
      String current,
      String R,
      NodeID nodeID,
      String myEndpoint,
      String layerID,
      String reqRT) {
    List<List<Map<String, dynamic>?>> jsonRT =
    routingTables[layerID]!.RoutingTable.map((innerList) {
      return innerList.map((nodeID) {
        if (nodeID != null) {
          return {
            'hashID': nodeID.hashID,
            'publicKey': {'x': CryptoUtils
                .ecPublicKeyFromPem(nodeID.publicKeyPem.toString())
                .Q!
                .x!
                .toBigInteger()!
                .toRadixString(16),
              'y': CryptoUtils
                  .ecPublicKeyFromPem(nodeID.publicKeyPem.toString())
                  .Q!
                  .y!
                  .toBigInteger()!
                  .toRadixString(16),
            },
            'sign': {'r': nodeID.sign.r.toString(),
              's': nodeID.sign.s.toString()},
            'publicKeyPem': nodeID.publicKeyPem.toString(),
            'localIpv4': nodeID.localIpv4.toString(),
            'publicIpv4': nodeID.publicIpv4.toString(),
            'publicIpv6': nodeID.localIpv4.toString(),
            'natStatus': nodeID.natStatus.toString(),
            'localIpv4Port': nodeID.localIpv4Port.toString(),
            'publicIpv4Port': nodeID.publicIpv4Port.toString(),
            'publicIpv6Port': nodeID.publicIpv6Port.toString(),
            'communicatorIP': nodeID.publicIpv6Port.toString(),
            'communicatorPort': nodeID.communicatorPort.toString(),
            'listeningPort': nodeID.listeningPort.toString(),

          };
        } else {
          return null;
        }
      }).toList();
    }).toList();

    Map<String, dynamic> jsonNodeIdToSend = {
      'hashID': nodeID.hashID,
      'publicKey': {'x': CryptoUtils
          .ecPublicKeyFromPem(nodeID.publicKeyPem.toString())
          .Q!
          .x!
          .toBigInteger()!
          .toRadixString(16),
        'y': CryptoUtils
            .ecPublicKeyFromPem(nodeID.publicKeyPem.toString())
            .Q!
            .y!
            .toBigInteger()!
            .toRadixString(16),
      },
      'sign': {'r': nodeID.sign.r.toString(),
        's': nodeID.sign.s.toString()},
      'publicKeyPem': nodeID.publicKeyPem.toString(),
      'localIpv4': nodeID.localIpv4.toString(),
      'publicIpv4': nodeID.publicIpv4.toString(),
      'publicIpv6': nodeID.localIpv4.toString(),
      'natStatus': nodeID.natStatus.toString(),
      'localIpv4Port': nodeID.localIpv4Port.toString(),
      'publicIpv4Port': nodeID.publicIpv4Port.toString(),
      'publicIpv6Port': nodeID.publicIpv6Port.toString(),
      'communicatorIP': nodeID.publicIpv6Port.toString(),
      'communicatorPort': nodeID.communicatorPort.toString(),
      'listeningPort': nodeID.listeningPort.toString(),

    };
    String jsonNodesString = jsonEncode(jsonRT);
    String jsonStringNodeToSend = jsonEncode(jsonNodeIdToSend);

    Map<String, dynamic> jsonMyNodeId = {
      'hashID': myNodeID.hashID,
      'publicKey': {'x': CryptoUtils
          .ecPublicKeyFromPem(myNodeID.publicKeyPem.toString())
          .Q!
          .x!
          .toBigInteger()!
          .toRadixString(16),
        'y': CryptoUtils
            .ecPublicKeyFromPem(myNodeID.publicKeyPem.toString())
            .Q!
            .y!
            .toBigInteger()!
            .toRadixString(16),
      },
      'sign': {'r': myNodeID.sign.r.toString(),
        's': myNodeID.sign.s.toString()},
      'publicKeyPem': myNodeID.publicKeyPem.toString(),
      'localIpv4': myNodeID.localIpv4.toString(),
      'publicIpv4': myNodeID.publicIpv4.toString(),
      'publicIpv6': myNodeID.localIpv4.toString(),
      'natStatus': myNodeID.natStatus.toString(),
      'localIpv4Port': myNodeID.localIpv4Port.toString(),
      'publicIpv4Port': myNodeID.publicIpv4Port.toString(),
      'publicIpv6Port': myNodeID.publicIpv6Port.toString(),
      'communicatorIP': myNodeID.publicIpv6Port.toString(),
      'communicatorPort': myNodeID.communicatorPort.toString(),
      'listeningPort': myNodeID.listeningPort.toString(),
    };

    String jsonStringMyNode = jsonEncode(jsonMyNodeId);

    // Convert to JSON String

    Map<String, dynamic> messageRM = {
      'RM': "RM",
      'Relay': "R",
      'myNodeID': jsonStringMyNode,
      'hashID': hashID,
      's': "s",
      'current': current,
      'R': "R",
      'nodeID': jsonStringNodeToSend,
      'myEndpoint': myEndpoint,
      'reqRT': reqRT,
      'layerID': layerID,
      'RT': jsonNodesString,
    };

    String jsonMessageRM = jsonEncode(messageRM);
    return jsonMessageRM;
  }

  Future<void> sendMessageRM(String rM,
      String reLay,
      NodeID myNodeID,
      String hashID,
      String s,
      String current,
      String n,
      NodeID nodeIDtoSend,
      String myEndpoint,
      String layerID,
      String reqRT) async {
    String message;

    message = createMessageRM(
        rM,
        reLay,
        myNodeID,
        hashID,
        s,
        current,
        "$natStatus",
        nodeIDtoSend,
        myEndpoint,
        layerID,
        reqRT
    );


    if (nodeIDtoSend.natStatus == 0) {
     await  manager.communicate(
          nodeIDtoSend.localIpv4,
          nodeIDtoSend.listeningPort,
          "D",
          message,
          nodeIDtoSend.hashID);
    } else {

      int? port;
      String? ip;
      if (nodeIDtoSend.natStatus != 0) {
        if (nodeIDtoSend.publicIpv6 == null) {
          ip = nodeIDtoSend.publicIpv4;
          port = nodeIDtoSend.publicIpv4Port;
        } else {
          ip = nodeIDtoSend.publicIpv6;
          port = nodeIDtoSend.publicIpv6Port;
        }
       await  manager.communicate(
            ip, port, "D", message, nodeIDtoSend.hashID);
      }
        }


    // await Future.delayed(Duration(milliseconds: 500));
    //  checkForMessagesCMExecution();
  }

  Future<void> rMessageRM(dynamic rcvdMessage) async {
    Map<String, dynamic> decodedMessageRM = jsonDecode(rcvdMessage);

    String senderNodeID = decodedMessageRM['myNodeID'];
    String reqRT = decodedMessageRM['reqRT'];
    String layerID = decodedMessageRM['layerID'];
    String rT = decodedMessageRM['RT'];

// This part of code is written to take senders node and update it because that will be not part of it's own routing table.

    Map<String, dynamic> jsonNodeid = jsonDecode(senderNodeID);
    ECSignature? signNode = ECSignature(BigInt.parse(jsonNodeid['sign']['r']),
        BigInt.parse(jsonNodeid['sign']['s']));
    NodeID sendersNodeID = NodeID.createFromTable(
      jsonNodeid['publicKeyPem'],
      // Assuming this is how you reconstruct pubKey
      signNode,
      jsonNodeid['hashID'],
      // Assuming this is how you reconstruct sign
      CryptoUtils.ecPublicKeyFromPem(jsonNodeid['publicKeyPem']),
      jsonNodeid['localIpv4'],
      jsonNodeid['publicIpv4'],
      jsonNodeid['publicIpv6'],
      int.tryParse(jsonNodeid['natStatus']),
      int.tryParse(jsonNodeid['localIpv4Port']),
      int.tryParse(jsonNodeid['publicIpv4Port']),
      int.tryParse(jsonNodeid['publicIpv6Port']),
      jsonNodeid['communicatorIP'],
      int.tryParse(jsonNodeid['communicatorPort']),
      int.parse(jsonNodeid['listeningPort']),
    );
    routingTables[layerID]!.updateNodeID(sendersNodeID,
        const Duration(milliseconds: 300), routingTables[layerID]!.RoutingTable);

    List<dynamic> decodedRT = jsonDecode(rT);

    List<List<NodeID?>> nodeList = decodedRT.map((innerList) {
      return (innerList as List<dynamic>).map((jsonNode) {
        if (jsonNode != null) {
          ECSignature? sign = ECSignature(BigInt.parse(jsonNode['sign']['r']),
              BigInt.parse(jsonNode['sign']['s']));
          return NodeID.createFromTable(
            jsonNode['publicKeyPem'],
            // Assuming this is how you reconstruct pubKey
            sign,
            jsonNode['hashID'],
            // Assuming this is how you reconstruct sign
            jsonNode['pubKey'],
            jsonNode['localIpv4'],
            jsonNode['publicIpv4'],
            jsonNode['publicIpv6'],
            int.tryParse(jsonNode['natStatus']),
            int.tryParse(jsonNode['localIpv4Port']),
            int.tryParse(jsonNode['publicIpv4Port']),
            int.tryParse(jsonNode['publicIpv6Port']),
            jsonNode['communicatorIP'],
            int.tryParse(jsonNode['communicatorPort']),
            int.parse(jsonNode['listeningPort']),
          );
        } else {
          return null;
        }
      }).toList();
    }).toList();
    routingTables[layerID]!
        .updateRtTable( nodeList);
    print("updated table");
    print(routingTables[layerID]!.RoutingTable);

    if (reqRT == 'Y') {
      await sendMessageRM(
          'RM',
          "D",
          localNodeID.nodeid,
          "hashID",
          "s",
          "current",
          "R",
          sendersNodeID,
          "myEndpoint",
          "0",
          'N');
    }
    if (reqRT == 'P') {
      for (int i = 0; i < 40; i++) {
        if (sendersNodeID.hashID.split('') !=
            localNodeID.nodeid.hashID.split('')[i]) {
          if (!((nodeList[0][i] != null &&
              nodeList[0][i]!.hashID == localNodeID.nodeid.hashID) ||
              (nodeList[1][i] != null &&
                  nodeList[1][i]!.hashID == localNodeID.nodeid.hashID) ||
              (nodeList[2][i] != null &&
                  nodeList[2][i] == localNodeID.nodeid.hashID))) {
            await sendMessageRM(
                'RM',
                "D",
                localNodeID.nodeid,
                "hashID",
                "s",
                "current",
                "R",
                sendersNodeID,
                "myEndpoint",
                "0",
                'N');
            i = 40;
          }
        }
      }
    }
  }

  Future<void> checkForMessagesCMExecution() async {
    const duration = Duration(seconds: 2); // Adjust duration as needed
    Timer.periodic(duration, (timer) {
      // This function will be executed periodically
      handleForMessages();
    });
  }

  Future<void> handleForMessages() async {
    //dynamic messageFromCMBuffer = dataBuffer.pullIntemp();
    dynamic messageFromCMBuffer = dataBuffer.pullrmBuffer();
    print(messageFromCMBuffer);
    if (messageFromCMBuffer != null) {
      Map<String, dynamic> decodedMessageRM = jsonDecode(messageFromCMBuffer);
      String rM = decodedMessageRM['RM'];

      if (rM != 'RM') {
        dataBuffer.pushrmBuffer(messageFromCMBuffer);
      } else {
        rMessageRM(messageFromCMBuffer);
      }
    } else {
      // In RM buffer messsage is null
      await Future.delayed(Duration(seconds: 20));
    }
  }

  B4RoutingTable? getFullRT(String layerID) {
    return routingTables[layerID];
  }

  void mergeTables(List<List<Node?>> newRoutingTable, String layerId) {
    List<List<Node?>> localRT = routingTables[layerId]!.RoutingTable;

    routingTables[layerId]!.updateRtTable( newRoutingTable);
  }

  void sendPeriodicUpdate(List<List<NodeID?>> rtTable) {
    for (int i = 0; i <= 39; i++) {
      for (int j = 0; j <= 39; j++) {
        if (rtTable[i][j] != null) {
          if (rtTable[i][j]!.natStatus == 0) {
            String message = createMessageRM(
                "RM",
                "Relay",
                localNodeID.nodeid,
                "hashID",
                "s",
                "current",
                "R",
                rtTable[i][j]!,
                "myEndpoint",
                "0",
                "P");
            manager.communicate(
                rtTable[i][j]!.communicatorIP,
                rtTable[i][j]!.communicatorPort,
                "TP",
                message,
                rtTable[i][j]!.hashID);
          } else {
            if (rtTable[i][j] != null) {
              int? port;
              String? ip;
              if (rtTable[i][j]!.natStatus != 0) {
                String message = createMessageRM(
                    "RM",
                    "Relay",
                    localNodeID.nodeid,
                    "hashID",
                    "s",
                    "current",
                    "R",
                    rtTable[i][j]!,
                    "myEndpoint",
                    "0",
                    "P");
                if (rtTable[i][j]!.publicIpv6 == null) {
                  ip = rtTable[i][j]!.publicIpv4;
                  port = rtTable[i][j]!.publicIpv4Port;
                } else {
                  ip = rtTable[i][j]!.publicIpv6;
                  port = rtTable[i][j]!.publicIpv6Port;
                }
                manager.communicate(
                    ip, port, "D", message, rtTable[i][j]!.hashID);
              }
            }
          }
        }
      }
    }
  }

  void checkNodeAliveness(){

  print("code is there");


  }

  bool checkRTTableForSpoof(List<List<Node?>> rtTable, String node) {
    List<String> nodeIdC = node.split('');
    bool flag = true;
    for (int i = 0; i <= 2; i++) {
      for (int j = 0; j <= 39; j++) {
        if (rtTable[i][j] != null) {
          List<String> tableNodeIdC = rtTable[i][j]!.nodeID.hashID.split('');
          if (j == 0) {
            if (nodeIdC[0] == tableNodeIdC[0]) {
              flag = false;
              i = 3;
              j = 40;
            }
          } else {
            for (int k = j - 1; k >= 0; k--) {
              if (nodeIdC[k] != tableNodeIdC[k]) {
                flag = false;
                i = 3;
                j = 40;
              }
            }
          }
        }
      }
    }
    return flag;
  }

  Future<void> createRoutingTableAtPath(String path,int layers, dynamic nodeId) async {
    try {
      // Ensure the directory exists
      final directory = Directory(p.dirname(path));
      // Get the parent directory of the given path
      if (!directory.existsSync()) {
        directory.createSync(
            recursive: true); // Create the directory if it doesn't exist
        print("Directory created: ${directory.path}");
      }

      // Create the routing table
      //
      //B4RoutingTable newRoutingTable = B4RoutingTable(localNodeID);
      for (int i = 0; i <= layers; i++) {
        //print("$i ......");
        routingTables[i.toString()] = B4RoutingTable(localNodeID);
      }
      print(routingTables);

      // Assuming nodeId is part of the localNodeID and can be accessed as _localNodeID.nodeid.hashID
      //  String nodeId = _localNodeID.nodeid.hashID;

      // Create a 3x40 matrix (for example purposes, we'll populate it with dummy values)
      List<List<int>> matrix =
      List.generate(3, (i) => List.generate(40, (j) => i * j));

    //  List<String> head = globals.nodeId.toString().split('');
      List<String> head = nodeId.toString().split('');

      // Create a JSON object that includes the nodeId and matrix
      Map<String, dynamic> routingTableJson = {
        'header': head, // Add nodeId as the header
        'routingTable': matrix, // Add the 3x40 matrix
      };

      // Convert the routing table to JSON
      String jsonContent = jsonEncode(routingTableJson);

      // Ensure the file path ends with 'rtTable.json'
      String filePathWithJsonExtension =
      path.endsWith('rtTable.json') ? path : '$path\\rtTable.json';

      // Write the routing table to the file
      File file = File(filePathWithJsonExtension);
      await file.writeAsString(jsonContent);

      print("Routing table created at: $filePathWithJsonExtension");

      // Optionally add it to the in-memory routing tables map
      String key = p.basenameWithoutExtension(
          filePathWithJsonExtension); // Use the file name as the key
      routingTables[key] = routingTables as B4RoutingTable;
    } catch (e) {
      print("Error creating routing table at path $path: $e");
    }
  }



}
