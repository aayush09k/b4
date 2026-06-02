import 'dart:convert';
import 'dart:io';

class TcpConnection {
    // The TcpConnection class is considered to be one of the  fundamental component of the cm API framework.This class is not compatible with the web browser.
    // This class is an abstraction built on top of the raw TCP socket library to offer additional functionality, as outlined below.
    // This class allow to establish a connection and provides a socket that may be utilised for both sending data over the socket and receiving incoming data.
    // Additionally,have functionality to bind the device to a specific port  and provide a server-socket.
    // The server socket then used to receive socket requests from nodes.
    // This class is designed to listen for incoming socket requests from other nodes and give the received socket for further use.
    // Whenever a reroute request and reroute registration request are received, they are not forwarded to a higher-level API.
    // The handling of such requests is implemented within this class.
    // This class Ensure that the data is processed before sending and after receiving to prevent any errors during transmission.
    // This class allows you to send, close, and listen on specified sockets.The received data is not stored in a shared buffer at this layer.
    // There are two types of nodes that I have defined for this class: 'cNode' for client-type nodes and 'sNode' for server-type nodes.

    late Socket _loCalcNodeSocket; // cNode-socket stored here.
    ServerSocket? _loCalsNodeSocket; // sNode-socket stored here.

    dynamic _decodesNodeMessage; // Used for message received from sNode.
    final Map <dynamic, List<int>> _buffer = {
    }; //Used for storing messages, which are then processed further


    final Map<String, Socket> _remoTecNodeSocket = {
    }; // To save all remote cNode Sockets. It is used to relay messages.


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

    // Close the connection for any given socket.
    void closeConnection(Socket socket) {
        try {
            socket.destroy();
        }
        catch (e) {
            print(e);
        }
    }


    // creates json string for sending messages.
    String createMessageJson(type, remoteNodeId, myNodeId, mesSage) {
        Map<String, dynamic> message = {
            'type': type,
            'remoteNodeID': remoteNodeId,
            'myNodeID': myNodeId,
            'message': mesSage,
        };
        return json.encode(message);
    }


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

    // Stop the server
    Future<void> stopASsNode() async {
        if (_loCalsNodeSocket != null) {
            _loCalsNodeSocket!.close();
        }
    }

}
