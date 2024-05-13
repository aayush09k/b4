import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:b4commgr/stungetip.dart';
import 'package:b4connection/b4connection.dart';
import 'bufferdata.dart';
import 'connectivity_monitor.dart';
import 'webrtcmanager.dart';



class CommunicationManager {

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
  DataBuffer bufferData = DataBuffer();
  final monitor = ConnectivityMonitor();

  String? _publicIPv6;
  final Map<String, B4connection> _connections = {};
  final Map<String, WebRTCManager> _connectionsWebrtc = {};
  Socket? socket;
  Socket? nodeSocket;

  Future startStreaming(remoteNodeID)async{

    Map<String, dynamic> configuration = {
      "iceServers":
      [
        {"url": "stun:stun.l.google.com:19302"},
      ]
    };


    // Check if a connection already exists
    if (_connectionsWebrtc.containsKey(remoteNodeID)) {
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
    }



  }


  Future sendMessage(ip, port, type, message, remoteNodeID) async {
    // Check if a connection already exists
    if (_connections.containsKey(remoteNodeID)) {
      _connections[remoteNodeID]!.sendMessage(message, type, remoteNodeID);
    } else {
      // Create a new connection if it does not exist
      _connections[remoteNodeID] = B4connection();

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


  dynamic getBufferData() {
    return bufferData.pull();
  }


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
      try {
        await stunClient.initializeIpv6();
        await stunClient.fetchPublicIPIpv6(stunIp, stunPort);
        await stunClient
            .closeIpv6(); //After getting information closed immediately.
      }
      catch (e) {
        print(
            'Node can not bind to both at a time . Node is not on dual network ');
        stunClient.N = 2;
        stunClient.resetIP();
      }
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


  //According to the information gathered it will start Listening for connection or
  // else it will be connected to provided  proxy sNode.

  Future<void> activateNode(proxyIp, proxyPort, listeningPort,
      natStatus, remoteNodeID) async {
    switch (natStatus) {
      case 0:
        print('Behind NAT in ipv4system');
        await sendMessage(proxyIp, proxyPort, 'MP', 'null', remoteNodeID);
      case 1:
      case 2:
        print('publicly available');

        B4connection b4connection = B4connection();
        await b4connection.startNodeLiseNing(listeningPort);
        b4connection.getRemoteIdCreationOfInstance((nodeId, socket,
            active) async {
          if (active) {
            if (nodeId == null) {}
            else {
              if (_connections.containsKey(nodeId)) {
                print('Instance corresponding to $nodeId is present.');
              }
              else {
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

      default:
        print('natStatus is not defined');
    }
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