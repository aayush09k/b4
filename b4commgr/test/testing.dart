
import 'package:b4commgr/b4commgr.dart';

void main () async {
  var message = 'RRT';
  var bootstrapIp = '35.185.142.164';
  var bootstrapPort = 22355;
  var type = 'D';
  var remoteNodeId = 'google';

  CommunicationManager communicationManager = CommunicationManager();

// In the starting of the B4olm you need to Send RT request to the bootstrapNode.
  await communicationManager.sendMessage(
      bootstrapIp, bootstrapPort, type, message, remoteNodeId);


//for getting data from the  common buffer.
/*  Future<void> getData() async {
    while (true) {
      await Future.delayed(Duration(seconds: 3));
      print(communicationManager.getBufferData());
    }
  }*/

  await Future.delayed(Duration(seconds: 3));
// Then give the stunIp and Port to identify the network environment.
  var stunIp = 'stun.l.google.com';
  var stunPort = 19302;
  var natStatus = await communicationManager.getNetworkInformation(
      stunIp, stunPort);

  print(natStatus);
  await Future.delayed(Duration(seconds: 13));
  print(communicationManager.stunClient.getPublicIPv6());
// According to the natStatus you need to activate the node.
// If you are public node then no need to give the  proxyIp, proxyPort.
  var listeningPort = 22355;
  var proxyIp = '35.185.142.164';
  var proxyPort = 22355;
  var myNodeId = 'google';
  await communicationManager.activateNode(
      proxyIp, proxyPort, listeningPort, natStatus);

//Now further you can send messages to any nodeID.
//So here we have simulated the main purpose of communication manager.
  //await getData();
}