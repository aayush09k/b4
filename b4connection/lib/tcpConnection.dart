import 'dart:convert';
import 'dart:io';



class TcpClient {
    //There are two types of nodes that I have defined: 'cNode' for client-type nodes and 'sNode' for server-type nodes.

    late Socket _loCalcNodeSocket; // cNode-socket stored here.
    ServerSocket? _loCalsNodeSocket; // sNode-socket stored here.

    dynamic _decodesNodeMessage; // Used for message received from sNode.
    final Map <dynamic, List<int>> _buffer = {
    }; //Used for storing messages, which are then processed further


    final Map<String, Socket> _remoTecNodeSocket = {
    }; // To save all remote cNode Sockets. It is used to relay messages.


    String? _message;


    // Connect to the server type node(sNode).
    Future<Socket?> connect(ip, port) async {
        InternetAddress iP = InternetAddress(ip);
        try {
            _loCalcNodeSocket = await Socket.connect(iP, port);

            print(
                'Connected to remoteNode: ${_loCalcNodeSocket.remoteAddress
                    .address}:${_loCalcNodeSocket.remotePort}');
            return _loCalcNodeSocket;
        }
        on SocketException catch (e) {
            print('Failed to connect: $e');
            return null;
        }
    }

    // Start as a sNode.
    Future<ServerSocket?> startASsNode(listeningPort) async {
        try {
            _loCalsNodeSocket =
            await ServerSocket.bind(
                InternetAddress.anyIPv6, listeningPort, v6Only: false);
        }
        catch (e) {
            print(e);
        }
        print('Server: started  on port ${_loCalsNodeSocket!.port}');

        return _loCalsNodeSocket;
    }

   //Receive sockets from the clients.
    Future receiveSocketsFromCNode(Function(Socket socket) onDataReceived) async
    {
        // Listen for incoming  connection from any cNode.
        _loCalsNodeSocket!.listen((socket) {
            print('RemoteNode is Connected to us from ${socket.remoteAddress
                .address}:${socket.remotePort}');

            onDataReceived(socket);
        }
        );
    }

    //It is used to rely the data of the requested remoteNode.
    Future relayBackToNode(key, message) async {

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

    // Close the connection if any given socket.
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

    // Message handling should be done when node is publicly available.
    void _handleMessageFroMNode(decodedMessage, Socket socket) async {
        if (decodedMessage['type'] == 'MP') {
            if (decodedMessage['myNodeID'] != null) {
                _remoTecNodeSocket[decodedMessage['myNodeID']] = socket;
                _message = createMessageJson(null, null, null,
                    'I am your proxy server i will let you connect to the world bro . Please press any key to continue.');
                await relayBackToNode(decodedMessage['myNodeID'], _message);
            }
        }
        else if (decodedMessage['type'] == 'D') {
            if (decodedMessage['myNodeID'] != null) {
                _remoTecNodeSocket[decodedMessage['myNodeID']] = socket;
                _message = createMessageJson(
                    null, null,null,
                    'your are now directly connected to me as we both are publicly available',
                );
                await relayBackToNode(decodedMessage['myNodeID'], _message);
            }
        }
        else if (decodedMessage['type'] == 'TP') {


            if (_remoTecNodeSocket[decodedMessage['remoteNodeID']] !=
                null) {

                String toSend = createMessageJson(
                    null,null,null, decodedMessage['message']);

                await relayBackToNode(
                    decodedMessage['remoteNodeID'], toSend);
            }
            else {

                // By mistake or due to any network issue if some node in relay connection get disconnected from proxy.
                // Then other peer will got this message below.
                String toSend = createMessageJson(
                    null, null, null,
                    'Other Node is no more connected.',
                );
                List<int> messageBytes = utf8.encode(
                    toSend); // Encode the JSON message
                int length = messageBytes
                    .length; // Calculate the message length
                var lengthBytes = [
                    (length >> 24) & 0xFF,
                    (length >> 16) & 0xFF,
                    (length >> 8) & 0xFF,
                    length & 0xFF
                ];
                socket.add(lengthBytes);
                socket.add(messageBytes);
                socket.flush();
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
