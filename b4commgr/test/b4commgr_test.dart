import 'package:b4commgr/b4commgr.dart';
import 'package:test/test.dart';

void main() {
  CommunicationManager communicationManager=CommunicationManager();
  test('1', () async {

   await communicationManager.sendMessage('35.185.142.164', 22350, 'D','macbook', null);
   communicationManager.b4connection.receiveTexFroMsNode((message) => print(message));
  });
}
