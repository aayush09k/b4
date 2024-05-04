import 'package:b4commgr/b4commgr.dart';
import 'package:test/test.dart';

void main() {
  CommunicationManager communicationManager=CommunicationManager();

  test('when you need  to Relay Behind NAT', () async {
   var message='hello brother';
   var proxyIp='35.185.142.164';
   var proxyPort=22355;
   var type='TP';
   var remoteNodeId='linux';
   await communicationManager.sendMessage(proxyIp,proxyPort, type,message,remoteNodeId);
   while(true) {
     await Future.delayed(Duration(seconds:3));
     print(communicationManager.getBufferData());
   }
  });
  test('when A node is publicly available', () async {
    var message='hello brother';
    var publicIp='35.185.142.164';
    var publicPort=22356;
    var type='D';
    var remoteNodeId='linux';
    await communicationManager.sendMessage(publicIp,publicPort,type,message,remoteNodeId);
    while(true) {
      await Future.delayed(Duration(seconds:3));
      print(communicationManager.getBufferData());
    }
  });
  test('relay registration', () async {
    var message='hello brother';
    var proxyIp='35.185.142.164';
    var proxyPort=22356;
    var type='MP';
    var remoteNodeId='linux';
    await communicationManager.sendMessage(proxyIp,proxyPort, type,message,remoteNodeId);

    while(true) {
      await Future.delayed(Duration(seconds:3));
      print(communicationManager.getBufferData());
    }
  });

  test('relay registration but if instance already there then it will only send message using the stored instance', () async {
    var message='hello brother';
    var proxyIp='35.185.142.164';
    var proxyPort=22356;
    var type='MP';
    var remoteNodeId='linux';
    await communicationManager.sendMessage(proxyIp,proxyPort, type,message,remoteNodeId);

    Future<void> getdata() async {
      while (true) {
        await Future.delayed(Duration(seconds: 3));
        print(communicationManager.getBufferData());
      }
    }
    await Future.delayed(Duration(seconds: 5));

    var message2='everything is going good?';
    var proxyIp2='35.185.142.164';
    var proxyPort2=22356;
    var type2='D';
    var remoteNodeId2='linux';
      await communicationManager.sendMessage(proxyIp2,proxyPort2, type2,message2,remoteNodeId2);
    await getdata();
    }
  );

  test('getNetworkInformation', () async {
   var stunIp='';
    var stunPort='';
    await communicationManager.getNetworkInformation(stunIp, stunPort);

  }
  );
}
