import 'dart:convert';
import 'dart:io';

class TcpConnection {
    /// The TcpConnection class is considered to be one of the  fundamental component of the cm API framework.This class is not compatible with the web browser.
    /// This class is an abstraction built on top of the raw TCP socket library to offer additional functionality, as outlined below.
    /// This class allow to establish a connection and provides a socket that may be utilised for both sending data over the socket and receiving incoming data.
    /// Additionally,have functionality to bind the device to a specific port  and provide a server-socket.
    /// The server socket then used to receive socket requests from nodes.
    /// This class is designed to listen for incoming socket requests from other nodes and give the received socket for further use.
    /// Whenever a reroute request and reroute registration request are received, they are not forwarded to a higher-level API.
    /// The handling of such requests is implemented within this class.
    /// This class Ensure that the data is processed before sending and after receiving to prevent any errors during transmission.
    /// This class allows you to send, close, and listen on specified sockets.The received data is not stored in a shared buffer at this layer.
    /// There are two types of nodes that I have defined for this class: 'cNode' for client-type nodes and 'sNode' for server-type nodes.
    /// A foundational class in the cm API framework for TCP communication between nodes.
    ///
    /// `TcpConnection` provides a high-level abstraction over raw TCP sockets, enabling both client (`cNode`) and server (`sNode`) node types to communicate efficiently. This class is **not** browser-compatible and is intended for use in environments like desktop or server-side Dart.
    ///
    /// ### Core Features:
    /// - Establishes TCP connections as a client (`cNode`) using [connect].
    /// - Listens for incoming TCP connections as a server (`sNode`) using [startASsNode].
    /// - Accepts and processes connections from remote clients using [receiveSocketsFromCNode].
    /// - Enables bidirectional data communication over sockets with [send].
    /// - Includes functionality for rerouting messages to NATed clients with [_rerouteBehindNAT].
    /// - Handles message framing and decoding using a custom 4-byte length prefix with [_processData].
    ///
    /// ### Design Highlights:
    /// - Maintains separate sockets for client (`_loCalcNodeSocket`) and server (`_loCalsNodeSocket`) roles.
    /// - Stores and manages connected sockets from remote nodes in [_remoTecNodeSocket].
    /// - Uses internal buffers to accumulate and decode streamed data safely.
    ///
    /// ### Node Terminology:
    /// - `cNode`: Client node initiating outbound TCP connections.
    /// - `sNode`: Server node listening for and accepting inbound TCP connections.
    ///
    /// This class also processes special message types like reroute requests internally, without forwarding them to higher-level layers. It ensures reliable message transmission by framing and buffering each message.
    ///
    /// > Note: All socket communication in this class is length-prefixed to prevent stream fragmentation issues.
    ///
    /// ---
    /// Example usage:
    /// ```dart
    /// final tcp = TcpConnection();
    /// await tcp.startASsNode(8080); // Start as server (sNode)
    ///
    /// Socket? clientSocket = await tcp.connect('127.0.0.1', 8080); // Start as client (cNode)
    /// await tcp.send('Hello server', clientSocket!);
    /// ```

    late Socket _loCalcNodeSocket; // cNode-socket stored here.
    /// cNode-socket stored here.
    ServerSocket? _loCalsNodeSocket; // sNode-socket stored here.
/// sNode-socket stored here.
    dynamic _decodesNodeMessage; // Used for message received from sNode.
    /// Used for storing message received from sNode.
    final Map <dynamic, List<int>> _buffer = {
    }; //Used for storing messages, which are then processed further

///Used for storing messages, which are then processed further. A buffer for incoming storage.
    final Map<String, Socket> _remoTecNodeSocket = {
    }; // To save all remote cNode Sockets. It is used to relay messages.

