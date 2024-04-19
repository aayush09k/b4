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
    bool _nullRemoteKey=false;


    // Connect to the server
    Future<void> connect(ip, port) async {
        _nodeHandler = null;
        relayToNodeKey = null;
        _nullRemoteKey=false;

        try {
            _socket[_j] = await Socket.connect(ip, port);
            _isConnected = true;
            print('Connected to remoteNode: ${_socket[_j]!.remoteAddress
                .address}:${_socket[_j]!.remotePort}');
        }
        on SocketException catch (e) {
            print('Failed to connect: $e');
            _isConnected = false;
            _nullRemoteKey=false;
        }
    }

    // Start as a server
    Future<ServerSocket?> startServer() async {
        _nodeHandler = null;
        relayToNodeKey = null;
        _nullRemoteKey=false;

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
                try { // Buffer to store data chunks

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
                        onDone: () {
                            print('${socket.remoteAddress} Node left.');

                            try {
                                var result = relayNodeMessageHandling(createMessageJson(null, null, null, null,
                                    'disconnect', 4));
                                remoteSocket[_keySocketMap[socket
                                    .remoteAddress]]!.add(result[0]);
                                remoteSocket[_keySocketMap[socket
                                    .remoteAddress]]!.add(result[1]);

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
        try {
            return _serverSocket;
        }
        catch (e) {
            print(e);
            return null;
        }
    }

    //Data send back to the client according to the key.
    List<dynamic> relayNodeMessageHandling(message) {
        List<int> messageBytes = utf8.encode(
            message); // Encode the JSON message
        int length = messageBytes.length; // Calculate the message length
        var lengthBytes = [
            (length >> 24) & 0xFF,
            (length >> 16) & 0xFF,
            (length >> 8) & 0xFF,
            length & 0xFF
        ]; // Prepare the length header
        /*try{
            print(message);
        _remoteSocket[key]!.write(lengthBytes); // Send the length header
        _remoteSocket[key]!.write(messageBytes); // Send the message bytes
        _remoteSocket[key]!.flush();}// Ensure the data is sent immediately
        catch(e){print(e);
        }*/
        return [lengthBytes, messageBytes];
    }

    // Send a message to the server
    Future<void> send(message) async {
        print(message);
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




     Future<dynamic> _processData(Socket socket,data) async{
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
                List<int> messageBytes = _buffer[socket]!.sublist(4, 4 + length);

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
    void receive(Function(String message) onDataReceived) {

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
                    _nullRemoteKey=true;
                    _socket[_j]!.close();
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
            _nullRemoteKey=true;
        }
        catch (e) {
            _isConnected = false;
            _nodeHandler = null;
            print('Disconnected error=$e');
            relayToNodeKey = null;
            _nullRemoteKey=true;
        }
    }

    String? Key() => _connectionKey;

    bool isConnected() => _isConnected;

    bool isListening() => _isListening;

    int? nodeHandler() => _nodeHandler;

    bool makeRemoteKeyNull()=> _nullRemoteKey;

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

    void _handleMessagePublic(Socket socket, decodedMessage) async {
        if (decodedMessage['length'] == 6) {
            // Extract individual parts
            final type = decodedMessage['type'];
            final NodeKey = decodedMessage['remoteKey'];
            final Key = decodedMessage['myKey'];
            if (type == 'MP') {
                try {
                    _message = createMessageJson(
                        null, stunGet.getPublicIPv4(), socket.port, null,
                        'I am your proxy server i will let you connect to the world bro . Please press any key to continue.',
                        0);
                    remoteSocket[Key] = socket;
                    _connectionKey = Key;
                    var result = relayNodeMessageHandling(_message);
                    remoteSocket[Key]!.add(result[0]);
                    remoteSocket[Key]!.add(result[1]);
                    _nodeHandler = 0;
                }
                catch (e) {

                    var result = relayNodeMessageHandling(createMessageJson(
                        null, null, null, null,
                        'error in proxy connection=$e', 0));
                    remoteSocket[Key]!.add(result[0]);
                    remoteSocket[Key]!.add(result[1]);
                }
            }
            else if (type == 'DTN') {
                try {
                    _connectionKey = Key;
                    remoteSocket[Key] = socket;
                    _message = createMessageJson(
                        null, null, null, null,
                        'your are now directly connected to me as we both are publicly available',
                        0);
                    var result = relayNodeMessageHandling(_message);
                    remoteSocket[Key]!.add(result[0]);
                    remoteSocket[Key]!.add(result[1]);
                    _nodeHandler = 3;
                }
                catch (e) {
                    var result = relayNodeMessageHandling(createMessageJson(
                        null, null, null, null,
                        'having error in connection=$e',
                        0));
                    remoteSocket[Key]!.add(result[0]);
                    remoteSocket[Key]!.add(result[1]);
                }
            }
            else if (type == 'TP') {
                _keySocketMap[socket.remoteAddress] = NodeKey;
                try {
                    var result = relayNodeMessageHandling(
                        jsonEncode(decodedMessage));
                    remoteSocket[NodeKey]!.add(result[0]);
                    remoteSocket[NodeKey]!.add(result[1]);

                    remoteSocket[Key] = socket;
                    _message = createMessageJson(null, null, null, null,
                        'you can relay your message to the key:$NodeKey', 0);
                    _connectionKey = Key;

                    var chat = relayNodeMessageHandling(_message);
                    remoteSocket[Key]!.add(chat[0]);
                    remoteSocket[Key]!.add(chat[1]);
                    _nodeHandler = 1;
                }
                catch (e) {
                    var result = relayNodeMessageHandling(
                        createMessageJson(null, null, null, null,
                            'having some error in your entered key=$e', 0));
                    remoteSocket[Key]!.add(result[0]);
                    remoteSocket[Key]!.add(result[1]);
                }
            }
            else {
                try {
                    _connectionKey = Key;
                    remoteSocket[Key] = socket;
                    _message = createMessageJson(
                        null, null, null, null,
                        'your are now directly connected to me as we both are publicly available',
                        0);
                    var chat = relayNodeMessageHandling(_message);
                    remoteSocket[Key]!.add(chat[0]);
                    remoteSocket[Key]!.add(chat[1]);
                    _nodeHandler = 3;
                }
                catch (e) {
                    print(e);
                }
            }
        }
        else if (decodedMessage['length'] == 4) {
            final key = decodedMessage['relayToNodeKey'];
            final message = decodedMessage['message'];
          //  final type = decodedMessage['type'];
            if (decodedMessage['type'] == 'TP') {
                try {
                    if(decodedMessage['message']=='disconnect'){
                        var result = relayNodeMessageHandling(
                            createMessageJson(null, null, null, null, message, 4));
                        remoteSocket[key]!.add(result[0]);
                        remoteSocket[key]!.add(result[1]);
                    }
                    else{
                    var result = relayNodeMessageHandling(
                        createMessageJson(null, null, null, null, message, 0));
                    remoteSocket[key]!.add(result[0]);
                    remoteSocket[key]!.add(result[1]);
                    }
                }
                catch (e) {
                    var result = relayNodeMessageHandling(createMessageJson(
                        null, null, null, null,
                        'Other Node is no more connected. error=$e',
                        0));
                    socket.add(result[0]);
                    socket.add(result[1]);
                }
            }
            else if (decodedMessage['type'] == 'MP') {
                try {
                    if(decodedMessage['message']=='disconnect'){
                        var result = relayNodeMessageHandling(
                            createMessageJson(null, null, null, null, message, 4));
                        remoteSocket[key]!.add(result[0]);
                        remoteSocket[key]!.add(result[1]);
                    }
                    else{
                    var result = relayNodeMessageHandling(
                        createMessageJson(null, null, null, null, message, 0));
                    remoteSocket[key]!.add(result[0]);
                    remoteSocket[key]!.add(result[1]);
                    }
                }
                catch (e) {
                    print(e);
                }
            }
            else {
                print(decodedMessage['message']);
            }
        }
        else if (decodedMessage['length'] == 34) {
            final message = decodedMessage['message'];
            final requestingNodeKey = decodedMessage['myKey'];
            Map<dynamic, dynamic> part = jsonDecode(
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
                        var result = relayNodeMessageHandling(
                            createMessageJson(
                                null, null, null, null,
                                'no relaying connection exits ',
                                0));
                        remoteSocket[requestingNodeKey]!.add(result[0]);
                        remoteSocket[requestingNodeKey]!.add(result[1]);
                    }
                    catch (e) {
                        print(e);
                    }
                }
            }
        }
        else if (decodedMessage['length'] == 5) {
            final requestingNodeKey = decodedMessage['myKey'];
            try {
                var result = relayNodeMessageHandling(createMessageJson(
                    null, null, null, null,
                    'no relaying connection exits ',
                    0));
                remoteSocket[requestingNodeKey]!.add(result[0]);
                remoteSocket[requestingNodeKey]!.add(result[1]);
            }
            catch (e) {
                print(e);
            }
        }
        else if (decodedMessage['type'] == 'SetMap') {
            _keySocketMap[socket.remoteAddress] = decodedMessage['myKey'];
            print('Set has Mapped');
        }
        else {
            print(decodedMessage['message']);
        }
    }


    void _handleMessageNode(decodeNodeMessage) async {
        print(decodeNodeMessage);
        if (decodeNodeMessage['length'] == 6) {
            print(relayToNodeKey);
            if (relayToNodeKey != null) {
                send(createMessageJson('TP', null, relayToNodeKey, null,
                    'disconnect', 4));
            }
            relayToNodeKey = decodeNodeMessage['myKey'];
            send(createMessageJson(
                'SetMap', null, null, relayToNodeKey, null, 0));
            print(relayToNodeKey);
        }
        else if (decodeNodeMessage['length'] == 4) {
            if (decodeNodeMessage['message'] == 'disconnect') {
                relayToNodeKey = null;
                _nullRemoteKey=true;
                print('relayDisconnected');
            }
            else {
                print(decodeNodeMessage['message']);
                _nullRemoteKey=false;
            }
        }
        else {
            print(decodeNodeMessage['message']);
            _nullRemoteKey=false;
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
            _nullRemoteKey=false;
            relayToNodeKey = null;
        }
    }
}
