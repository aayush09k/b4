import 'dart:convert';
import 'dart:io';



class TcpClient {
    //There are two types of nodes that I have defined: 'cNode' for client-type nodes and 'sNode' for server-type nodes.

    late Socket _loCalcNodeSocket;// Sockets as Map. so that we can differentiate cNode connections. It is for future purpose.
    bool _isConnected = false; // If you are connected to some node then _isConnected = true;
    ServerSocket? _loCalsNodeSocket; // sNode-socket stored here.


    dynamic _parsecNodeMessage; // Used for parsing message coming from the cNode.
    dynamic _decodesNodeMessage; // Used for message received from sNode.
    final Map <dynamic, List<int>> _buffer = {
    }; //Used for storing messages, which are then processed further


    final Map<String, Socket> _remoTecNodeSocket = {
    }; // To save all remote cNode Sockets. It is used to relay messages.
    bool _isListening = false; //If you are Listening for connection  then _isListening  = true;
    dynamic relayBackToNodeKey; //When a NATed node receives a relay request, it also receives a key to relay messages back to that node. This key is stored in this variable and is used to send messages to that node
    dynamic relayToreMoteNodeKey; // Set by the user for relay connection to a NATed node.

    String? _message;
    String? _connectionKey;
    Socket? receivedSocket;


    // Connect to the sNode
    Future<Socket?> connect(ip, port) async {

        relayBackToNodeKey = null;


        try {
            _loCalcNodeSocket = await Socket.connect(ip, port);
            _isConnected = true;
            print(
                'Connected to remoteNode: ${_loCalcNodeSocket.remoteAddress
                    .address}:${_loCalcNodeSocket.remotePort}');
        }
        on SocketException catch (e) {
            print('Failed to connect: $e');
            _isConnected = false;

        }
        return _loCalcNodeSocket;
    }

    // Start as a sNode
    Future<ServerSocket?> startASsNode(listeningPort) async {

        relayToreMoteNodeKey = null;


        try {
            _loCalsNodeSocket =
            await ServerSocket.bind(
                InternetAddress.anyIPv6, 22355, v6Only: false);
            _isListening = true;
        }
        catch (e) {
            print(
                'not able to create server on ipv6 so now creating on ipv4...');
            _loCalsNodeSocket =
            await ServerSocket.bind(InternetAddress.anyIPv4, 0);
            _isListening = true;
        }
        print('Server: started  on port ${_loCalsNodeSocket!.port}');

        return _loCalsNodeSocket;
    }

    Future<Socket?> receiveAsaServer(Function(dynamic message) onDataReceived) async
    {
        // Listen for incoming  connection from any cNode.
        _loCalsNodeSocket!.listen((socket) {
            receivedSocket=socket;
            print('RemoteNode is Connected to us from ${socket.remoteAddress
                .address}:${socket.remotePort}');
            // Invokes whenever some data comes from other cNode.
            socket.listen(
                    (data) async {
                    _parsecNodeMessage =
                    await _processData(socket, data);

                    if (_parsecNodeMessage != null) {
                        _handleMessageFroMcNode(
                            socket, _parsecNodeMessage);
                        onDataReceived(_parsecNodeMessage);

                    }
                },
                onError: (error) async {
                    print('Server and network  Error: $error');

                },
                onDone: () async {

                },
            );

        }
        );
      return receivedSocket;
    }

    //Data send back to the client according to the key.
    Future relayBackToNode(key, message) async {
        print('relay back to node krne agya');
        List<int> messageBytes = utf8.encode(
            message); // Encode the JSON message
        int length = messageBytes.length; // Calculate the message length
        var lengthBytes = [
            (length >> 24) & 0xFF,
            (length >> 16) & 0xFF,
            (length >> 8) & 0xFF,
            length & 0xFF
        ]; // Prepare the length header
        try {
            _remoTecNodeSocket[key]!.add(lengthBytes); // Send the length header
            _remoTecNodeSocket[key]!.add(
                messageBytes); // Send the message bytes
            _remoTecNodeSocket[key]!.flush();
        } // Ensure the data is sent immediately
        catch (e) {
            print(e);
        }
    }