    /// Connects the client-type node (cNode) to a server-type node (sNode) using a TCP socket.
    ///
    /// This function:
    /// - Validates the [ip] and [port] values.
    /// - Attempts to create a TCP connection to the specified IP address and port.
    /// - If successful, return the socket which is used for further communication.
    ///
    /// Parameters:
    /// - [ip] (`dynamic`): The IP address of the sNode as a string (e.g., `'192.168.1.10'`).
    /// - [port] (`dynamic`): The port number on which the sNode is listening.
    ///
    /// Returns:
    /// - A `Future<Socket?>` that completes with the connected `Socket` if the connection succeeds.
    ///   Returns `null` if either input is invalid or if the connection fails.
    ///
    /// Example usage:
    /// ```dart
    ///Socket? socket = await cnode.connect('127.0.0.1', 4517);
    /// ``

    // Connect to the server type node(sNode).
    Future<Socket?> connect(ip, port) async {
        if ((ip == null) || (port == null)) {
            return null;
        }
        InternetAddress iP = InternetAddress(ip);
        try {
            _loCalcNodeSocket = await Socket.connect(iP, port);
            /*print(
                'Connected to remoteNode: ${_loCalcNodeSocket.remoteAddress
                    .address}:${_loCalcNodeSocket.remotePort}');*/
            return _loCalcNodeSocket;
        }
        on SocketException catch (e) {

            return null;
        }
    }

    // Start as a sNode.
    /// To save all remote cNode Sockets. It is used to relay messages.

    /// Starts the server socket node (sNode) to listen for incoming TCP connections
    /// from other nodes (typically cNodes or client nodes).
    ///
    /// This method:
    /// - Binds the server to any available IPv6 or IPv4 address on the specified [listeningPort].
    /// - Stores the resulting ServerSocket in the `_loCalsNodeSocket` variable for later use.
    /// - Prints the IP address and port on which the server is listening.
    ///
    /// Parameters:
    /// - [listeningPort] (`int`): The port number on which the server should listen for connections.
    ///
    /// Returns:
    /// - A `Future<ServerSocket?>` which completes with the `ServerSocket` object if the bind was successful,
    ///   or `null` if an error occurred.
    ///
    /// Example usage:
    /// ```dart
    /// await sNode.startASsNode(8080);
    /// ```
    Future<ServerSocket?> startASsNode(listeningPort) async {
        try {
            _loCalsNodeSocket =
            await ServerSocket.bind(
                InternetAddress.anyIPv6, listeningPort, v6Only: false,shared: true);
        }
        catch (e) {}
        print('Server: started  on port ${_loCalsNodeSocket!.address.address} ${_loCalsNodeSocket!.port}');
        return _loCalsNodeSocket;
    }

