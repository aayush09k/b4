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
        if (b4connection.K == 0) {
          if (b4connection.tcpClient.nodeHandler() != null) {
            b4connection.K = 6;
            print(
                'want to connect to some public node , then write c.if you are publicly connected to some node then write n');
          }
          else {
            b4connection.K = 1;
            print(
                'If you want to connect to Behind NAT node then enter Proxy Target IP. If you want to connect to public node then enter target IP');
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
          b4connection.targetPort = int.tryParse(line);
          if (b4connection.targetPort != null) {
            print('Port entered: $targetPort');
            if (b4connection.subtype != null) {
              b4connection.K = 3;
              print('Write any key to connect');
            }
            else {
              print('Please enter the ConnectionType');
              b4connection.K = 3;
            }
          } else {
            print('Invalid port. Please enter a valid port number:');
          }
        }
        else if (b4connection.K == 3) {
          type = line;
          if (line == 'TP') {
            b4connection.K = 4;
            print(" write  the remote key");
          }
          else {
            if (b4connection.subtype != null) {
              b4connection.sendMessage(null);
            }
            await b4connection.startConnection(
                b4connection.targetIp!.address, b4connection.targetPort, type);
            b4connection.K = 6;
          }
        }
        else if (b4connection.K == 4) {
          b4connection.setRemoteNodeKey(line);
          b4connection.K = 5;
          print("write 'enter' and then press enter to connect ");
        }
        else if (b4connection.K == 5) {
          if (line == 'enter') {
            await b4connection.startConnection(
                b4connection.targetIp!.address, b4connection.targetPort, type);
            b4connection.K = 6;
            print(
                'Do you want to connect to some node , then press c.if you are already connected to some node then press n.Press "exit relay" to exit from relay.');
          }
          else {
            print(
                'Do you want to connect to some node , then press c.if you are already connected to some node then press n');
            b4connection.K = 6;
          }
        }
        else if (b4connection.K == 6) {
          if (line == 'c') {
            b4connection.K = 1;
            print(
                'If you want to connect to Behind NAT node then enter Proxy Target IP. If you want to connect to public node then enter target IP. ');
          }
          else if (line == 'n') {
            b4connection.K = 7;
            print('(1).go send message to connected node.'
                '(2).Write "connect" if you want to get connect further.'
                '(3).Write "exitRelay" to exit from relay.'
                '(4).Write exit to disconnect from either Proxy or remoteNode.'
                '(5).Write "goToIpv6" for connecting to ivp6 public node through your proxy if your are behind NAT.');
          }
          else {
            print('enter proper input (Input should be either c or n)');
          }
        }
        else if (b4connection.K == 7) {
          print(b4connection.tcpClient.isConnected());
          if (line == 'connect') {
            b4connection.K = 1;
            print(
                'if you want to connect to Behind NAT node then enter Proxy Target IP. If you want to connect to public node then enter target IP');
          }
          else if (b4connection.tcpClient.isConnected()) {
            if (line == 'exitRelay') {
              b4connection.K = 1;
              b4connection.disconnectRelay();
            }
            else if (line == 'goToIpv6') {
              print('Enter target ipv6');
              b4connection.K = 1;
              b4connection.setSubtype();
            }
            else if (line == 'printRelayMap') {
              b4connection.printRelayMap(); // this is for Snode side.
            }
            else if (line == 'exit') {
              b4connection.K = 1;
              b4connection.tcpClient.disconnect();
            }
            else {
              b4connection.sendMessage(line);
            }
          }
          else if (b4connection.tcpClient.isListening()) {
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
