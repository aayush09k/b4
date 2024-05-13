
import 'dart:async';

import 'package:b4commgr/b4commgr.dart';
import 'package:b4rttable/b4rttable.dart';
import 'package:b4rttable/routingmanager.dart';

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
  RoutingManager routingManager=RoutingManager.instance;
  await getData();
}