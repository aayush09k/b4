import 'dart:io';

import 'package:b4commgr/stungetip.dart';
import 'package:b4connection/b4connection.dart';


class CommunicationManager {
  B4connection b4connection = B4connection();
  StunClient stunClient = StunClient();

  //RoutingManager routingManager=RoutingManager.instance;
  String? _publicIPv4;
  String? _localIPv4;
  int? _localPortIPv4;
  String? _publicIPv6;
  int? skip = 0;
  Socket? nodeSocket;




  Future<Socket?> sendMessage(ip, port, type, message,remoteNodeID) async {

    nodeSocket = await b4connection.startConnection(ip, port, type,remoteNodeID);
    if(type!='MP'){
      b4connection.sendMessage(message);
    }

    return nodeSocket;
  }

  Future<int?> getNetworkInformation(stunIp, stunPort) async {
    int natStatus=9;

    //Start connection with STUN server for all the network information.
    // Try to connect to stun server by ipv4 and ipv6 both one by one.
    b4connection.monitor.onConnectivityChanged.listen((interfaces) async {
      if (skip! >= 1) {
        if (b4connection.tcpClient.isListening()) {
          b4connection.tcpClient.stopASsNode();
          b4connection.listening!.close();
        }
      }

      print('Network interfaces changed');
      for (var interface in interfaces) {
        print('Interface: ${interface.name}');
      }

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
    });
    return natStatus;
  }


  Future<void> activateNode(proxyIp,proxyPort,listeningPort,natStatus) async {
    switch(natStatus){
      case 0:print('Behind NAT in ipv4system');
      // listening= await tcpClient.startASsNode(listeningPort);
      //receiveTexFroMcNode((message) => print(message));
      await b4connection.startConnection(proxyIp, proxyPort, 'MP',null);
      case 1:print('Not behind NAT in ipv4 system');b4connection.startNodeLiseNing(listeningPort); messageReceptionFroMcNode((message) => null);
      case 2:print('System is on ipv6 '); b4connection.startNodeLiseNing(listeningPort);messageReceptionFroMcNode((message) => null);
      default:print('natStatus is not defined');
    }
  }

  Future<void> messageReceptionFroMsNode(Function(dynamic message) onDataReceived)async {
    await b4connection.receiveTexFroMsNode((message){
       onDataReceived(message);
    });
  }

  Future<void> messageReceptionFroMcNode(Function(dynamic message) onDataReceived)async {
    await b4connection.receiveTexFroMsNode((message){
      onDataReceived(message);
    });
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