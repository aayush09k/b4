
import 'dart:async';

import 'package:b4commgr/b4commgr.dart';
import 'package:b4rttable/b4rttable.dart';
import 'package:b4rttable/routingmanager.dart';

void main () async {

  CommunicationManager communicationManager = CommunicationManager();
  RoutingManager routingManager=RoutingManager.instance;


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

  await Future.delayed(Duration(seconds: 50));
  print(communicationManager.getBufferData());

}