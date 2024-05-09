
import 'package:b4commgr/b4commgr.dart';

void main () async {

  CommunicationManager communicationManager = CommunicationManager();


//for getting data from the  common buffer.
  Future<void> getData() async {
    while (true) {
      await Future.delayed(Duration(seconds: 3));
      print(await communicationManager.getBufferData());
    }
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

  await Future.delayed(Duration(seconds: 22));
/*
  var message1 = 'i am your bootstrap node bro i have sent you a message by making your instance of b4connection.'
      'i have made a instance of b4connection corresponding tp your node id, when you had sent me relay registration request';
  var proxyIP = '35.185.142.164';
  var proxyPORT = 22356;
  var type1 = 'D';
  var remoteNodeId1 = 'psj';*/



  await getData();
}