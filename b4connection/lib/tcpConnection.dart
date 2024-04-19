import 'dart:convert';
import 'dart:io';
import 'package:psjapp/stungetip.dart';


class TcpClient {

    final stunGet = StunClient();
    final Map<int, Socket> _socket = {
    }; // Sockets as Map. so that we can differentiate connected clients.
    bool _isConnected = false;
    ServerSocket? _serverSocket;
    Map<dynamic, dynamic> _keySocketMap = {};

    final Map<String, Socket> _remoteSocket = {}; // To save all remote Sockets.
    bool _isListening = false;
    dynamic relayToNodeKey; //The receiving node sets a unique node key to facilitate the  brokering of messages from the proxy server.


    String? _message;
    String? _connectionKey;

    List<dynamic>? partGlobal;
    int _j = 0;
    int? _nodeHandler;
    int Null = 4;
    List<String> M = [];


    // Connect to the server
    Future<void> connect(ip, port) async {
        _nodeHandler = null;
        Null = 1;
        try {
            _socket[_j] = await Socket.connect(ip, port);
            _isConnected = true;
            print('Connected to remoteNode: ${_socket[_j]!.remoteAddress
                .address}:${_socket[_j]!.remotePort}');
        }
        on SocketException catch (e) {
            print('Failed to connect: $e');
            _isConnected = false;
        }
    }

