import 'dart:convert';
import 'dart:io';
import 'package:psjapp/stungetip.dart';


class TcpClient {

    final stunGet = StunClient();
    final Map<int, Socket> _socket = {
    }; // Sockets as Map. so that we can differentiate connected clients.
    bool _isConnected = false;
    ServerSocket? _serverSocket;

    final Map<dynamic, dynamic> _keySocketMap = {};
    dynamic _parsedPublicMessage;
    dynamic _decodeNodeMessage;
    final Map <dynamic, List<int>> _buffer = {};


    final Map<String, Socket> remoteSocket = {}; // To save all remote Sockets.
    bool _isListening = false;
    dynamic relayToNodeKey; //The receiving node sets a unique node key to facilitate the  brokering of messages from the proxy server.


    String? _message;
    String? _connectionKey;

    List<dynamic>? partGlobal;
    final int _j = 0;
    int? _nodeHandler;
    bool _nullRemoteKey = false;


    // Connect to the server
    Future<void> connect(ip, port) async {
        _nodeHandler = null;
        relayToNodeKey = null;
        _nullRemoteKey = false;

        try {
            _socket[_j] = await Socket.connect(ip, port);
            _isConnected = true;
            print('Connected to remoteNode: ${_socket[_j]!.remoteAddress
                .address}:${_socket[_j]!.remotePort}');
        }
        on SocketException catch (e) {
            print('Failed to connect: $e');
            _isConnected = false;
            _nullRemoteKey = false;
        }
    }

