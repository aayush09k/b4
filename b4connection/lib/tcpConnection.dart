import 'dart:convert';
import 'dart:io';



class TcpClient {
    //There are two types of nodes that I have defined: 'cNode' for client-type nodes and 'sNode' for server-type nodes.

    final Map<int, Socket> _loCalcNodeSocket = {
    }; // Sockets as Map. so that we can differentiate cNode connections. It is for future purpose.
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


    final int _j = 0;
    int? _nodeHandler; // Very important variable used for handling the sending of messages to other nodes.we will se its use in b4connection.
    bool _nullMaker = false; // used to make 'subtype' null in b4connection .
    Map<dynamic, dynamic> partInl5 = {
    }; // Used at line no.=513 . when some NATed node(ipv4) request to start a relayed connection to the ipv6 sNode.


    // Connect to the sNode
    Future<Socket?> connect(ip, port) async {
        _nodeHandler = null;
        relayBackToNodeKey = null;
        _nullMaker = false;

        try {
            _loCalcNodeSocket[_j] = await Socket.connect(ip, port);
            _isConnected = true;
            print(
                'Connected to remoteNode: ${_loCalcNodeSocket[_j]!.remoteAddress
                    .address}:${_loCalcNodeSocket[_j]!.remotePort}');
        }
        on SocketException catch (e) {
            print('Failed to connect: $e');
            _isConnected = false;
            _nullMaker = false;
        }
        return _loCalcNodeSocket[_j];
    }

    // Start as a sNode
    Future<ServerSocket?> startASsNode(listeningPort) async {
        _nodeHandler = null;
        relayBackToNodeKey = null;
        _nullMaker = false;
        relayToreMoteNodeKey = null;


        try {
            _loCalsNodeSocket =
            await ServerSocket.bind(
                InternetAddress.anyIPv6, listeningPort, v6Only: false);
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

    Future receiveAsaServer(Function(dynamic message) onDataReceived) async
    {
        // Listen for incoming  connection from any cNode.
        _loCalsNodeSocket!.listen((socket) {
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
        });

    }

    //Data send back to the client according to the key.
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
    Future<void> send(message) async {
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
                _loCalcNodeSocket[_j]!.add(
                    lengthBytes); // Send the length header
                _loCalcNodeSocket[_j]!.add(
                    messageBytes); // Send the message bytes
                _loCalcNodeSocket[_j]!.flush();
            } // Ensure the data is sent immediately
            catch (e) {
                print(e);
            }
        }
        // When we start a connection, an initial message is sent to establish a smooth flow of communication between the nodes.
        // At that time, we need to assign the node handler a value so that we can facilitate further conversation in an easier manner.
        Map<dynamic, dynamic> split = jsonDecode(message);
        switch (split['t']) {
            case 'MP':
                _nodeHandler = 0;
            case 'TP':
                _nodeHandler = 1;
            case 'DTN':
                _nodeHandler = 3;
            case 'D' :
                _nodeHandler = 3;
        }
    }

