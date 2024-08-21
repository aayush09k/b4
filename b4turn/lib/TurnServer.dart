// DATED 19 AUG 24
import 'dart:async'; // Used for Timer
import 'dart:io'; // Provides RawDatagramSocket and InternetAddress
import 'dart:convert'; // For UTF-8 encoding and decoding
import 'dart:typed_data'; // For Uint8List

// Flag to check if the application is running in debug mode
const bool isDebugMode = false; // Hardcoded to false for production

// Custom debug print function
void debugPrint(String message) {
  if (isDebugMode) {
    print(message);
  }
}

class TurnServer {
  // A map to keep track of all active allocations. The key is the client ID.
  final Map<String, AllocationEntry> _allocationTable = {};
  // A map to keep track of permissions for each client. The key is the client ID.
  final Map<String, List<String>> _permissionsTable = {};

  // Starts the TURN server
  void startTurnServer() async {
    try {
      // Bind the server to listen on any IPv4 address on port 3478
      var socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 3478);
      debugPrint('TURN server listening on port 3478');

      // Set up the server to listen for incoming datagrams
      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          Datagram? datagram = socket.receive();
          if (datagram != null) {
            debugPrint('Received datagram from ${datagram.address.address}:${datagram.port}');
            handleMessage(datagram, socket);
          }
        }
      });

      // Optionally: Print allocations when the server starts
      printCurrentAllocations();
    } catch (e) {
      // Catch and print any errors that occur while starting the server
      debugPrint('Error starting TURN server: $e');
    }
  }

  // Handles incoming messages and determines their type
  void handleMessage(Datagram datagram, RawDatagramSocket socket) {
    // Get a unique client ID based on the sender's IP address and port
    String clientId = getClientId(datagram.address, datagram.port);
    List<int> requestData = datagram.data;

    debugPrint('Received TURN request from $clientId');
    debugPrint('Request Data: $requestData');

    // Check if the datagram is a TURN request
    if (isTurnRequest(datagram.data)) {
      debugPrint('Valid TURN request from $clientId');
      // Check if an allocation already exists for the client
      if (!_allocationTable.containsKey(clientId)) {
        // If no allocation exists, authenticate and allocate resources
        authenticateAndAllocate(socket, clientId, datagram.address, datagram.port);
      } else {
        debugPrint('Allocation already exists for $clientId');
      }
    } else if (isSendIndication(datagram.data)) {
      // If it's a SendIndication message, handle it
      handleSendIndication(socket, clientId, datagram);
    } else if (isCreatePermissionRequest(datagram.data)) {
      // If it's a CreatePermission request, process it
      handleCreatePermissionRequest(socket, clientId, datagram);
    } else {
      // If the datagram is neither a recognized request nor a SendIndication or CreatePermission request
      debugPrint('Received datagram is not a recognized request from $clientId');
    }
  }

  // Checks if the packet is a TURN allocation request
  bool isTurnRequest(List<int> packet) {
    // TURN request identified by the first two bytes being 0x00 and 0x03
    return packet.length > 1 && packet[0] == 0x00 && packet[1] == 0x03;
  }

  // Checks if the packet is a SendIndication message
  bool isSendIndication(List<int> packet) {
    // SendIndication message identified by specific byte values (example: 0x00 and 0x06)
    return packet.length > 1 && packet[0] == 0x00 && packet[1] == 0x06;
  }

  // Checks if the packet is a CreatePermission request
  bool isCreatePermissionRequest(List<int> packet) {
    // CreatePermission request identified by specific byte values (example: 0x00 and 0x08)
    return packet.length > 1 && packet[0] == 0x00 && packet[1] == 0x08;
  }

  // Constructs a unique client ID based on the sender's IP address and port
  String getClientId(InternetAddress address, int port) {
    return '${address.address}:$port';
  }

  // Authenticates the client and allocates resources if authentication is successful
  void authenticateAndAllocate(RawDatagramSocket socket, String clientId, InternetAddress clientAddress, int clientPort) {
    // In a real scenario, add proper authentication logic here
    bool authenticated = true; // Placeholder for authentication

    if (authenticated) {
      // Determine the server's IP address and port for relaying
      String serverIpAddress = InternetAddress.anyIPv4.address; // This should typically be the public IP
      int relayedTransportPort = socket.port;
      String relayedTransportAddress = '$serverIpAddress:$relayedTransportPort';

      // Create an allocation entry for the client
      _allocationTable[clientId] = AllocationEntry(
        clientId: clientId,
        serverReflexiveIp: clientAddress.address,
        serverReflexivePort: clientPort,
        relayedTransportAddress: relayedTransportAddress,
        // Set a timer to expire the allocation after 10 minutes
        timer: Timer(Duration(minutes: 10), () {
          // Remove allocation when the timer expires
          _allocationTable.remove(clientId);
          _permissionsTable.remove(clientId);
          debugPrint('Allocation closed for $clientId (timer expiry)');
        }),
      );

      // Send the relayed transport address back to the client
      socket.send(utf8.encode(relayedTransportAddress), clientAddress, clientPort);
      debugPrint('Allocation created for $clientId');

      // Print current allocations after creating a new one
      printCurrentAllocations();
    } //else {
      //debugPrint('Authentication failed for $clientId');
   // }
  }

  // Handles SendIndication messages
  void handleSendIndication(RawDatagramSocket socket, String clientId, Datagram datagram) {
    // Extract the application data and peer address from the request data
    String peerAddress = extractPeerAddress(datagram.data);
    String applicationData = extractApplicationData(datagram.data);

    if (peerAddress.isNotEmpty && applicationData.isNotEmpty) {
      // Forward the application data to the peer
      forwardData(socket, clientId, peerAddress, applicationData);
    } else {
      debugPrint('Failed to extract peer address or application data from SendIndication for $clientId');
    }
  }

  // Extracts the peer address from SendIndication request data
  String extractPeerAddress(List<int> requestData) {
    // Example extraction logic (replace with actual logic as per TURN protocol)
    if (requestData.length > 8) {
      return '${requestData[2]}.${requestData[3]}.${requestData[4]}.${requestData[5]}:${requestData[6] << 8 | requestData[7]}';
    }
    return '';
  }

  // Extracts the application data from SendIndication request data
  String extractApplicationData(List<int> requestData) {
    // Example extraction logic (replace with actual logic as per TURN protocol)
    return utf8.decode(requestData.sublist(8));
  }

  // Handles CreatePermission requests
  void handleCreatePermissionRequest(RawDatagramSocket socket, String clientId, Datagram datagram) {
    // Extract the peer address from the request data
    String peerAddress = extractPeerAddress(datagram.data);
    if (peerAddress.isNotEmpty) {
      _permissionsTable.putIfAbsent(clientId, () => []).add(peerAddress);
      debugPrint('Permission granted for $clientId to communicate with $peerAddress');
      sendCreatePermissionResponse(socket, datagram.address, datagram.port);
    } else {
      debugPrint('Failed to extract peer address from CreatePermission request for $clientId');
    }
  }

  // Sends an acknowledgment response for CreatePermission requests
  void sendCreatePermissionResponse(RawDatagramSocket socket, InternetAddress clientAddress, int clientPort) {
    // Construct a response message (example format)
    List<int> response = [0x01, 0x08]; // Example response type for CreatePermission acknowledgment
    socket.send(Uint8List.fromList(response), clientAddress, clientPort);
    debugPrint('CreatePermission response sent to ${clientAddress.address}:$clientPort');
  }

  // Forwards data to the specified destination
  void forwardData(RawDatagramSocket socket, String clientId, String peerAddress, String applicationData) {
    try {
      // Prepare the message to be forwarded
      String message = '$clientId: $applicationData';
      Uint8List messageBytes = utf8.encode(message);

      // Check if client is permitted to communicate with the destination
      if (_permissionsTable[clientId]?.contains(peerAddress) ?? false) {
        // Send the message to the destination address and port
        socket.send(messageBytes, InternetAddress(peerAddress), 3478); // Example port number
        debugPrint('Forwarding data from $clientId to $peerAddress: $applicationData');
      } else

      {
        debugPrint('Permission denied for $clientId to communicate with $peerAddress');
      }
    } catch (e) {
      // Catch and print any errors that occur during data forwarding
      debugPrint('Error forwarding data from $clientId: $e');
    }
  }

  // Prints the current allocations
  void printCurrentAllocations() {
    debugPrint('Current Allocations:');
    // Iterate through the allocation table and print details of each allocation
    _allocationTable.forEach((clientId, allocation) {
      debugPrint('Client ID: $clientId, Allocation: serverReflexiveIp: ${allocation.serverReflexiveIp}, serverReflexivePort: ${allocation.serverReflexivePort}, relayedTransportAddress: ${allocation.relayedTransportAddress}');
    });
  }
}

// Represents an allocation entry for a client
class AllocationEntry {
  String clientId; // Unique ID of the client
  String serverReflexiveIp; // IP address of the client as seen by the server
  int serverReflexivePort; // Port number of the client as seen by the server
  String relayedTransportAddress; // Address used for relayed transport
  Timer timer; // Timer to expire the allocation

  AllocationEntry({
    required this.clientId,
    required this.serverReflexiveIp,
    required this.serverReflexivePort,
    required this.relayedTransportAddress,
    required this.timer,
  });
}

void main() {
  // Create a TURN server instance and start it
  TurnServer turnServer = TurnServer();
  turnServer.startTurnServer();
}