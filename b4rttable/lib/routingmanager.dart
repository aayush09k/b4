import 'dart:async';
import 'dart:convert';
import 'package:b4rttable/b4rttable.dart';
import 'dart:io';
import 'package:nodeid/nodeid.dart';
import 'package:b4rttable/config.dart';
import 'package:b4commgr/b4commgr.dart';
import 'package:b4utils/bufferdata.dart';
import 'package:b4utils/connectivity_monitor.dart';
import 'package:basic_utils/basic_utils.dart';

class RoutingManager {
  String filePath = AppConfig.filepath; // Get file path from AppConfig.
  String? rcvdMessage;
  String? RTfilepath; //
  int? natStatus;
  int layers = AppConfig.numberOfLayers;
  late LocalNodeID _localNodeID;
  Map<String, B4RoutingTable> routingTables = {};
  /*
    0 - Base layer
    1 - IPv4 non-nated layer
    2 - IPv6 non-nated layer
    3 - IPv4/IPv6 dual stack non-nated layer
    4 - file storage layer
    5 - file storage reputation layer
    */
  Map<String, B4RoutingTable> neighbourTables = {};
  Map<String, B4RoutingTable> latlongTables = {};
  CommunicationManager manager = CommunicationManager();
  DataBuffer dataBuffer = DataBuffer();
  ConnectivityMonitor monitor =ConnectivityMonitor();

  RoutingManager._() {
    RTfilepath =
        "${filePath}rttable.json"; // the path where routing table file will be stored as json.
    _localNodeID = LocalNodeID();
    _localNodeID.nodeid.hashID = "62D67DFC3E4616381DACA70A90CDF3C59EA80D32"; // we have to get this from auth manager, for testing change this ib b4rttable class also at line no. 30
    // Call the init() function when the instance is created
    _localNodeID.nodeid.sign=ECSignature(BigInt.parse("65470513412405851950885404129427616067309932491674362141979488612896203164025"), BigInt.parse("35241799610163012077198311829834117378791561246876962545184629718444186922890"));
   _localNodeID.nodeid.publicKeyPem="-----BEGIN PUBLIC KEY-----\nMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEr8xH1as9ZYF2t+Bc6iQVBNtB4WxK\nUBlQ5sX9oBpTSrTdS39R2c8W4r/Wq/fXNHk+df5uig06vSozEnADHgY8xQ==\n-----END PUBLIC KEY-----" ;
   _localNodeID.nodeid.pubKey= CryptoUtils.ecPublicKeyFromPem(_localNodeID.nodeid.publicKeyPem);
   _localNodeID.nodeid.publicIpv4="103.246.106.197";
   _localNodeID.nodeid.natStatus=null;
   _localNodeID.nodeid.listeningPort=22801;
   _localNodeID.nodeid.publicIpv6="";
   _localNodeID.nodeid.localIpv4="172.20.160.56";
   init();
  }
  LocalNodeID get localNodeID => _localNodeID;
  // Getter to access the singleton instance
  static RoutingManager get instance {
    _instance ??= RoutingManager._();
    return _instance!;
  }

  static RoutingManager? _instance;
  Future<void> init() async {
    // Check if the file exists

    if (File(filePath).existsSync()) {
      print('File exists.');
      // Perform actions related to the existing file,check liveliness of nodes.
    } else {
      print('File does not exist.');
      for (int i = 0; i <= layers; i++) {
        routingTables[i.toString()] = B4RoutingTable(localNodeID);
      }
    }
  //  await geTinFormation();
   // int? natStatus = localNodeID.nodeid.natStatus;
    manager.activateNode(null, null, localNodeID.nodeid.listeningPort, 1, null);

    // if (natStatus == 0) {
    //   manager.activateNode("bootstrapIP", "Bootport", null, natStatus,"62D67DFC3E4616381DACA70A90CDF3C59EA80D32"); // hard code boots
    // } else {
    //   manager.activateNode(null, null, localNodeID.nodeid.listeningPort, natStatus, null); it is already public
    // }

    // un comment this line for normal nodes.This line will reamin comment for bootstrap.
    // await sendmessageRM('RM', "Relay", localNodeID.nodeid, "hashID", "s",
    //     "current", "natStatus", "nodeID", "myEndpoint", "0", 'Y');

    checkForMessagesCMExecution();
    Timer.periodic(Duration(minutes: 5),
            (Timer t) => sendPeriodicUpdate(routingTables["0"]!.RoutingTable));
  }

