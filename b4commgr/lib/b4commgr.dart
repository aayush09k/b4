import 'dart:io';

import 'package:b4commgr/stungetip.dart';
import 'package:b4connection/b4connection.dart';
import 'bufferdata.dart';
import 'connectivity_monitor.dart';



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


  String? _publicIPv4;
  String? _localIPv4;
  int? _localPortIPv4;
  String? _publicIPv6;
  int? skip = 0;

  final Map<String, B4connection> _connections = {};
  Socket? socket;
  Socket? nodeSocket;


  Future sendMessage(ip, port, type, message, remoteNodeID) async {

    // Check if a connection already exists
    if (_connections.containsKey(remoteNodeID)) {
      _connections[remoteNodeID]!.sendMessage(message);
    } else {
      // Create a new connection if it does not exist
      _connections[remoteNodeID] = B4connection();
      socket = (await _connections[remoteNodeID]!.startConnection(
          ip, port, type, remoteNodeID))!;
      _connections[remoteNodeID]!.sendMessage(message);
    }

    // Set the onClosed callback
    _connections[remoteNodeID]!.onClosedC = () {
      _connections.remove(remoteNodeID);
      print(
          "Connection for $remoteNodeID has been removed from manager due to closure.");
    };

  }


  dynamic getBufferData() {
    return bufferData.pull();
  }


  Future<int?> getNetworkInformation(stunIp, stunPort) async {
    int natStatus = 9;

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
      await _getAllIpPort();
      skip = 2;


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
      natStatus, myNodeId) async {
    switch (natStatus) {
      case 0:
        print('Behind NAT in ipv4system');
        await sendMessage(proxyIp, proxyPort, 'MP', 'null', 'lulu');
      case (1,2):
        print('publicly available');
        if (_connections.containsKey(myNodeId)) {

          _connections[myNodeId]!.getRemoteIdCreationOfInstance((message,socket) async {
            if (_connections.containsKey(message['p3'])) {
              print('good');
            }
            else{
              _connections[message['p3']]=B4connection();
              _connections[message['p3']]!.setNodeSocketAndSkip(socket);
              await _connections[message['p3']]!.bufferReceivingData();

            }

          });

        }
        else {
          _connections[myNodeId] = B4connection();
           await _connections[myNodeId]!.startNodeLiseNing(listeningPort);
          _connections[myNodeId]!.getRemoteIdCreationOfInstance((message,socket){
            if (_connections.containsKey(message['p3'])) {
              print('good');
            }
            else{
              _connections[message['p3']]=B4connection();
              _connections[message['p3']]!.setNodeSocketAndSkip(socket);
              _connections[message['p3']]!.bufferReceivingData();
            }

          });
        }

      default:
        print('natStatus is not defined');
    }
  }


  //Putting all the ip and port inside the global variables.
  Future<void> _getAllIpPort() async {
    try {
      if (stunClient.getPublicIPv4() != null) {
        _localIPv4 = stunClient.getLocalIPv4()!.address;
        _localPortIPv4 = stunClient.getLocalPortIPv4();
      }

      if (stunClient.getPublicIPv4() != null) {
        _publicIPv4 = stunClient.getPublicIPv4()!.address;
        //_publicPortIPv4 = stunClient.getPublicPortIPv4();
      }

      if (stunClient.getPublicIPv6() != null) {
        _publicIPv6 = stunClient.getPublicIPv6()!.address;
        // _publicPortIPv6 = stunClient.getPublicPortIPv6();
      }
    }
    catch (e) {
      print('error in getting all ports');
    }
    // _printAllPort();
  }

}