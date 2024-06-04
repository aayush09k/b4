/*   Squadron Leader Tarun Chaudhary    */
import 'dart:async'; // Used for Timer
import 'dart:io'; // Provides RawDatagramSocket and InternetAddress
import 'dart:convert'; // For UTF-8 encoding and decoding
import 'dart:typed_data'; // For Uint8List

class TurnServer {
  // A map to keep track of all active allocations. The key is the client ID.
  final Map<String, AllocationEntry> _allocationTable = {};

  // Starts the TURN server
  void startTurnServer() async {
    try {
      // Bind the server to listen on any IPv4 address on port 3478
      var socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 3478);
      print('TURN server listening on port 3478');

      // Set up the server to listen for incoming datagrams
      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          Datagram? datagram = socket.receive();
          if (datagram != null) {
            print('Received datagram from ${datagram.address.address}:${datagram.port}');
            handleMessage(datagram, socket);
          }
        }
      });

      // Optionally: Print allocations when the server starts
      printCurrentAllocations();
    } catch (e) {
      // Catch and print any errors that occur while starting the server
      print('Error starting TURN server: $e');
    }
  }

  // Handles incoming messages and determines their type
  void handleMessage(Datagram datagram, RawDatagramSocket socket) {
    // Get a unique client ID based on the sender's IP address and port
    String clientId = getClientId(datagram.address, datagram.port);
    List<int> requestData = datagram.data;

    print('Received TURN request from $clientId');
    print('Request Data: $requestData');

    // Check if the datagram is a TURN request
    if (isTurnRequest(datagram.data)) {
      print('Valid TURN request from $clientId');
      // Check if an allocation already exists for the client
      if (!_allocationTable.containsKey(clientId)) {
        // If no allocation exists, authenticate and allocate resources
        authenticateAndAllocate(socket, clientId, datagram.address, datagram.port);
      } else {
        print('Allocation already exists for $clientId');
      }
    } else if (isForwardRequest(datagram.data)) {
      // If it's a forward request, forward the data
      forwardData(socket, clientId, String.fromCharCodes(datagram.data));
    } else {
      // If the datagram is neither a TURN request nor a forward request
      print('Received datagram is not a TURN request from $clientId');
    }
  }

  // Checks if the packet is a TURN allocation request
  bool isTurnRequest(List<int> packet) {
    // TURN request identified by the first two bytes being 0x00 and 0x03
    return packet.length > 1 && packet[0] == 0x00 && packet[1] == 0x03;
  }

  // Checks if the packet is a data forwarding request
  bool isForwardRequest(List<int> packet) {
    // Forward requests start with the word "SEND"
    String data = utf8.decode(packet);
    return data.startsWith('SEND');
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
          print('Allocation closed for $clientId (timer expiry)');
        }),
      );

      // Send the relayed transport address back to the client
      socket.send(utf8.encode(relayedTransportAddress), clientAddress, clientPort);
      print('Allocation created for $clientId');

      // Print current allocations after creating a new one
      printCurrentAllocations();
    } else {
      print('Authentication failed for $clientId');
    }
  }

  // Forwards data to the specified destination
  void forwardData(RawDatagramSocket socket, String clientId, String data) {
    try {
      // Parse the forwarded data
      List<String> parts = data.split(' ');
      if (parts.length < 4) {
        print('Malformed data received from $clientId: $data');
        return;
      }

      // Extract the destination address and port
      String destinationAddress = parts[1].trim();
      int destinationPort = int.parse(parts[2].trim());
      // Extract the actual application data to be forwarded
      String applicationData = parts.sublist(3).join(' ').trim();

      // Prepare the message to be forwarded
      String message = '$clientId: $applicationData';
      Uint8List messageBytes = utf8.encode(message);
      // Send the message to the destination address and port
      socket.send(messageBytes, InternetAddress(destinationAddress), destinationPort);
      print('Forwarding data from $clientId to $destinationAddress:$destinationPort: $applicationData');
    } catch (e) {
      // Catch and print any errors that occur during data forwarding
      print('Error forwarding data from $clientId: $e');
    }
  }

  // Prints the current allocations
  void printCurrentAllocations() {
    print('Current Allocations:');
    // Iterate through the allocation table and print details of each allocation
    _allocationTable.forEach((clientId, allocation) {
      print('Client ID: $clientId, Allocation: serverReflexiveIp: ${allocation.serverReflexiveIp}, serverReflexivePort: ${allocation.serverReflexivePort}, relayedTransportAddress: ${allocation.relayedTransportAddress}');
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