  String createMessageRM(
      String RM,
      String Relay,
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

            // old code, for nodeID
            // 'hashID': nodeID.hashID,
            // 'publicKey': nodeID.pubKey.toString(),
            // 'sign': {
            //   'r': nodeID.sign.r.toString(),
            //   's': nodeID.sign.s.toString()
            // },
            // 'publicKeyPem': nodeID.publicKeyPem.toString(),

            'hashID': nodeID.hashID,
            'publicKey': nodeID.pubKey.toString(),
            'sign':{'r':nodeID.sign.r.toString(),
              's':nodeID.sign.s.toString()},
            'publicKeyPem':nodeID.publicKeyPem.toString(),
            'localIpv4':nodeID.localIpv4.toString(),
            'publicIpv4':nodeID.publicIpv4.toString(),
            'publicIpv6':nodeID.localIpv4.toString(),
            'natStatus':nodeID.natStatus.toString(),
            'localIpv4Port':nodeID.localIpv4Port.toString(),
            'publicIpv4Port':nodeID.publicIpv4Port.toString(),
            'publicIpv6Port':nodeID.publicIpv6Port.toString(),
            'communicatorIP':nodeID.publicIpv6Port.toString(),
            'communicatorPort':nodeID.communicatorPort.toString(),
            'listeningPort':nodeID.listeningPort.toString(),

          };
        } else {
          return null;
        }
      }).toList();
    }).toList();

    Map<String, dynamic> jsonMyNode = {
      'pubKey': myNodeID.pubKey.toString(),
      'hashID': myNodeID.hashID.toString(),
      'sign': {
        'r': myNodeID.sign.r.toString(),
        's': myNodeID.sign.s.toString()
      }, // Replace this with actual ECSignature JSON
      'publicKeyPem': myNodeID.publicKeyPem.toString(),

      'hashID': myNodeID.hashID,
      'publicKey': myNodeID.pubKey.toString(),
      'sign':{'r':myNodeID.sign.r.toString(),
        's':myNodeID.sign.s.toString()},
      'publicKeyPem':myNodeID.publicKeyPem.toString(),
      'localIpv4':myNodeID.localIpv4.toString(),
      'publicIpv4':myNodeID.publicIpv4.toString(),
      'publicIpv6':myNodeID.localIpv4.toString(),
      'natStatus':myNodeID.natStatus.toString(),
      'localIpv4Port':myNodeID.localIpv4Port.toString(),
      'publicIpv4Port':myNodeID.publicIpv4Port.toString(),
      'publicIpv6Port':myNodeID.publicIpv6Port.toString(),
      'communicatorIP':myNodeID.publicIpv6Port.toString(),
      'communicatorPort':myNodeID.communicatorPort.toString(),
      'listeningPort':myNodeID.listeningPort.toString(),


    };

    String jsonStringMyNode = jsonEncode(jsonMyNode);

    // Convert to JSON String
    String jsonNodesString = jsonEncode(jsonRT);
    Map<String, dynamic> messageRM = {
      'RM': "RM",
      'Relay': "R",
      'myNodeID': jsonStringMyNode,
      'hashID': hashID,
      's': "s",
      'current': current,
      'R': "R",
      'nodeID': nodeID,
      'myEndpoint': myEndpoint,
      'reqRT': reqRT,
      'layerID': layerID,
      'RT': jsonNodesString,
    };

    String jsonMessageRM = jsonEncode(messageRM);
    return jsonMessageRM;
  }



  Future<void> geTinFormation() async {
    monitor.onConnectivityChanged.listen((interfaces) async {
      print('Network interfaces changed:');
      natStatus =
          await manager.getNetworkInformation("stun.l.google.com", 19302);
      InternetAddress? Ipl = await manager.stunClient.getLocalIPv4();
      InternetAddress? Ip4 = await manager.stunClient.getPublicIPv4();
      InternetAddress? Ip6 = await manager.stunClient.getPublicIPv6();
      localNodeID.nodeid.localIpv4 = Ipl as String;
      localNodeID.nodeid.publicIpv6 = Ip6 as String;
      localNodeID.nodeid.publicIpv4 = Ip4 as String;
      localNodeID.nodeid.natStatus = natStatus;
      for (var interface in interfaces) {
        print('Interface name: ${interface.name}');
        print('Addresses: ${interface.addresses}');
      }
    });
  }

  Future<void> sendmessageRM(
      String RM,
      String Relay,
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

    message = createMessageRM(RM, Relay, myNodeID, hashID, s, current,
        "${natStatus}", nodeIDtoSend, myEndpoint, layerID, reqRT);

    // await manager.sendMessage("35.185.142.164", 22355, "D", "hello psj", "google");

    // await manager.sendMessage("35.185.142.164", 22355, "D", message, "google");
    if (nodeIDtoSend!.natStatus == 0) {

      manager.communicate(
          nodeIDtoSend!.communicatorIP,
          nodeIDtoSend.communicatorPort,
          "TP",
          message,
          nodeIDtoSend!.hashID);
    } else {
      if (nodeIDtoSend!= null) {
        int? port;
        String? ip;
        if (nodeIDtoSend.natStatus != 0) {

          if (nodeIDtoSend.publicIpv6 == null) {
            ip = nodeIDtoSend.publicIpv4;
            port = nodeIDtoSend.publicIpv4Port;
          } else {
            ip = nodeIDtoSend.publicIpv6;
            port =nodeIDtoSend.publicIpv6Port;
          }
          manager.communicate(
              ip, port, "D", message, nodeIDtoSend.hashID);
        }
      }
    }


    // await Future.delayed(Duration(milliseconds: 500));
    //  checkForMessagesCMExecution();
  }

  Future<void> rMessageRM(dynamic rcvdMessage) async {
    Map<String, dynamic> decodedMessageRM = jsonDecode(rcvdMessage);
    String RM = decodedMessageRM['RM'];
    String Relay = decodedMessageRM['Relay'];
    String senderNodeID = decodedMessageRM['myNodeID'];
    String hashID = decodedMessageRM['hashID'];
    String s = decodedMessageRM['s'];
    String current = decodedMessageRM['current'];
    String R = decodedMessageRM['R'];
    String nodeID = decodedMessageRM['nodeID'];
    String Endpoint = decodedMessageRM['myEndpoint'];
    String reqRT = decodedMessageRM['reqRT'];
    String layerID = decodedMessageRM['layerID'];
    String RT = decodedMessageRM['RT'];

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
      jsonNodeid['pubKey'],
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
        Duration(milliseconds: 300), routingTables[layerID]!.RoutingTable);

    List<dynamic> decodedRT = jsonDecode(RT);

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
        .updateRtTable(routingTables[layerID]!.RoutingTable, nodeList);
    print("updated node id is");
    print(routingTables[layerID]!.RoutingTable);

    if (reqRT == 'Y') {
      await sendmessageRM('RM', "D", localNodeID.nodeid, "hashID", "s",
          "current", "R", sendersNodeID, "myEndpoint", "0", 'N');
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
            await sendmessageRM('RM', "D", localNodeID.nodeid, "hashID", "s",
                "current", "R",sendersNodeID, "myEndpoint", "0", 'N');
            i = 40;
          }
        }
      }
    }
  }

  Future<void> checkForMessagesCMExecution() async {
    const duration = Duration(seconds: 5); // Adjust duration as needed
    Timer.periodic(duration, (timer) {
      // This function will be executed periodically

      handleForMessages();
    });
  }

  void handleForMessages() {
    dynamic messageFromCMBuffer = dataBuffer.pull();
    print(messageFromCMBuffer);

    if (messageFromCMBuffer != null) {
      Map<String, dynamic> decodedMessageRM = jsonDecode(messageFromCMBuffer);
      String RM = decodedMessageRM['RM'];

      if (RM != 'RM') {
        dataBuffer.push(messageFromCMBuffer);
      } else {
        rMessageRM(messageFromCMBuffer);
      }
    } else {}
  }

  B4RoutingTable? getFullRT(String layerID) {
    return routingTables[layerID];
  }

  void mergeTables(List<List<NodeID?>> newRoutingTable, String layerId) {
    List<List<NodeID?>> localRT = routingTables[layerId]!.RoutingTable;

    routingTables[layerId]!.updateRtTable(localRT, newRoutingTable);
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

  bool checkRTTableForSpoof(List<List<NodeID?>> rtTable, String node) {
    List<String> nodeIdC = node.split('');
    bool flag = true;
    int p, q;
    for (int i = 0; i <= 2; i++) {
      for (int j = 0; j <= 39; j++) {
        if (rtTable[i][j] != null) {
          List<String> tablenodeIdC = rtTable[i][j]!.hashID.split('');
          if (j == 0) {
            if (nodeIdC[0] == tablenodeIdC[0]) {
              flag = false;
              i = 3;
              j = 40;
            }
          } else {
            for (int k = j - 1; k >= 0; k--) {
              if (nodeIdC[k] != tablenodeIdC[k]) {
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
}
