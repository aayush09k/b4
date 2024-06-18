import 'dart:async';
import 'dart:io';
import 'stungetip.dart';
import 'package:b4connection/B4connection.dart';


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


  Future<void> _getIpv6() async {
    try {
      if (stunClient.getPublicIPv6() != null) {
        _publicIPv6 = stunClient.getPublicIPv6()!.address;
      }
    }
    catch (e) {}
  }
}