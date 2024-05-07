
import 'package:b4commgr/b4commgr.dart';

void main () async {

  CommunicationManager communicationManager = CommunicationManager();

  var message = 'RRT';
  var bootstrapIp = '35.185.142.164';
  var bootstrapPort = 22355;
  var type = 'D';
  var remoteNodeId = 'google';


// In the starting of the B4olm you need to Send RT request to the bootstrapNode.
  await communicationManager.sendMessage(
      bootstrapIp, bootstrapPort, type, message, remoteNodeId);


//for getting data from the  common buffer.
  Future<void> getData() async {
    while (true) {
      await Future.delayed(Duration(seconds: 3));
      print(communicationManager.getBufferData());
    }
  }

  await Future.delayed(Duration(seconds: 3));
// Then give the stunIp and Port to identify the network environment.
  var stunIp = 'stun.l.google.com';
  var stunPort = 19302;
  var natStatus = await communicationManager.getNetworkInformation(
      stunIp, stunPort);

  print(natStatus);
  await Future.delayed(Duration(seconds: 5));
  print(communicationManager.stunClient.getPublicIPv6());
// According to the natStatus you need to activate the node.
// If you are public node then no need to give the  proxyIp, proxyPort.
  var listeningPort = 22355;
  var proxyIp = '35.185.142.164';
  var proxyPort = 22355;
  await communicationManager.activateNode(
      proxyIp, proxyPort, listeningPort, natStatus);

//Now further you can send messages to any nodeID.
//So here we have simulated the main purpose of communication manager.

  await Future.delayed(Duration(seconds: 5));
  var message1 = 'RRT';
  var bootstrapIp1 = '35.185.142.164';
  var bootstrapPort1 = 22355;
  var type1 = 'D';
  var remoteNodeId1 = 'google';


// In the starting of the B4olm you need to Send RT request to the bootstrapNode.
  await communicationManager.sendMessage(
      bootstrapIp1, bootstrapPort1, type1, message1, remoteNodeId1);
  await getData();
}