    // Send a message to the sNode or any relayed node.
    Future<void> send(message,Socket nodeSocket) async {
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

        if (!_isConnected) {
            print('Client is not connected to a server.');
            return;
        }
        else {
            try {
                nodeSocket.add(
                    lengthBytes); // Send the length header
                nodeSocket.add(
                    messageBytes); // Send the message bytes
                nodeSocket.flush();
            } // Ensure the data is sent immediately
            catch (e) {
                print(e);
            }
        }
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
    Future receiveAsaClient(Function(dynamic message) onDataReceived,Socket nodeSocket) async {
        if (!_isConnected) {
            print('Client is not connected to a server.');
            return;
        }
        nodeSocket.listen(
                (data) async {

                _decodesNodeMessage =
                await _processData(_loCalcNodeSocket, data);

                if (_decodesNodeMessage != null) {
                     onDataReceived(_decodesNodeMessage);
                }

            },
            onError: (error) {
                print('Error: $error');
                _isConnected = false;
            },
            onDone: () {
                try {
                    print('remoteNode  left.');
                    relayBackToNodeKey = null;
                    _isConnected = false;


                }
                catch (e) {
                    print('remoteNode  left.');
                    _isConnected = false;
                    relayBackToNodeKey = null;
                }
            },
        );
    }

    // Close the connection from sNode.
    void disconnectFroMsNode(Socket nodeSocket) {
        try {
            nodeSocket.destroy();
            _isConnected = false;
            print('Disconnected from the proxy');

        }
        catch (e) {
            _isConnected = false;
            print('Disconnected error=$e');
        }
    }

    // creates json string for sending messages.
    String createMessageJson(type, A, B, C, D, length) {
        Map<String, dynamic> message = {
            't': type,
            'p1': A,
            // p1=none for l=3. otherwise p1=IP.
            'p2': B,
            // p2=relayToNodeKey for l=4,5,default. p2=nil for l=3. p2=Port for l=6.
            'p3': C,
            // p3=myKey for l=default,5,4. p3=remoteKey for l=6.p3=ipv6 for l=3.
            'p4': D,
            // p4=message for l=default,5,4. p4=myKey for l=6. p4=ipv6port for l=3.
            'l': length
        };
        return json.encode(message);
    }


    void _handleMessageFroMcNode(Socket socket, decodedMessage) async {
        print(
            'public message handler kerne agye me or mera msg = $decodedMessage');

        //For l=6 means message came for setup smooth flow between nodes.
        if (decodedMessage['l'] == 6) {
            if (decodedMessage['t'] == 'MP') {
                print('me t=MP,l=6 ke if me agya');
                try {
                    print(decodedMessage);
                    _message = createMessageJson(
                        null, null, socket.port, null,
                        'I am your proxy server i will let you connect to the world bro . Please press any key to continue.',
                        0);
                    _remoTecNodeSocket[decodedMessage['p4']] = socket;

                    await relayBackToNode(decodedMessage['p4'], _message);

                }
                catch (e) {
                    print('me t=MP,l=6 ke if ke catch me agya');
                    await relayBackToNode(
                        decodedMessage['p4'], createMessageJson(
                        null, null, null, null,
                        'error in proxy connection=$e', 0));
                }

            }
            else {
                try {
                    print('me t=D,l=6 ke try me agya');
                    _connectionKey = decodedMessage['p4'];
                    _remoTecNodeSocket[decodedMessage['p4']] = socket;
                    _message = createMessageJson(
                        null, null, null, null,
                        'your are now directly connected to me as we both are publicly available',
                        0);
                    await relayBackToNode(decodedMessage['p4'], _message);


                }
                catch (e) {
                    print('me t=D,l=6 ke catch me agya');
                    print(e);
                }
            }
        }
        // This l=4 is used for relaying messages to nodes. All relaying messages are sent to other nodes from here only
        else if (decodedMessage['l'] == 4) {
            if (decodedMessage['t'] == 'TP') {
                print('me t=TP,l=4 ke if me agya');

                try {
                    print('me t=TP,l=4  ke try ke else  me agya.');
                        if (_remoTecNodeSocket[decodedMessage['p2']] != null) {
                            await relayBackToNode(decodedMessage['p2'],
                                createMessageJson(
                                    null, null, null, null,
                                    decodedMessage['p4'],
                                    0));
                        }
                        else {
                            // By mistake or due to any network issue if some node in relay connection get disconnected from proxy.
                            // Then other peer will got this message below.
                            String toSend = createMessageJson(
                                null, null, null, null,
                                'Other Node is no more connected.',
                                0);
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
                catch (e) {
                    print('me t=TP,l=4  ke catch  me agya. or error he =$e');
                }
            }
            else {
                print('l=4 ke else me agya');
                print(decodedMessage['p4']);
            }
        }
        // l=5 provides a NATed node(ipv4) to relay with ipv6 via this proxy sNode.
        else if (decodedMessage['l'] == 5) {
            print('l=5 me agya');

                try {
                    print(
                        'l=5 ke else me try me "no reyling connection bhejne agya me "');
                    await relayBackToNode(
                        decodedMessage['p3'], createMessageJson(
                        null, null, null, null,
                        'no relaying connection exits ',
                        0));
                }
                catch (e) {
                    print('l=5 me catch me agya');
                    print(e);
                }

        }

        else {
            print(decodedMessage['p4']);
        }
    }

    // Stop the server
    Future<void> stopASsNode() async {
        try {
            _loCalsNodeSocket!.close();
            _isListening = false;
            print('Server stopped.');

        }
        catch (e) {
            _isListening = false;
            print('Server Stop error=$e');
        }
    }

    // Some variables used in b4connection hence they can use by accessing these function.
    String? Key() => _connectionKey;

    bool isConnected() => _isConnected;

    bool isListening() => _isListening;

}
