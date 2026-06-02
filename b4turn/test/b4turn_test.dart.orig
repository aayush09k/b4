import 'dart:async';
import 'package:b4turn/TurnClient.dart';

void main() async {
  // Define the TURN server address and port
  String turnServerAddress = '172.17.85.108';
  int turnServerPort = 3478;

  // Create a TurnClient instance
  TurnClient turnClient = TurnClient(turnServerAddress, turnServerPort);

  // Connect to the TURN server
  await turnClient.connect();

  // Send the TURN messages to the TURN server
  await sendTurnMessages(turnClient);

  // Disconnect from the TURN server
  //turnClient.disconnect();
}

Future<void> sendTurnMessages(TurnClient turnClient) async {
  //List<int> turnMessage = generateTurnMessage();
  //await turnClient.sendData(turnMessage);
}

List<int> generateTurnMessage() {
  // Construct a valid TURN Allocate Request message
  List<int> turnMessage = [
    0x00, 0x03, // Message Type: Allocate Request
    0x00, 0x14, // Message Length: 20 bytes
    0x21, 0x12, 0xA4, 0x42, // Magic Cookie
    0x63, 0x42, 0x95, 0x14, 0x26, 0x13, 0x14, 0x45, // Transaction ID
    0x00, 0x19, 0x00, 0x04, // LIFETIME attribute
    0x00, 0x00, 0x0E, 0x10, // Lifetime value: 3600 seconds
    0x00, 0x03, 0x00, 0x04, // REQUESTED-TRANSPORT attribute
    0x00, 0x00, 0x00, 0x11  // Protocol: UDP
  ];

  return turnMessage;
}