    // Start as a server
    Future<ServerSocket?> startServer() async {
        _nodeHandler = null;
        Null = 2;
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
                            (List<int> data) {
                            // Convert the received data to a string and trim whitespace
                            final clientMessage = String.fromCharCodes(data)
                                .trim();
                            Map<String,
                                dynamic> parsedMessage = parseMessageJson(clientMessage);



                            // Check if the split operation produced the expected two parts

                            if (parsedMessage['length'] == 6) {
                                // Extract individual parts
                                final type = parsedMessage['type'];
                                final NodeKey = parsedMessage['remoteKey'];
                                final Key = parsedMessage['myKey'];
                                if (type == 'MP') {
                                    try {
                                        _message = createMessageJson(
                                            null, stunGet.getPublicIPv4(),
                                            socket
                                                .port, null,
                                            'I am your proxy server i will let you connect to the world bro . Please press any key to continue.',
                                            0);
                                        _remoteSocket[Key] = socket;
                                        _connectionKey = Key;
                                        sendBackToClient(Key, _message);
                                        _nodeHandler = 0;
                                    }
                                    catch (e) {
                                        sendBackToClient(Key, createMessageJson(
                                            null, null, null, null,
                                            'error in proxy connection=$e', 0));
                                    }
                                }
                                else if (type == 'DTN') {
                                    try {
                                        _connectionKey = Key;
                                        _remoteSocket[Key] = socket;
                                        _message = createMessageJson(
                                            null, null, null, null,
                                            'your are now directly connected to me as we both are publicly available',
                                            0);
                                        sendBackToClient(Key, _message);
                                        _nodeHandler = 3;
                                    }
                                    catch (e) {
                                        sendBackToClient(Key, createMessageJson(
                                            null, null, null, null,
                                            'having error in connection=$e',
                                            0));
                                    }
                                }
                                else if (type == 'TP') {
                                    _keySocketMap[socket.remoteAddress] =
                                        NodeKey;
                                    print(_keySocketMap[socket.remoteAddress]);

                                    try {
                                        sendBackToClient(
                                            NodeKey, clientMessage);
                                        _remoteSocket[Key] = socket;
                                        _message = createMessageJson(
                                            null, null, null, null,
                                            'you can relay your message to the key:$NodeKey',
                                            0);

                                        _connectionKey = Key;
                                        sendBackToClient(Key, _message);
                                        _nodeHandler = 1;
                                    }
                                    catch (e) {
                                        sendBackToClient(Key, createMessageJson(
                                            null, null, null, null,
                                            'having some error in your entered key=$e',
                                            0));
                                    }
                                }
                                else {
                                    print(NodeKey);
                                    partGlobal = NodeKey.split('-');
                                    if (partGlobal!.length == 3) {
                                        final toDo = partGlobal![2];
                                        if (toDo == 'GP') {
                                            try {
                                                _remoteSocket['ipv6'] = socket;
                                                var msg = 'you can relay message to me through your proxy node';

                                                String toSend = createMessageJson(
                                                    'TP', null, Key, null, msg,
                                                    4);
                                                relayToNodeKey = Key;
                                                sendBackToClient(
                                                    'ipv6', toSend);
                                                _nodeHandler = 2;
                                            }
                                            catch (e) {
                                                print(e);
                                            }
                                        }
                                    }
                                    else {
                                        try {
                                            _connectionKey = Key;
                                            _remoteSocket[Key] = socket;
                                            _message = createMessageJson(
                                                null, null, null, null,
                                                'your are now directly connected to me as we both are publicly available',
                                                0);
                                            sendBackToClient(Key, _message);
                                            _nodeHandler = 3;
                                        }
                                        catch (e) {
                                            print(e);
                                        }
                                    }
                                }
                            }
                            else if (parsedMessage['length'] == 4) {
                                final key = parsedMessage['relayToNodeKey'];
                                final message = parsedMessage['message'];
                                final type = parsedMessage['type'];
                                if (type == 'TP') {
                                    try {
                                        sendBackToClient(key, createMessageJson(
                                            null, null, null, null, message,
                                            0));
                                    }
                                    catch (e) {
                                        socket.write(createMessageJson(
                                            null, null, null, null,
                                            'Other Node is no more connected. error=$e',
                                            0));
                                    }
                                }
                                else if (type == 'MP') {
                                    try {
                                        sendBackToClient(key, createMessageJson(
                                            null, null, null, null, message,
                                            0));
                                    }
                                    catch (e) {
                                        print(e);
                                    }
                                }
                                else {
                                    print(clientMessage);
                                }
                            }
                            else if (parsedMessage['length'] == 5) {
                                final message = parsedMessage['message'];
                                final requestingNodeKey = parsedMessage['myKey'];
                                Map<dynamic, dynamic> part = parseMessageJson(
                                    message);
                                if (part['length'] == 3) {
                                    if (part['type'] == 'GP') {
                                        print('i am inside GP');
                                        connect(part['ipv6'], part['ipv6port']);
                                        String toSend = createMessageJson(
                                            'D', part['ipv6'], part['ipv6port'],
                                            message,
                                            requestingNodeKey,
                                            6);
                                        send(toSend);
                                    }
                                }
                                else {
                                    if (_isConnected) {
                                        send(message);
                                    }
                                    else {
                                        try {
                                            String toSend = createMessageJson(
                                                null, null, null, null,
                                                'no relaying connection exits ',
                                                0);
                                            sendBackToClient(
                                                requestingNodeKey, toSend);
                                        }
                                        catch (e) {
                                            print(e);
                                        }
                                    }
                                }
                            }
                            else if (parsedMessage['type'] == 'SetMap') {
                                _keySocketMap[socket.remoteAddress] = parsedMessage['myKey'];
                            }
                            else {
                                print(clientMessage);
                                print(parsedMessage['message']);
                            }
                        },
                        onError: (error) {
                            print('Server: Error: $error');
                        },
                        onDone: () {
                            print('${socket.remoteAddress} Node left.');

                            try {
                                sendBackToClient(
                                    _keySocketMap[socket.remoteAddress],
                                    createMessageJson(null, null, null, null,
                                        'relay-disconnect', 0));
                            }
                            catch (e) {
                                print('error=$e');
                            }

                            try {
                                socket.close();
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

        return _serverSocket;
    }

    //Data send back to the client according to the key.
    void sendBackToClient(key, message) {
        _remoteSocket[key]?.write(message);
    }

    // Send a message to the server
    void send(message) {
        print('message sent=$message');
        if (!_isConnected) {
            print('Client is not connected to a server.');
            return;
        }
        else {
            _socket[_j]!.write(message);
        }
        Map<dynamic, dynamic> split = parseMessageJson(message);
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
        _remoteSocket[key]!.close();
        _connectionKey = null;
    }

    // Receive data from the server
    void receive(Function(String message) onDataReceived) {
        print('recive function ivoke');
        if (!_isConnected) {
            print('Client is not connected to a server.');
            return;
        }
        _socket[_j]!.listen(
                (dynamic data) {
                final serverMessage = String.fromCharCodes(data).trim();

                Map<String, dynamic> parsedMessage = parseMessageJson(
                    serverMessage);

                if (parsedMessage['length'] == 6) {
                    if (relayToNodeKey != null) {
                        send(createMessageJson('TP', null, relayToNodeKey, null,
                            'fiGthQiTk', 4));
                    }
                    relayToNodeKey = parsedMessage['myKey'];
                    print(serverMessage);
                    print(relayToNodeKey);
                    send(createMessageJson('SetMap',null, null, relayToNodeKey, null, 0));
                }
                else if (parsedMessage['length'] == 4) {
                    if (parsedMessage['message'] == 'fiGthQiTk') {
                        Null = 0;
                        relayToNodeKey = null;
                        print('relaytonodekey=$relayToNodeKey');
                        print('relayDisconnected');
                    }
                    else {
                        print(serverMessage);
                        print(parsedMessage['message']);
                    }
                }
                else {
                    print(serverMessage);
                    print(parsedMessage['message']);
                }
            },
            onError: (error) {
                print('Error: $error');
                _isConnected = false;
            },
            onDone: () {
                print('remoteNode  left.');
                _isConnected = false;
                _socket[_j]!.close();
            },
        );
    }

    // Close the connection
    Future<void> disconnect() async {
        await _socket[_j]!.close();
        // _socket[_j]!.destroy();
        _isConnected = false;
        _nodeHandler = null;
        print('Disconnected from the proxy');
        relayToNodeKey = null;
    }

    String? Key() => _connectionKey;

    bool isConnected() => _isConnected;

    bool isListening() => _isListening;

    int? nodeHandler() => _nodeHandler;

    dynamic nullMaker() => Null;


    String createMessageJson(type, A, B, C, D, length) {
        switch (length) {
            case 6:
                Map<String, dynamic> message = {
                    'type': type,
                    'IP': A,
                    'Port': B,
                    'remoteKey': C,
                    'myKey': D,
                    'length': length
                };
                return json.encode(message);

            case 4:
                Map<String, dynamic> message = {
                    'type': type,
                    'IP': A,
                    'relayToNodeKey': B,
                    'myKey': C,
                    'message': D,
                    'length': length
                };
                return json.encode(message);

            case 5:
                Map<String, dynamic> message = {
                    'type': type,
                    'IP': A,
                    'relayToNodeKey': B,
                    'myKey': C,
                    'message': D,
                    'length': length
                };
                return json.encode(message);
            case 3:
                Map<String, dynamic> message = {
                    'type': type,
                    'None': A,
                    'nil': B,
                    'ipv6': C,
                    'ipv6port': D,
                    'length': length
                };
                return json.encode(message);
            default:
                Map<String, dynamic> message = {
                    'type': type,
                    'IP': A,
                    'relayToNodeKey': B,
                    'myKey': C,
                    'message': D,
                    'length': length
                };
                return json.encode(message);
        }
    }

    Map<String, dynamic> parseMessageJson(message) {
        return json.decode(message); // Convert the JSON string back to a Map
    }

    // Stop the server
    Future<void> stopServer() async {
        await _serverSocket?.close();
        _isListening = false;
        print('Server stopped.');
        _nodeHandler = null;
    }
}
