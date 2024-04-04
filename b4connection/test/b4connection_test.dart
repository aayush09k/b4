import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:psjapp/b4connection.dart';


Future<void> main() async {
  // Initialize your STUN connection or other setup here

  B4connection b4connection = B4connection('stun.l.google.com', 19302);
  int? targetPort;


  // Create a stream subscription to handle each line of input
  StreamSubscription<String>? inputSubscription;
  print('type anything to start');
  inputSubscription =
      stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((
          String line) async {
        if(b4connection.K==0){
          if(b4connection.tcpClient.nodeHandler()!=null){
            b4connection.K=4;
          }
          else{
            b4connection.K=1;
            print('enter target IP');

          }
        }
        else if (b4connection.K == 1) { // First step, expecting IP address
          b4connection.targetIp = InternetAddress.tryParse(line);
          if (b4connection.targetIp != null) {
            print('IPv4  entered: ${b4connection.targetIp!.address}');
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
        else if (b4connection.K == 3) {
          await b4connection.startConnection(
              b4connection.targetIp!.address, targetPort, line);
          b4connection.K = 4;
        }
        else if (b4connection.K == 4) {
          print(
              'want to connect to some public node , then press c.if you are publicly connected to some node then press n');

          if (line == 'c') {
            b4connection.K = 0;
            print('enter target IP');
          }
          else {
            b4connection.K = 5;
            print('go send message to connected node');
          }
        }
        else if (b4connection.K == 5) {
          if (b4connection.tcpClient.isConnected()) {
            if (line == 'exit') {
              b4connection.tcpClient.disconnect();
              b4connection.K = 0;
            }
            else {
              b4connection.sendMessage(line);

            }
          }
          else if(b4connection.tcpClient.isListening()){
            if (line == 'exit') {
              b4connection.tcpClient.stopServer();
              b4connection.K = 0;
            }
            else {
              b4connection.sendMessage(line);

            }

          }
          else {
            print('not connected again enter proper IP');
            b4connection.K = 0;
          }
        }
      }, onDone: () {
        print('Input complete.');
      });

  // Add your remaining application logic here
}
