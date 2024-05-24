// updated on 24 April as RFC 8656

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

// Define a class representing a TURN server
class TurnServer {
  // Map to store allocation entries (client ID -> AllocationEntry)
  final Map<String, AllocationEntry> _allocationTable = {};

  // Method to start the TURN server
  void startTurnServer() async {
    try {
      // Bind a UDP socket to port 3478
      var socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 3478);
      print('TURN server listening on port 3478');

      // Listen for events on the socket
      socket.listen((RawSocketEvent event) {
        // If data is available to read
        if (event == RawSocketEvent.read) {
          // Receive a datagram from the socket
          Datagram? datagram = socket.receive();
          // If a datagram is received
          if (datagram != null) {
            // Process the received datagram
            handleMessage(datagram, socket);
          }
        }
      });
    } catch (e) {
      // Handle errors while starting the server
      print('Error starting TURN server: $e');
    }
  }

  // This method handles incoming datagrams.
  // It extracts the client ID from the datagram,
  // checks if an allocation exists for the client,
  // and either forwards the data to the intended destination peer
  // or authenticates and allocates resources for the client if no allocation exists.
  void handleMessage(Datagram datagram, RawDatagramSocket socket) {
    // Extract client ID from datagram
    String clientId = getClientId(datagram.address, datagram.port);

    // Check if the datagram is a TURN request
    if (isTurnRequest(datagram.data)) {
      // If it's a TURN request, process it
      if (!(_allocationTable.containsKey(clientId))) {
        // Forward data to the intended destination peer
        //forwardData(clientId, String.fromCharCodes(datagram.data));
        // Authenticate and allocate resources for the client
        authenticateAndAllocate(clientId, datagram.address, datagram.port, socket);
       // forwardData(clientId, String.fromCharCodes(datagram.data));
      }
      forwardData(clientId, String.fromCharCodes(datagram.data));
    } else {
      // If it's not a TURN request, handle it accordingly
      // For example, you can log the message or ignore it
      print('Received datagram is not a TURN request');
    }
  }

  // Method to authenticate the client and allocate resources.
  void authenticateAndAllocate(String clientId, InternetAddress clientAddress, int clientPort, RawDatagramSocket socket) {
    // Simulate authentication
    bool authenticated = true; // Replace with actual authentication logic

    if (authenticated) {
      // Allocate relayed transport address
      String relayedTransportAddress = '${socket.address.address}:${socket.port}';
      // Create AllocationEntry and add to allocation table
      _allocationTable[clientId] = AllocationEntry(
        clientId: clientId,
        serverReflexiveIp: clientAddress.address,
        serverReflexivePort: clientPort,
        relayedTransportAddress: relayedTransportAddress,
        timer: Timer(Duration(minutes: 10), () {
          // Remove allocation after 10 minutes
          _allocationTable.remove(clientId);
          print('Allocation closed for $clientId (timer expiry)');
        }),
      );
      // Send response to client with allocated relayed transport address
      socket.send(utf8.encode(relayedTransportAddress), clientAddress, clientPort);
      print('Allocation created for $clientId');
    } else {
      // Authentication failed, handle error
      print('Authentication failed for $clientId');
    }
  }

  // Method to forward data to the intended destination peer.
  void forwardData(String clientId, String data) {
    // Extract destination peer and application data from message
    List<String> parts = data.split(':');
    String destinationPeer = parts[0].trim();
    String applicationData = parts.sublist(1).join(':').trim();
    if (_allocationTable.containsKey(destinationPeer)) {
      AllocationEntry destinationEntry = _allocationTable[destinationPeer]!;
      // Use the relayed transport address of the destination peer
      String relayedTransportAddress = destinationEntry.relayedTransportAddress;
      List<String> addressParts = relayedTransportAddress.split(':');
      InternetAddress destinationAddress = InternetAddress(addressParts[0]); // IP address
      int destinationPort = int.parse(addressParts[1]); // Port
      // Prepare the message to be forwarded
      String message = '$clientId:$applicationData';
      Uint8List messageBytes = utf8.encode(message);
      // Forward application data to destination peer via TURN server
      socket.send(messageBytes, destinationAddress, destinationPort);
      print('Forwarding data from $clientId to $destinationPeer: $applicationData');
    } else {
      // Destination peer is not found in the allocation table
      print('Destination peer $destinationPeer not found. Unable to forward data from $clientId.');

    }
  }




  // Method to construct a client ID using the client's IP address and port.
  String getClientId(InternetAddress address, int port) {
    return '${address.address}:$port';
  }

  // Method to check if a datagram contains a TURN request.
  bool isTurnRequest(Uint8List packet) {
    // Offset for the method field in the packet
    int methodOffset = 0;
    // Check if the packet length is greater than the method offset and if the method is 0x01
    return packet.length > methodOffset && packet[methodOffset] == 0x01;
  }
}

// Class representing an allocation entry
class AllocationEntry {
  // Properties of an allocation entry
  String clientId;
  String serverReflexiveIp;
  int serverReflexivePort;
  String relayedTransportAddress;
  Timer timer;

  // Constructor for an allocation entry
  AllocationEntry({
    required this.clientId,
    required this.serverReflexiveIp,
    required this.serverReflexivePort,
    required this.relayedTransportAddress,
    required this.timer,
  });
}

// Main function
void main() {
  // Create an instance of the TurnServer class
  TurnServer turnServer = TurnServer();
  // Start the TURN server
  turnServer.startTurnServer();
}