    // Start as a server
    Future<ServerSocket?> startServer() async {
        _nodeHandler = null;
        relayToNodeKey = null;
        _nullRemoteKey = false;

        try {
            _serverSocket =
            await ServerSocket.bind(
                InternetAddress.anyIPv6, 0, v6Only: false);
            _isListening = true;
        }
        catch (e) {
            print(
                'not able to create server on ipv6 so now creating on ipv4...');
            _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
            _isListening = true;
        }
        print('Server: started  on port ${_serverSocket!.port}');
        try {
            _serverSocket!.listen((socket) {
                print('RemoteNode is Connected to us from ${socket.remoteAddress
                    .address}:${socket.remotePort}');
                try {
                    socket.listen(
                            (data) async {
                            _parsedPublicMessage =
                            await _processData(socket, data);

                            if (_parsedPublicMessage != null) {
                                _handleMessagePublic(
                                    socket, _parsedPublicMessage);
                            }
                        },
                        onError: (error) {
                            print('Server: Error: $error');
                        },
                        onDone: () async {
                            try {
                                await relayBackToNode(_keySocketMap[socket
                                    .remoteAddress],
                                    createMessageJson(null, null, null, null,
                                        'disconnect', 4));
                                remoteSocket.remove(
                                    '_keySocketMap[socket.remoteAddress]');
                            }
                            catch (e) {
                                print('error=$e');
                            }

                            try {
                                try {
                                    socket.close();
                                }
                                catch (e) {
                                    print(e);
                                }
                            }
                            catch (e) {
                                print('error=$e');
                            }
                        },
                    );
                }
                catch (e) {
                    print(e);
                }
            });
        }
        catch (e) {
            print(e);
        }
        try {
            return _serverSocket;
        }
        catch (e) {
            print(e);
            return null;
        }
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
            remoteSocket[key]!.write(lengthBytes); // Send the length header
            remoteSocket[key]!.write(messageBytes); // Send the message bytes
            remoteSocket[key]!.flush();
        } // Ensure the data is sent immediately
        catch (e) {
            print(e);
        }
    }

    // Send a message to the server
    Future<void> send(message) async {
        print(message['message']);
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
                _socket[_j]!.add(lengthBytes); // Send the length header
                _socket[_j]!.add(messageBytes); // Send the message bytes
                _socket[_j]!.flush();
            } // Ensure the data is sent immediately
            catch (e) {
                print(e);
            }
        }

        Map<dynamic, dynamic> split = jsonDecode(message);
        switch (split['type']) {
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

    void remoteSocketCloses(key) {
        try {
            remoteSocket[key]!.close();
            _connectionKey = null;
        }
        catch (e) {
            print(e);
        }
    }


    Future<dynamic> _processData(Socket socket, data) async {
        // Ensure the buffer for this socket exists, or create a new one
        //putIfAbsent: This method checks if buffer has an entry for socket. If it does not, it initializes it with a new empty list (<int>[]). This ensures that buffer[socket] is never null when you try to use addAll.
        _buffer.putIfAbsent(socket, () => <int>[]);

        // Now that we're sure buffer[socket] exists, we can add data safely
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

    // Receive data from the server
    void receive(Function(String message) onDataReceived) async {
        if (!_isConnected) {
            print('Client is not connected to a server.');
            return;
        }
        _socket[_j]!.listen(
                (data) async {
                _decodeNodeMessage = await _processData(_socket[_j]!, data);

                if (_decodeNodeMessage != null) {
                    _handleMessageNode(_decodeNodeMessage);
                }
            },
            onError: (error) {
                print('Error: $error');
                _isConnected = false;
            },
            onDone: () {
                try {
                    print('remoteNode  left.');
                    relayToNodeKey = null;
                    _isConnected = false;
                    _nullRemoteKey = true;
                    try {
                        _socket[_j]!.close();
                    }
                    catch (e) {
                        print(e);
                    }
                }
                catch (e) {
                    print('remoteNode  left.');
                    _isConnected = false;
                    relayToNodeKey = null;
                }
            },
        );
    }

    // Close the connection
    Future<void> disconnect() async {
        try {
            await _socket[_j]!.close();
            _isConnected = false;
            _nodeHandler = null;
            print('Disconnected from the proxy');
            relayToNodeKey = null;
            _nullRemoteKey = true;
        }
        catch (e) {
            _isConnected = false;
            _nodeHandler = null;
            print('Disconnected error=$e');
            relayToNodeKey = null;
            _nullRemoteKey = true;
        }
    }

    String? Key() => _connectionKey;

    bool isConnected() => _isConnected;

    bool isListening() => _isListening;

    int? nodeHandler() => _nodeHandler;

    bool makeRemoteKeyNull() => _nullRemoteKey;

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

    void _handleMessagePublic(Socket socket, decodedMessage) async {
        if (decodedMessage['length'] == 6) {
            if (decodedMessage['type'] == 'MP') {
                try {
                    _message = createMessageJson(
                        null, stunGet.getPublicIPv4(), socket.port, null,
                        'I am your proxy server i will let you connect to the world bro . Please press any key to continue.',
                        0);
                    remoteSocket[decodedMessage['p4']] = socket;
                    _connectionKey = decodedMessage['p4'];
                    await relayBackToNode(decodedMessage['p4'], _message);
                    _nodeHandler = 0;
                }
                catch (e) {
                    relayBackToNode(decodedMessage['p4'], createMessageJson(
                        null, null, null, null,
                        'error in proxy connection=$e', 0));
                }
            }
            else if (decodedMessage['type'] == 'DTN') {
                try {
                    _connectionKey = decodedMessage['p4'];
                    remoteSocket[decodedMessage['p4']] = socket;
                    _message = createMessageJson(
                        null, null, null, null,
                        'your are now directly connected to me as we both are publicly available',
                        0);
                    await relayBackToNode(decodedMessage['p4'], _message);
                    _nodeHandler = 3;
                }
                catch (e) {
                    await relayToNodeKey(
                        decodedMessage['p4'], createMessageJson(
                        null, null, null, null,
                        'having error in connection=$e',
                        0));
                }
            }
            else if (decodedMessage['type'] == 'TP') {
                _keySocketMap[socket.remoteAddress] = decodedMessage['p3'];
                try {
                    await relayBackToNode(decodedMessage['p3'],
                        jsonEncode(decodedMessage));


                    remoteSocket[decodedMessage['myKey']] = socket;
                    _message = createMessageJson(null, null, null, null,
                        "you can relay your message to the key:$decodedMessage['remoteKey']",
                        0);
                    _connectionKey = decodedMessage['p4'];

                    await relayBackToNode(decodedMessage['p4'], _message);

                    _nodeHandler = 1;
                }
                catch (e) {
                    await relayBackToNode(decodedMessage['p4'],
                        createMessageJson(null, null, null, null,
                            'having some error in your entered key=$e', 0));
                }
            }
            else {
                try {
                    _connectionKey = decodedMessage['p4'];
                    remoteSocket[decodedMessage['p4']] = socket;
                    _message = createMessageJson(
                        null, null, null, null,
                        'your are now directly connected to me as we both are publicly available',
                        0);
                    await relayBackToNode(decodedMessage['p4'], _message);

                    _nodeHandler = 3;
                }
                catch (e) {
                    print(e);
                }
            }
        }
        else if (decodedMessage['length'] == 4) {
            if (decodedMessage['type'] == 'TP') {
                try {
                    if (decodedMessage['p4'] == 'disconnect') {
                        await relayBackToNode(decodedMessage['p2'],
                            createMessageJson(
                                null, null, null, null, decodedMessage['p4'],
                                4));

                        //Mapping remove logic when relay is disconnected.
                        remoteSocket.remove(
                            '_keySocketMap[socket.remoteAddress]');
                        String? keyToRemove = remoteSocket.keys.firstWhere(
                                (k) => remoteSocket[k] == decodedMessage['p2'],
                            // looking for an age that doesn't exist
                            orElse: () => 'null');
                        remoteSocket.remove(keyToRemove);
                    }
                    else {
                        await relayBackToNode(decodedMessage['p2'],
                            createMessageJson(
                                null, null, null, null, decodedMessage['p4'],
                                0));
                    }
                }
                catch (e) {
                    String toSend = createMessageJson(
                        null, null, null, null,
                        'Other Node is no more connected. error=$e',
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
            else if (decodedMessage['type'] == 'MP') {
                try {
                    if (decodedMessage['message'] == 'disconnect') {
                        await relayBackToNode(decodedMessage['p2'],
                            createMessageJson(
                                null, null, null, null, decodedMessage['p4'],
                                4));
                        //Mapping remove logic when relay is disconnected.
                        remoteSocket.remove(
                            '_keySocketMap[socket.remoteAddress]');
                        String? keyToRemove = remoteSocket.keys.firstWhere(
                                (k) => remoteSocket[k] == decodedMessage['p2'],
                            // looking for an age that doesn't exist
                            orElse: () => 'null'
                        );
                        remoteSocket.remove(keyToRemove);
                    }
                    else {
                        await relayBackToNode(decodedMessage['p2'],
                            createMessageJson(
                                null, null, null, null, decodedMessage['p4'],
                                0));
                    }
                }
                catch (e) {
                    print(e);
                }
            }
            else {
                print(decodedMessage['p4']);
            }
        }
        else if (decodedMessage['length'] == 34) {
            Map<dynamic, dynamic> part = jsonDecode(
                decodedMessage['p4']);
            if (part['length'] == 3) {
                if (part['type'] == 'GP') {
                    print('i am inside GP');
                    connect(part['p3'], part['p4']);
                    String toSend = createMessageJson(
                        'D', part['p3'], part['p4'],
                        decodedMessage['p4'],
                        decodedMessage['p3'],
                        6);
                    send(toSend);
                }
            }
            else {
                if (_isConnected) {
                    send(decodedMessage['p4']);
                }
                else {
                    try {
                        await relayBackToNode(decodedMessage['p3'],
                            createMessageJson(
                                null, null, null, null,
                                'no relaying connection exits ',
                                0));
                    }
                    catch (e) {
                        print(e);
                    }
                }
            }
        }
        else if (decodedMessage['length'] == 5) {
            try {
                await relayBackToNode(decodedMessage['p3'], createMessageJson(
                    null, null, null, null,
                    'no relaying connection exits ',
                    0));
            }
            catch (e) {
                print(e);
            }
        }
        else if (decodedMessage['type'] == 'SetMap') {
            _keySocketMap[socket.remoteAddress] = decodedMessage['p3'];
            print('Set has Mapped');
        }
        else {
            print(decodedMessage['p4']);
        }
    }


    void _handleMessageNode(decodeNodeMessage) async {
        if (decodeNodeMessage['length'] == 6) {
            print(relayToNodeKey);
            if (relayToNodeKey != null) {
                send(createMessageJson('TP', null, relayToNodeKey, null,
                    'disconnect', 4));
            }
            relayToNodeKey = decodeNodeMessage['p4'];
            send(createMessageJson(
                'SetMap', null, null, relayToNodeKey, null, 0));
            print('relay connected to $relayToNodeKey');
        }
        else if (decodeNodeMessage['length'] == 4) {
            if (decodeNodeMessage['p4'] == 'disconnect') {
                relayToNodeKey = null;
                _nullRemoteKey = true;

                print('relayDisconnected');
            }
            else {
                print(decodeNodeMessage['p4']);
                _nullRemoteKey = false;
            }
        }
        else {
            print(decodeNodeMessage['p4']);
            _nullRemoteKey = false;
        }
    }

    // Stop the server
    Future<void> stopServer() async {
        try {
            await _serverSocket?.close();
            _isListening = false;
            relayToNodeKey = null;
            print('Server stopped.');
            _nodeHandler = null;
        }
        catch (e) {
            _isListening = false;
            print('Server Stop error=$e');
            _nodeHandler = null;
            _nullRemoteKey = false;
            relayToNodeKey = null;
        }
    }
}
