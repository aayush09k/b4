import 'dart:io';

void main() {
  // Define the server address and port
  String serverAddress = '127.0.0.1'; // Assuming the server is running on localhost
  int serverPort = 3478; // Assuming the server is listening on port 3478

  // Define destination data and application data for the TURN messages
  List<Map<String, dynamic>> messages = [
    {'destination': 'clientB', 'applicationData': 'Hello from Client A'},
    {'destination': 'clientA', 'applicationData': 'Hello from Client B'}
  ];

  // Create a UDP socket for the client
  RawDatagramSocket.bind(InternetAddress.anyIPv4, 0).then((socket) {
    print('UDP client socket created.');

    // Send TURN messages to the server
    for (var message in messages) {
      // Construct the message as per the TURN protocol
      String turnMessage = '${message['destination']}:${message['applicationData']}';
      // Send the message to the server
      socket.send(turnMessage.codeUnits, InternetAddress(serverAddress), serverPort);
      print('Client sent: $turnMessage');
    }

    // Listen for responses from the server
    socket.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        Datagram? datagram = socket.receive();
        if (datagram != null) {
          String response = String.fromCharCodes(datagram.data);
          print('Client received response from server: $response');
        }
      }
    });
  }).catchError((e) {
    print('Error creating UDP client socket: $e');
  });
}