    //Receive sockets from the clients.
    //Function(Socket socket) onDataReceived is a callback function.
    ///Receive sockets from the clients.
  ///Function(Socket socket) onDataReceived is a callback function.
  ///This function takes an takes a callback function as input.The function calls the provided callback.
  ///example usage :
  ///```dart
  ///await Node.receiveSocketsFromCNode((Socket socket){
  ///print('client connected : ${socket}')
  ///});
  ///```
    Future receiveSocketsFromCNode(Function(Socket socket) onDataReceived) async
    {
        // Listen for incoming  connection from any cNode.
        _loCalsNodeSocket!.listen((socket) {
            print('RemoteNode is Connected to us from ${socket.remoteAddress
                .address}:${socket.remotePort}');

            // whenever socket received it calls the call back function onDataReceived with newly connected socket.
            onDataReceived(socket);
        }
        );
    }
/// Reroutes a message to a remote node behind NAT using a previously established socket.
  ///
  /// This function is typically used when the server (`sNode`) needs to relay a message
  /// to a client (`cNode`) that is behind NAT, where direct connections are not possible.
  ///
  /// The message is encoded with a length prefix, which ensures that the receiving side
  /// can properly frame and decode the message.
  ///
  /// Parameters:
  /// - [key] (`dynamic`): A key used to identify the socket in the `_remoTecNodeSocket` map.
  /// - [message] (`String`): The JSON-encoded message string to send.
  ///
  /// Returns:
  /// - A `Future` that completes when the message has been fully sent.
  ///
    //It is used to reroute the data to the requested remoteNode.
    Future _rerouteBehindNAT(key, message) async {
        List<int> messageBytes = utf8.encode(
            message); // Encode the JSON message
        int length = messageBytes.length; // Calculate the message length
        var lengthBytes = [
            (length >> 24) & 0xFF,
            (length >> 16) & 0xFF,
            (length >> 8) & 0xFF,
            length & 0xFF
        ]; // Prepare the length header

        _remoTecNodeSocket[key]!.add(lengthBytes); // Send the length header
        _remoTecNodeSocket[key]!.add(
            messageBytes); // Send the message bytes
        _remoTecNodeSocket[key]!.flush();
        // Ensure the data is sent immediately

    }
///
  /// This function is similar to `_rerouteBehindNAT`, but it sends the message
  /// to a directly connected socket (could be a server or NATed client).
  /// It includes a length prefix to ensure reliable message framing.
  ///
  /// Parameters:
  /// - [message] (`String`): The JSON-encoded message string to be sent.
  /// - [socket] (`Socket`): The Dart Socket object through which the message should be sent.
  ///
  /// Returns:
  /// - A `Future<void>` that completes once the message is flushed.
  ///
  /// Example:
  /// ```dart
  /// String regMessage = cnode.createMessageJson('MP', null, 'client_123', 'Hello sNode');
  ///await cnode.send(regMessage, socket);
  /// ```
    // Send a message to the sNode or any NATed node.
    Future<void> send(message, Socket socket) async {
        //Some processing occurs before sending. This ensures that even if you send a stream of data, the connection will not get lost.
        List<int> messageBytes = utf8.encode(
            message); // Encode the JSON message

        int length = messageBytes.length; // Calculate the message length
        var lengthBytes = [
            (length >> 24) & 0xFF,
            (length >> 16) & 0xFF,
            (length >> 8) & 0xFF,
            length & 0xFF
        ]; // Prepare the length header

    //  await  Future.delayed(Duration(seconds: 2));
        socket.add(
            lengthBytes); // Send the length header
        socket.add(
            messageBytes); // Send the message bytes
        socket.flush();
        // Ensure the data is sent immediately

    }
///Internal helper function for processing messages.
  /// Processes raw data received from the socket and returns a decoded JSON object.
  /// This function accumulates data in a per-socket buffer to handle cases where
  /// messages arrive in fragments or multiple messages arrive together. Each message
  /// is assumed to start with a 4-byte header that specifies the length of the
  /// message body.
  ///
  /// - If a complete message is found in the buffer, it extracts, decodes, and returns it.
  /// - If the data is incomplete, it waits for more data (returns `null`).
  ///
  /// Parameters:
  /// - [socket]: The `Socket` from which the data was received.
  /// - [data]: The chunk of raw data received from the socket.
  ///
  /// Returns:
  /// - A `Future<dynamic>` containing the decoded JSON object if a complete message is
  ///   available, or `null` if the buffer doesn't yet contain a full message.
  ///
  ///Used in [invokeListening].

