import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

class TurnServer {
  final Map<String, AllocationEntry> _allocationTable = {};
/*
The `startTurnServer` method is the entry point for initializing the TURN server functionality.
It begins by attempting to create a UDP socket bound to port 3478,
 allowing the server to listen for incoming datagrams. Upon successful socket creation,
 it sets up a listener to handle incoming data events. When a datagram is received,
 the method invokes the `handleMessage` function to process the datagram, facilitating client authentication,
  resource allocation, and data forwarding as necessary. If any errors occur during the server initialization process,
  such as failure to bind the socket, the method catches and handles the errors.

 */
  void startTurnServer() async {
    try {
      var socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 3478);
      print('TURN server listening on port 3478');

      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          Datagram? datagram = socket.receive();
          if (datagram != null) {
            handleMessage(datagram, socket);
          }
        }
      });
    } catch (e) {
      print('Error starting TURN server: $e');
    }
  }
/*
The `handleMessage` method in the TURN server code is responsible for processing incoming datagrams.
 It takes a `Datagram` object containing the received data and the associated socket.
 The method first extracts the client ID from the datagram's address and port using the `getClientId` function.
 It then checks if the received data represents a TURN request by calling the `isTurnRequest` method.
  If the data is indeed a TURN request, it further checks if an allocation exists for the client ID in the `_allocationTable`.
  If an allocation does not exist, it calls the `authenticateAndAllocate` method to authenticate the client
  and allocate resources. Regardless of whether the client was authenticated or if an allocation already existed,
   the method then forwards the received data to the appropriate destination peer using the `forwardData` method.
   If the received data is not a TURN request, the method simply prints a message indicating
   that the received datagram is not a TURN request. This method effectively
 handles incoming TURN requests and manages the authentication and resource allocation process for clients.   */


  /* Handling Communication with Multiple Peers:
  Since the TURN message always contains an indication of which peer the client is communicating with,
  the client can use a single allocation to communicate with multiple peers.
   Your TURN server code appropriately handles relaying data between clients and peers,
  allowing for communication with multiple peers using a single allocation.    */

  void handleMessage(Datagram datagram, RawDatagramSocket socket) {
    String clientId = getClientId(datagram.address, datagram.port);

    if (isTurnRequest(datagram.data)) {
      if (!(_allocationTable.containsKey(clientId))) {
        authenticateAndAllocate(socket, clientId, datagram.address, datagram.port);
      }
      forwardData(socket, clientId, String.fromCharCodes(datagram.data));
    } else {
      print('Received datagram is not a TURN request');
    }
  }

  bool isTurnRequest(List<int> packet) {
    int methodOffset = 0;
    return packet.length > methodOffset && packet[methodOffset] == 0x01;
  }

  String getClientId(InternetAddress address, int port) {
    return '${address.address}:$port';
  }
/* The authenticateAndAllocate method in the TURN server code is responsible for authenticating clients
 and allocating resources, specifically a relayed transport address.
 Upon receiving a request from a client, this method first simulates an authentication process
  by setting the authenticated flag based on some predefined logic.
   If the authentication is successful, the method generates a relayed transport address
    using the TURN server's IP address and port, and then creates an entry in the _allocationTable map
    associating the client's ID with the allocated resources. Additionally,
     it sets a timer to automatically remove the allocation after a specified duration (in this case, 10 minutes).
      Finally, it sends a response to the client containing the allocated relayed transport address.
       However, if the authentication fails, it simply prints a message
        indicating authentication failure for the specific client.
*/
  void authenticateAndAllocate(RawDatagramSocket socket, String clientId, InternetAddress clientAddress, int clientPort) {
    bool authenticated = true;

    if (authenticated) {
      String relayedTransportAddress = '${socket.address.address}:${socket.port}';
      _allocationTable[clientId] = AllocationEntry(
        clientId: clientId,
        serverReflexiveIp: clientAddress.address,
        serverReflexivePort: clientPort,
        relayedTransportAddress: relayedTransportAddress,
        timer: Timer(Duration(minutes: 10), () {
          _allocationTable.remove(clientId);
          print('Allocation closed for $clientId (timer expiry)');
        }),
      );
      socket.send(utf8.encode(relayedTransportAddress), clientAddress, clientPort);
      print('Allocation created for $clientId');
    } else {
      print('Authentication failed for $clientId');
    }
  }
/*  The forwardData method in the TURN server code is responsible for
 forwarding data from one client to another through the TURN server.
  It takes the client ID, representing the sender, and the data to be forwarded.
  The method parses the data to extract the destination peer ID and the application data.
  It then checks if the destination peer ID exists in the _allocationTable,
   indicating that an allocation has been made for that peer. If the destination peer is found,
    the method retrieves the relayed transport address associated with that peer from the allocation table.
     It then splits the relayed transport address into its components: the destination IP address and port.
     With this information, it constructs a message containing the sender's client ID and the application data.
      This message is encoded into bytes using UTF-8 encoding. Finally,
      the method uses the UDP socket to send the encoded message to the destination peer's address and port.
      If the destination peer is not found in the allocation table, indicating that no allocation has been made for that peer,
the method prints a message indicating the inability to forward data to the destination peer. */

  void forwardData(RawDatagramSocket socket, String clientId, String data) {
    List<String> parts = data.split(':');
    String destinationPeer = parts[0].trim();
    String applicationData = parts.sublist(1).join(':').trim();
    if (_allocationTable.containsKey(destinationPeer)) {
      AllocationEntry destinationEntry = _allocationTable[destinationPeer]!;
      String relayedTransportAddress = destinationEntry.relayedTransportAddress;
      List<String> addressParts = relayedTransportAddress.split(':');
      InternetAddress destinationAddress = InternetAddress(addressParts[0]);
      int destinationPort = int.parse(addressParts[1]);
      String message = '$clientId:$applicationData';
      Uint8List messageBytes = utf8.encode(message);
      socket.send(messageBytes, destinationAddress, destinationPort);
      print('Forwarding data from $clientId to $destinationPeer: $applicationData');
    } else {
      print('Destination peer $destinationPeer not found. Unable to forward data from $clientId.');
    }
  }
}

class AllocationEntry {
  String clientId;
  String serverReflexiveIp;
  int serverReflexivePort;
  String relayedTransportAddress;
  Timer timer;

  AllocationEntry({
    required this.clientId,
    required this.serverReflexiveIp,
    required this.serverReflexivePort,
    required this.relayedTransportAddress,
    required this.timer,
  });
}

void main() {
  TurnServer turnServer = TurnServer();
  turnServer.startTurnServer();
}
