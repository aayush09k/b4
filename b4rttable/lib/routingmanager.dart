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
  String? receiveMessage;
  String? rtFilePath; //
  int? natStatus;
  int layers = AppConfig.numberOfLayers;
  late LocalNodeID _localNodeID;
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
  DataBuffer dataBuffer = DataBuffer();
  ConnectivityMonitor monitor = ConnectivityMonitor();
  bool flag = true;

  RoutingManager._() {
    rtFilePath =
    "${filePath}rtTable.json"; // the path where routing table file will be stored as json.
    _localNodeID = LocalNodeID();
    _localNodeID.nodeid.listeningPort = 8888;
    _localNodeID.nodeid.hashID = "62D67DFC3E4616381DACA70A90CDF3C59EA80D32";


    if (flag == true) {
      // we have to get this from auth manager, for testing change this ib b4rtTable class also at line no. 30
      // Call the init() function when the instance is created
      _localNodeID.nodeid.sign = ECSignature(BigInt.parse(
          "65470513412405851950885404129427616067309932491674362141979488612896203164025"),
          BigInt.parse(
              "35241799610163012077198311829834117378791561246876962545184629718444186922890"));
      _localNodeID.nodeid.publicKeyPem =
      "-----BEGIN PUBLIC KEY-----\nMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEr8xH1as9ZYF2t+Bc6iQVBNtB4WxK\nUBlQ5sX9oBpTSrTdS39R2c8W4r/Wq/fXNHk+df5uig06vSozEnADHgY8xQ==\n-----END PUBLIC KEY-----";
      _localNodeID.nodeid.pubKey =
          CryptoUtils.ecPublicKeyFromPem(_localNodeID.nodeid.publicKeyPem);


      _localNodeID.nodeid.publicIpv4 = "103.246.106.197";
      _localNodeID.nodeid.natStatus = 1;
      _localNodeID.nodeid.publicIpv6 = "";
      _localNodeID.nodeid.localIpv4 = "172.20.160.56";
    }


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
    // Check if the file exists;
    NodeID? bootStrapNodeID;

    if (File(filePath).existsSync()) {

      // Perform actions related to the existing file,check liveliness of nodes.
    } else {

      for (int i = 0; i <= layers; i++) {
        routingTables[i.toString()] = B4RoutingTable(localNodeID);
      }
    }

    // Skip as flag=true for botsTrapNode.
    if (flag == false) {
      bootStrapNodeID = NodeID.createFromTable(
        "-----BEGIN PUBLIC KEY-----\nMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEr8xH1as9ZYF2t+Bc6iQVBNtB4WxK\nUBlQ5sX9oBpTSrTdS39R2c8W4r/Wq/fXNHk+df5uig06vSozEnADHgY8xQ==\n-----END PUBLIC KEY-----",
        // Assuming this is how you reconstruct pubKey
        ECSignature(BigInt.parse(
            "65470513412405851950885404129427616067309932491674362141979488612896203164025"),
            BigInt.parse(
                "35241799610163012077198311829834117378791561246876962545184629718444186922890")),
        "62D67DFC3E4616381DACA70A90CDF3C59EA80D32",
        // Assuming this is how you reconstruct sign
        CryptoUtils.ecPublicKeyFromPem(
            "-----BEGIN PUBLIC KEY-----\nMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEr8xH1as9ZYF2t+Bc6iQVBNtB4WxK\nUBlQ5sX9oBpTSrTdS39R2c8W4r/Wq/fXNHk+df5uig06vSozEnADHgY8xQ==\n-----END PUBLIC KEY-----"),
        "172.20.160.56", //localIPV4
        "103.246.106.197",//publicIPV4
        null.toString(),
        1,
        null,
        null,
        null,
        null.toString(),
        null,
        8888,
      );
    }


    if (flag == true) {
      manager.activateNode(
          null, null, localNodeID.nodeid.listeningPort, 1, null);
    }


    // un comment this line for normal nodes.This line will remain comment for bootstrap.
    if (flag == false) {
      await geTinFormation();
      await manager.activateNode(bootStrapNodeID!.publicIpv4,bootStrapNodeID.listeningPort,localNodeID.nodeid.listeningPort, natStatus,
          bootStrapNodeID.hashID); // hard code boots
      await sendMessageRM(
          'RM',
          "D",
          localNodeID.nodeid,
          "hashID",
          "s",
          "current",
          "natStatus",
          localNodeID.nodeid,
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

            // old code, for nodeID
            // 'hashID': nodeID.hashID,
            // 'publicKey': nodeID.pubKey.toString(),
            // 'sign': {
            //   'r': nodeID.sign.r.toString(),
            //   's': nodeID.sign.s.toString()
            // },
            // 'publicKeyPem': nodeID.publicKeyPem.toString(),

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


  Future<void> geTinFormation() async {
    natStatus = await manager.getNetworkInformation("stun.l.google.com", 19302);

    String? iPl;
    String? iP4;
    String? iP6;
    if (manager.stunClient.getLocalIPv4() != null) {
      iPl = manager.stunClient.getLocalIPv4()!.address;
    }

    if (manager.stunClient.getPublicIPv4() != null) {
      iP4 = manager.stunClient.getPublicIPv4()!.address;
    }

    if (manager.stunClient.getPublicIPv6() != null) {
      iP6 = manager.stunClient.getPublicIPv6()!.address;
    }

    localNodeID.nodeid.localIpv4 = iPl;
    localNodeID.nodeid.publicIpv6 = iP4;
    localNodeID.nodeid.publicIpv4 = iP6;
    localNodeID.nodeid.natStatus = natStatus;
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
      manager.communicate(
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
        manager.communicate(
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
        .updateRtTable(routingTables[layerID]!.RoutingTable, nodeList);
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

  void handleForMessages() {
    dynamic messageFromCMBuffer = dataBuffer.pull();
    print(messageFromCMBuffer);
    if (messageFromCMBuffer != null) {
      Map<String, dynamic> decodedMessageRM = jsonDecode(messageFromCMBuffer);
      String rM = decodedMessageRM['RM'];

      if (rM != 'RM') {
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
    for (int i = 0; i <= 2; i++) {
      for (int j = 0; j <= 39; j++) {
        if (rtTable[i][j] != null) {
          List<String> tableNodeIdC = rtTable[i][j]!.hashID.split('');
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
}
