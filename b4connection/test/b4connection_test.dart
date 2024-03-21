import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:psjapp/b4connection.dart';
 // Adjust the import path as necessary
enum ConnectionType{P,D}
Future<void> main() async {
  // Initialize your STUN connection or other setup here
  B4connection b4connection = B4connection('stun.l.google.com', 19302);
  int? targetPort;

  // Create a stream subscription to handle each line of input
  StreamSubscription<String>? inputSubscription;

  inputSubscription = stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((String line) async {
    if (b4connection.step == 0) { // First step, expecting IP address
      b4connection.targetIp=InternetAddress.tryParse(line);
       if(b4connection.targetIp!=null) {
         print('IPv4  entered: ${b4connection.targetIp!.address}');
         print('Please enter the target port:');
         b4connection.step = 1;
       }
       else{
        print('your IP invalid enter a valid IP');
       }
    } else if (b4connection.step == 1) { // Second step, expecting port
           targetPort = int.tryParse(line);
          if (targetPort == null) {
             print('Invalid port. Please enter a valid port number:');
          } else{
            print('Port entered: $targetPort');
            print('Please enter the ConnectionType');


            b4connection.step=2;

          }
    }
    else if(b4connection.step==2){

      await b4connection.startConnection(b4connection.targetIp!.address, targetPort,line);

    }
    else if(b4connection.step==3) {
      if(b4connection.tcpClient.isConnected()) {
        if (line == 'exit') {
          b4connection.tcpClient.disconnect();
          b4connection.step = 0;
        }
        else {
          b4connection.sendMessage(line);
        }
      }
      else{
        print('not connected again enter proper IP');
        b4connection.step=0;
      }
    }
  }, onDone: () {
    print('Input complete.');
  });

  // Add your remaining application logic here
}