    //Some processing is done before receiving messages to ensure that the connection stays stable under any condition.
    Future<dynamic> _processData(Socket socket, data) async {
        // Ensure the buffer for this socket exists, or create a new one
        //putIfAbsent: This method checks if buffer has an entry for socket. If it does not, it initializes it with a new empty list (<int>[]).
        // This ensures that buffer[socket] is never null when you try to use addAll.
        _buffer.putIfAbsent(socket, () => <int>[]);

        // Now that we're sure buffer[socket] exists, we can add data safely.
        _buffer[socket]!.addAll(data);

        while (_buffer[socket]!.length >= 4) {
            // Ensure there's enough buffer to read the length
            // Reading length from the buffer
            int length = (_buffer[socket]![0] << 24) +
                (_buffer[socket]![1] << 16) +
                (_buffer[socket]![2] << 8) +
                _buffer[socket]![3];

            if (_buffer[socket]!.length >= 4 + length) {
                // Check if the whole message has arrived
                // Extract the message bytes after the length header
                List<int> messageBytes = _buffer[socket]!.sublist(
                    4, 4 + length);

                // Decode the message from bytes to a UTF-8 string
                var messageDecode = utf8.decode(messageBytes);

                // Remove the processed message from the buffer
                _buffer[socket]!.removeRange(0, 4 + length);

                return jsonDecode(messageDecode);
            } else {
                break; // Not enough data for a full message, wait for more data
            }
        }
    }
///
  /// This function sets up an asynchronous listener on the socket, decodes the
  /// incoming data, and passes it to the callback [onDataReceived]. It also handles
  /// socket errors and client disconnections.
  ///
  /// Parameters:
  /// - [onDataReceived]: A callback function that gets called whenever a message is
  ///   received or when the client disconnects. It receives:
  ///     1. The decoded message (or `'disconnected'` if the socket is closed),
  ///     2. A boolean [active] flag indicating if the connection is still active.
  /// - [socket]: The socket connected to a client node.
  ///
  /// Example usage:
  /// ```dart
  /// sNode.invokeListening((message, active) {
  ///   if (active) {
  ///     print('Message from client: $message');
  ///   } else {
  ///     print('Client disconnected.');
  ///   }
  /// }, socket);
  /// ```

    // Receive data from the sNode.
    Future invokeListening(
        Function(dynamic message, bool active) onDataReceived,
        Socket socket) async {
        // Invokes listening on socket.
        socket.listen(
                (data) async {
                _decodesNodeMessage =
                await _processData(socket, data);

                if (_decodesNodeMessage != null) {
                    onDataReceived(_decodesNodeMessage, true);
                    _handleMessageFroMNode(_decodesNodeMessage, socket);
                }
            },
            onError: (error) {
                print('Error: $error');
            },
            onDone: () {
                // If connection is done from the side of other node then send active=false to the b4connection class to delete the instance of the b4connection.
                onDataReceived('disconnected', false);
            },
        );
    }

    /// Close the connection for any given socket.
    void closeConnection(Socket socket) {
        try {
            socket.destroy();
        }
        catch (e) {
            print(e);
        }
    }


    /// creates json string for sending messages.
    String createMessageJson(type, remoteNodeId, myNodeId, mesSage) {
        Map<String, dynamic> message = {
            'type': type,
            'remoteNodeID': remoteNodeId,
            'myNodeID': myNodeId,
            'message': mesSage,
        };
        return json.encode(message);
    }

/// Private Helper function that deals with message.
  /// Takes the decodedMessage and socket as inputs and sends the message to
    // Message handling should be done whenever a message is received.
    void _handleMessageFroMNode(decodedMessage, Socket socket) async {
        if (decodedMessage['type'] == 'MP') {
            print('relay registered');
            if (decodedMessage['myNodeID'] != null) {
                _remoTecNodeSocket[decodedMessage['myNodeID']] = socket;
            }
        }
        else if (decodedMessage['type'] == 'D') {
            if (decodedMessage['myNodeID'] != null) {
                _remoTecNodeSocket[decodedMessage['myNodeID']] = socket;
            }
        }
        else if (decodedMessage['type'] == 'TP') {
            if (_remoTecNodeSocket[decodedMessage['remoteNodeID']] !=
                null) {
                String toSend = createMessageJson(
                    null, null, null, decodedMessage['message']);

                await _rerouteBehindNAT(

                    decodedMessage['remoteNodeID'], toSend);
            }
        }
    }

    /// Stop the server
    Future<void> stopASsNode() async {
        if (_loCalsNodeSocket != null) {
            _loCalsNodeSocket!.close();
        }
    }

}