    // In case you are an sNode and want to close a connection to a connected cNode, you can do this with this function.
    void remoteSocketCloses(key) {
        try {
            _remoTecNodeSocket[key]!.destroy();
            _connectionKey = null;
        }
        catch (e) {
            print(e);
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
    Future receiveAsaClient(Function(dynamic message) onDataReceived) async {
        if (!_isConnected) {
            print('Client is not connected to a server.');
            return;
        }
        _loCalcNodeSocket[_j]!.listen(
                (data) async {

                _decodesNodeMessage =
                await _processData(_loCalcNodeSocket[_j]!, data);

                if (_decodesNodeMessage != null) {
                    _handleMessageFroMsNode(_decodesNodeMessage);
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
                    _nullMaker = false;
                    /*try {
                        _loCalcNodeSocket[_j]!.close();
                    }
                    catch (e) {
                        print(e);
                    }*/
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
    void disconnectFroMsNode() {
        try {
            _loCalcNodeSocket[_j]!.destroy();
            _isConnected = false;
            _nodeHandler = null;
            print('Disconnected from the proxy');
            relayBackToNodeKey = null;
            _nullMaker = false;
        }
        catch (e) {
            _isConnected = false;
            _nodeHandler = null;
            print('Disconnected error=$e');
            relayBackToNodeKey = null;
            _nullMaker = false;
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
                    _nodeHandler = 0;
                }
                catch (e) {
                    print('me t=MP,l=6 ke if ke catch me agya');
                    await relayBackToNode(
                        decodedMessage['p4'], createMessageJson(
                        null, null, null, null,
                        'error in proxy connection=$e', 0));
                }
            }
            else if (decodedMessage['t'] == 'TP') {



                try {
                    print('me t=TP,l=6 ke try me agya');
                    await relayBackToNode(decodedMessage['p3'],
                        jsonEncode(decodedMessage));


                    _remoTecNodeSocket[decodedMessage['p4']] = socket;
                    _message = createMessageJson(null, null, null, null,
                        "you can relay your message to the key:${decodedMessage['p3']})",
                        0);


                    await relayBackToNode(decodedMessage['p4'], _message);

                    _nodeHandler = 1;
                }
                catch (e) {
                    print('me t=MP,l=6 ke catch me agya');
                    relayBackToNode(decodedMessage['p4'],
                        createMessageJson(null, null, null, null,
                            'having some error in your entered key=$e', 0));
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

                    _nodeHandler = 3;
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
                    if (decodedMessage['p4'] == 'disconnect') {
                        print(
                            'me t=TP,l=4  ke try ke if  me agya.disconnect krne k liye');
                        await relayBackToNode(decodedMessage['p2'],
                            createMessageJson(
                                null, null, null, null, decodedMessage['p4'],
                                4));

                        //Mapping remove logic when relay is disconnected.



                    }
                    else {
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
                }
                catch (e) {
                    print('me t=TP,l=4  ke catch  me agya. or error he =$e');
                }
            }
            else if (decodedMessage['t'] == 'MP') {
                print('me t=MP,l=4 me agya');
                try {
                    if (decodedMessage['p4'] == 'disconnect') {
                        print(
                            'me t=MP,l=4 ke try ke if  me agya.disconnect krne k liye');
                        await relayBackToNode(decodedMessage['p2'],
                            createMessageJson(
                                null, null, null, null, decodedMessage['p4'],
                                4));

                    }
                    else {
                        print('me t=MP,l=4  ke try ke else  me agya.');
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
                }
                catch (e) {
                    print('me t=MP,l=4 ke catch me agya');
                    print(e);
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
                partInl5 = jsonDecode(
                    decodedMessage['p4']);
            }
            catch (e) {
                print(e);
                partInl5['l'] = 0;
            }

            if (partInl5['l'] == 3) {
                print(
                    'l=5 me akr phr message ko khola or part kiya usme l=3 ke if me  agya');
                if (_isConnected) {
                    send(decodedMessage['p4']);
                }
                else {
                    if (partInl5['t'] == 'GP') {
                        print('l=3 t=GP me agya');
                        await connect(partInl5['p3'], partInl5['p4']);
                        if (!_isConnected) {
                            await relayBackToNode(
                                decodedMessage['p3'], createMessageJson(
                                null, null, null, null,
                                'not able to proxy you to the ipv6 node sorry ',
                                0));
                        }
                        else {
                            String toSend = createMessageJson(
                                'D', partInl5['p3'], partInl5['p4'],
                                decodedMessage['p4'],
                                decodedMessage['p3'],
                                6);
                            await send(toSend);
                        }
                    }
                }
            }
            else {
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
        }
        // when node A start relay to node B then node B send a msg to this proxy cNode to setMap 'node B.socketAddress-->node A key'.
        else if (decodedMessage['t'] == 'SetMap') {
            print('default l ke t=setMap me agya ');

        }
        else {
            print(decodedMessage['p4']);
        }
    }


    void _handleMessageFroMsNode(decodeNodeMessage) async {
       // print('me node mesgg handle krne agya mera msg=$decodeNodeMessage');
        //l=6 Setup smooth flow of relay connection.
        //If a node requests a relay, it sends a 'disconnect' message to the previous relaying node,
        // which then ceases to maintain any further relaying connection with this node.
        if (decodeNodeMessage['l'] == 6) {
          //  print(relayBackToNodeKey);
            if (relayBackToNodeKey != null) {
                await send(
                    createMessageJson('TP', null, relayBackToNodeKey, null,
                        'disconnect', 4));
            }
            else if (relayToreMoteNodeKey != null) {
                await send(
                    createMessageJson('TP', null, relayToreMoteNodeKey, null,
                        'disconnect', 4));
            }
            relayBackToNodeKey = decodeNodeMessage['p4'];
            await send(createMessageJson(
                'SetMap', null, null, relayBackToNodeKey, null, 0));
            print('relay connected to $relayBackToNodeKey');
        }
        // When we receive this below message while we are in relaying with another node, two things will happen:
        // 1. If you are a public node in a relaying connection with another peer, you will be disconnected from that node's proxy.
        // 2. If you are a NATed node, you will not be disconnected from the proxy, but your keys to relay messages will become null,
        // and you won't be able to send any further messages

        else {
           // print(decodeNodeMessage['p4']);
            _nullMaker = false;
        }
    }

    // Stop the server
    Future<void> stopASsNode() async {
        try {
            _loCalsNodeSocket!.close();
            _isListening = false;
            relayBackToNodeKey = null;
            print('Server stopped.');
            _nodeHandler = null;
        }
        catch (e) {
            _isListening = false;
            print('Server Stop error=$e');
            _nodeHandler = null;
            _nullMaker = false;
            relayBackToNodeKey = null;
        }
    }

    // Some variables used in b4connection hence they can use by accessing these function.
    String? Key() => _connectionKey;

    bool isConnected() => _isConnected;

    bool isListening() => _isListening;

    int? nodeHandler() => _nodeHandler;

    bool makeRemoteKeyNull() => _nullMaker;



}
