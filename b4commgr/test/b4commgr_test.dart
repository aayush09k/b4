import 'package:b4commgr/b4commgr.dart';
import 'package:test/test.dart';

void main() {
  CommunicationManager communicationManager=CommunicationManager();
  test('when you need  to Relay Behind NAT', () async {
   var myNodeId='macbbok';
   var proxyIp='35.185.142.164';
   var proxyPort=22355;
   var type='TP';
   var remoteNodeId='dell';
   await communicationManager.sendMessage(proxyIp,proxyPort, type,myNodeId,remoteNodeId);
   communicationManager.b4connection.receiveTexFroMsNode((message) => print(message));
  });
  test('when A node is publicly available', () async {
    var myNodeId='macbbok';
    var publicIp='35.185.142.164';
    var publicPort=22355;
    var type='D';
    var remoteNodeId='dell';
    await communicationManager.sendMessage(publicIp,publicPort,type,myNodeId,remoteNodeId);
    communicationManager.b4connection.receiveTexFroMsNode((message) => print(message));
  });
  test('relay registration', () async {
    var myNodeId='macbbok';
    var proxyIp='35.185.142.164';
    var proxyPort=22355;
    var type='MP';
    var remoteNodeId='';
    await communicationManager.sendMessage(proxyIp,proxyPort, type,myNodeId,remoteNodeId);
   communicationManager.b4connection.receiveTexFroMsNode((message) => print(message));
  });

}
