import 'package:b4commgr/b4commgr.dart';
import 'package:test/test.dart';

void main() {
  CommunicationManager communicationManager = CommunicationManager();

  test('when you need  to Relay Behind NAT', () async {
    var message = 'hello brother';
    var proxyIp = '35.185.142.164';
    var proxyPort = 22355;
    var type = 'TP';
    var remoteNodeId = 'linux';
    await communicationManager.sendMessage(
        proxyIp, proxyPort, type, message, remoteNodeId);

    // Very important thing ,you need to handle the buffer data in asynchronous way otherwise it
    // will block your other operation.
    while (true) {
      await Future.delayed(Duration(seconds: 3));
      print(communicationManager.getBufferData());
    }
  });

  test('when A node is publicly available / when i am responding to the connected client', () async {
    var message = 'hello brother';
    var publicIp = '35.185.142.164';
    var publicPort = 22356;
    var type = 'D';
    var remoteNodeId = 'linux';
    await communicationManager.sendMessage(
        publicIp, publicPort, type, message, remoteNodeId);
    while (true) {
      await Future.delayed(Duration(seconds: 3));
      print(communicationManager.getBufferData());
    }
  });

  test('relay registration', () async {
    var message = 'hello brother';
    var proxyIp = '35.185.142.164';
    var proxyPort = 22356;
    var type = 'MP';
    var remoteNodeId = 'linux';
    await communicationManager.sendMessage(
        proxyIp, proxyPort, type, message, remoteNodeId);

    while (true) {
      await Future.delayed(Duration(seconds: 3));
      print(communicationManager.getBufferData());
    }
  });

  test(
      'If instance already there then it will only send message using the stored instance', () async {
    var message = 'hello brother';
    var proxyIp = '35.185.142.164';
    var proxyPort = 22355;
    var type = 'MP';
    var remoteNodeId = 'linux';
    //sendMessage function of singleton class.
    await communicationManager.sendMessage(
        proxyIp, proxyPort, type, message, remoteNodeId);

    //for getting data from the  common buffer.
    Future<void> getData() async {
      while (true) {
        await Future.delayed(Duration(seconds: 3));
        print(communicationManager.getBufferData());
      }
    }

    // Simulate the time according to yourself to see different use-cases.
    // If you are not sending anything on the b4connection instance or receiving for a particular time
    // your instance will be deleted.Then you will have to create the new one.
    await Future.delayed(Duration(seconds: 6));

    var message2 = 'everything is going good?';
    var proxyIp2 = '35.185.142.164';
    var proxyPort2 = 22355;
    var type2 = 'D';
    var remoteNodeId2 = 'linux';
    await communicationManager.sendMessage(
        proxyIp2, proxyPort2, type2, message2, remoteNodeId2);
    await getData();
  }
  );

  test(
      'You should proceed exactly according to this use-case  for B4olm', () async {
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
    var natStatus=await communicationManager.getNetworkInformation(
        stunIp, stunPort);

    print(natStatus);
    await Future.delayed(Duration(seconds: 3));
    // According to the natStatus you need to activate the node.
    // If you are public node then no need to give the  proxyIp, proxyPort.
    var listeningPort = 22355;
    var proxyIp = '35.185.142.164';
    var proxyPort = 22355;
    var myNodeId = 'macbook';
    await communicationManager.activateNode(
        proxyIp, proxyPort, listeningPort, natStatus);

    //Now further you can send messages to any nodeID.
    //So here we have simulated the main purpose of communication manager.
  await  getData();
  }

  );
}
