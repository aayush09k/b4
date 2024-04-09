import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:psjapp/b4connection.dart';


Future<void> main() async {
  // Initialize your STUN connection or other setup here

  B4connection b4connection = B4connection('stun.l.google.com', 19302);
  int? targetPort;
  String? type;


  // Create a stream subscription to handle each line of input
  StreamSubscription<String>? inputSubscription;

  inputSubscription =
      stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((
          String line) async {
        if(b4connection.K==0){
          if(b4connection.tcpClient.nodeHandler()!=null){
            b4connection.K=6;
            print('want to connect to some public node , then press c.if you are publicly connected to some node then press n');
          }
          else{
            b4connection.K=1;
            print('If you want to connect to Behind NAT node then enter Proxy Target IP. If you want to connect to public node then enter target IP');

          }
        }
        else if (b4connection.K == 1) { // First step, expecting IP address
          b4connection.targetIp = InternetAddress.tryParse(line);
          if (b4connection.targetIp != null) {
            print('Ip  entered: ${b4connection.targetIp!.address}');
            print('Please enter the target port:');
            b4connection.K = 2;
          }
          else {
            print('your IP invalid enter a valid IP');
          }
        } else if (b4connection.K == 2) { // Second step, expecting port
          targetPort = int.tryParse(line);
          if (targetPort == null) {
            print('Invalid port. Please enter a valid port number:');
          } else {
            print('Port entered: $targetPort');
            print('Please enter the ConnectionType');


            b4connection.K = 3;
          }
        }
        else if(b4connection.K==3){
          type=line;
          if(line=='TP'){
          b4connection.K=4;
          print("Press enter the remote key");
          }
          else{
            await b4connection.startConnection(
                b4connection.targetIp!.address, targetPort, type);
            b4connection.K = 6;
          }
        }
        else if(b4connection.K==4){
        b4connection.setRemoteNodeKey(line);
        b4connection.K=5;
        print("press 'enter ' to connect ");
        }
        else if (b4connection.K == 5) {
          if(line=='enter') {
            await b4connection.startConnection(b4connection.targetIp!.address, targetPort, type);
            b4connection.K = 6;
            print('Do you want to connect to some node , then press c.if you are already connected to some node then press n');
          }
          else{
          print('Do you want to connect to some node , then press c.if you are already connected to some node then press n');
          b4connection.K=6;}
        }
        else if (b4connection.K == 6) {


          if (line == 'c') {
            b4connection.K = 1;
            print('If you want to connect to Behind NAT node then enter Proxy Target IP. If you want to connect to public node then enter target IP');
          }
          else if(line=='n'){
            b4connection.K = 7;
            print('go send message to connected node');
          }
          else{
            print('enter proper input (Input should be either c or n)');
          }
        }
        else if (b4connection.K == 7) {
          if(line=='connect'){
            b4connection.K=1;
            print('if you want to connect to Behind NAT node then enter Proxy Target IP. If you want to connect to public node then enter target IP');
          }
          else if (b4connection.tcpClient.isConnected()) {
            if (line == 'exit') {
              b4connection.disconnectFromRemoteNode();
              b4connection.K = 1;
            }
            else {
              b4connection.sendMessage(line);

            }
          }
          else if(b4connection.tcpClient.isListening()){
            if (line == 'exit') {
              b4connection.remoteSocketClose();
              b4connection.K = 1;
            }
            else {
              b4connection.sendMessage(line);

            }

          }
          else {
            print('not connected again enter proper IP');
            b4connection.K = 1;
          }
        }
      }, onDone: () {
        print('Input complete.');
      });

  // Add your remaining application logic here
}
