/* Squadron Leader Tarun Chaudhary    */
// this code has to run on a node that is behind NAT and want to use TURN Server

import 'dart:async'; // Provides Timer and Future functionalities
import 'dart:io'; // Provides RawDatagramSocket and InternetAddress
import 'dart:convert'; // For encoding and decoding UTF-8 strings

class TurnClient {
  late InternetAddress _turnServerAddress; // IP address of the TURN server
  late int _turnServerPort; // Port of the TURN server
  late RawDatagramSocket _socket; // Socket used for communication

  // Constructor to initialize the TURN client with server address and port
  TurnClient(String turnServerAddress, int turnServerPort) {
    _turnServerAddress = InternetAddress(turnServerAddress);
    _turnServerPort = turnServerPort;
  }

  // Connects the client to the TURN server
  Future<void> connect() async {
    try {
      print('TURN client connecting...');
      // Bind the client socket to any available IPv4 address and port
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      print('Client socket bound to port: ${_socket.port}');

      // Listen for responses from the TURN server
      _socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          Datagram? datagram = _socket.receive();
          if (datagram != null) {
            // Print received response from the TURN server
            print('Received response from TURN server: ${String.fromCharCodes(datagram.data)}');
            // Process the response as needed
          }
        }
      });
    } catch (e) {
      // Print any errors that occur during connection
      print('Error connecting to TURN server: $e');
    }
  }

  // Sends data to the TURN server
  Future<void> sendDataToTurnServer(List<int> data) async {
    try {
      // Send data to the TURN server using the client socket
      _socket.send(data, _turnServerAddress, _turnServerPort);
      print('Sent data to TURN server');
    } catch (e) {
      // Print any errors that occur while sending data
      print('Error sending data: $e');
    }
  }

  // Sends a message to a destination address and port via the TURN server
  Future<void> sendDataToDestination(String destinationAddress, int destinationPort, String message) async {
    try {
      // Create a forward message in the required format
      List<int> forwardMessage = createForwardMessage(destinationAddress, destinationPort, message);
      // Send the forward message to the TURN server
      _socket.send(forwardMessage, _turnServerAddress, _turnServerPort);
      print('Forwarded message to destination via TURN server');
    } catch (e) {
      // Print any errors that occur while forwarding data
      print('Error forwarding data: $e');
    }
  }

  // Disconnects the client from the TURN server
  void disconnect() {
    // Close the socket
    _socket.close();
    print('Disconnected from TURN server');
  }
}

// Main function to demonstrate the usage of the TurnClient class
Future<void> main() async {
  // Define the TURN server address and port
  String turnServerAddress = '192.168.0.105'; // TURN server address
  int turnServerPort = 3478;

  // Create a TurnClient instance
  TurnClient turnClient = TurnClient(turnServerAddress, turnServerPort);

  // Connect to the TURN server
  await turnClient.connect();

  // Define the destination address and port
  String destinationAddress = '127.0.0.1'; // Destination address
  int destinationPort = 5000; // Destination port

  // Send the TURN Allocate Request to the TURN server
  await sendTurnAllocateRequest(turnClient);

  // Send a message to the destination via TURN server
  await turnClient.sendDataToDestination(destinationAddress, destinationPort, 'Hello, Destination!');

  // Disconnect from the TURN server
  turnClient.disconnect();
}

// Sends a TURN Allocate Request to the TURN server
Future<void> sendTurnAllocateRequest(TurnClient turnClient) async {
  // Generate a TURN Allocate Request message
  List<int> turnAllocateRequest = generateTurnAllocateRequest();
  // Send the request to the TURN server
  await turnClient.sendDataToTurnServer(turnAllocateRequest);
}

// Generates a TURN Allocate Request message
List<int> generateTurnAllocateRequest() {
  // Construct a valid TURN Allocate Request message according to the protocol
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

// Creates a forward message in the required format
List<int> createForwardMessage(String destinationAddress, int destinationPort, String message) {
  // Format the message according to the TURN server requirements
  String formattedMessage = 'SEND $destinationAddress $destinationPort $message';
  print(message);
  // Encode the message as UTF-8 and return it
  return utf8.encode(formattedMessage);
}
