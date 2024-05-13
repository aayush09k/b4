
import 'dart:async';

import 'package:b4commgr/b4commgr.dart';
import 'package:b4rttable/b4rttable.dart';
import 'package:b4rttable/routingmanager.dart';

void main () async {

  CommunicationManager communicationManager = CommunicationManager();
 // RoutingManager routingManager=RoutingManager.instance;


  var message = 'RRT';
  var bootstrapIp = '35.185.142.164';
  var bootstrapPort = 22355;
  var type = 'D';
  var remoteNodeId = 'google';

 await  communicationManager.startStreaming(remoteNodeId);

// In the starting of the B4olm you need to Send RT request to the bootstrapNode.
  await communicationManager.sendMessage(
      bootstrapIp, bootstrapPort, type, message, remoteNodeId);


//for getting data from the  common buffer.
  Future<void> getData() async {
    Timer.periodic(Duration(seconds: 3), (timer) async {
      print(await communicationManager.getBufferData());
    });
  }

  await Future.delayed(Duration(seconds: 7));
// Then give the stunIp and Port to identify the network environment.
  var stunIp = 'stun.l.google.com';
  var stunPort = 19302;
  var natStatus = await communicationManager.getNetworkInformation(
      stunIp, stunPort);

  print(natStatus);

  await Future.delayed(Duration(seconds: 5));

// According to the natStatus you need to activate the node.
// If you are public node then no need to give the  proxyIp, proxyPort.
  var listeningPort = 22355;
  var proxyIp = '35.185.142.164';
  var proxyPort = 22355;
  var remoteNodeId3 = 'google';
  await communicationManager.activateNode(
      proxyIp, proxyPort, listeningPort,natStatus,remoteNodeId3);

//Now further you can send messages to any nodeID.
//So here we have simulated the main purpose of communication manager.

  await Future.delayed(Duration(seconds: 15));

  var message1 = 'i am sending  proxy message to  myself ';
  var proxyIP = '35.185.142.164';
  var proxyPORT = 22355;
  var type1 = 'TP';
  var remoteNodeId1 = 'psj';


// Now we are relaying  data to "remoteNodeId1 " because it is behind NAT.
  await communicationManager.sendMessage(
      proxyIP, proxyPORT, type1, message1, remoteNodeId1);

  await Future.delayed(Duration(seconds: 5));

  var message2 = 'THIS IS MESSAGE FROM PUSHPENDRA ';
  var proxyIP2 = '35.185.142.164';
  var proxyPORT2 = 22355;
  var type12 = 'TP';
  var remoteNodeId12 = 'aman';


// Now we are relaying  data to "remoteNodeId1 " because it is behind NAT.
  await communicationManager.sendMessage(
      proxyIP2, proxyPORT2, type12, message2, remoteNodeId12);

  await Future.delayed(Duration(seconds: 10));
  await getData();
}