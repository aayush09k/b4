
import 'dart:async';

import 'package:b4commgr/b4commgr.dart';

void main () async {

  CommunicationManager communicationManager = CommunicationManager();


//for getting data from the  common buffer.
  Future<void> getData() async {
    Timer.periodic(Duration(seconds: 3), (timer) async {
      print(await communicationManager.getBufferData());
    });
  }



// Then give the stunIp and Port to identify the network environment.
  var stunIp = 'stun.l.google.com';
  var stunPort = 19302;
  var natStatus = await communicationManager.getNetworkInformation(
      stunIp, stunPort);
  print(natStatus);

// According to the natStatus you need to activate the node.
// If you are public node then no need to give the  proxyIp, proxyPort.
  var listeningPort = 22355;
  await communicationManager.activateNode(
      null, null, listeningPort,2,null);

//Now further you can send messages to any nodeID.
//So here we have simulated the main purpose of communication manager.
  await Future.delayed(Duration(seconds: 15));

  var type1 = 'D';
  var remoteNodeId1 = 'psj';
  var message='hey i have sent you from you stored instance at my node ';
  communicationManager.sendMessage(null, null, type1, message, remoteNodeId1);

  await Future.delayed(Duration(seconds: 52));


  var type12 = 'D';
  var remoteNodeId12 = 'psj';
  var message2='this message will not be coming to you';
  communicationManager.sendMessage(null, null, type12, message2, remoteNodeId12);

  await getData();
}