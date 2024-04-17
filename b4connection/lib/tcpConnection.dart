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
    dynamic parsedMessage;
    dynamic messageDecode;
    dynamic decodeNodeMessage;
    List<int> buffer = [];



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
                try {// Buffer to store data chunks

                    socket.listen(
                            (data) async {

                               parsedMessage=await _processData(data);
                            // Convert the received data to a string and trim whitespace
                      //     final clientMessage = String.fromCharCodes(data).trim();
                                //    Map<String, dynamic> parsedMessage = parseMessageJson(clientMessage);
                               if(parsedMessage!=null){
                                   print(parsedMessage);
                                   print('yha conditionme agya me');
                                _handleMessagePublic(socket, parsedMessage);}
                               else{
                                   print('$parsedMessage');
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
                                        '1/s;e45rfv.;hn,lgrFp0', 4));
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
        List<int> messageBytes = utf8.encode(
            message); // Encode the JSON message
        int length = messageBytes.length; // Calculate the message length
        var lengthBytes = [
            (length >> 24) & 0xFF,
            (length >> 16) & 0xFF,
            (length >> 8) & 0xFF,
            length & 0xFF
        ]; // Prepare the length header
        try{
        _remoteSocket[key]!.add(lengthBytes); // Send the length header
        _remoteSocket[key]!.add(messageBytes); // Send the message bytes
        _remoteSocket[key]!.flush();}// Ensure the data is sent immediately
        catch(e){print(e);
        }
    }

    // Send a message to the server
    void send(message) {
        print('message sent=$message');

        List<int> messageBytes = utf8.encode(message);  // Encode the JSON message
        int length = messageBytes.length;  // Calculate the message length
        var lengthBytes = [
            (length >> 24) & 0xFF,
            (length >> 16) & 0xFF,
            (length >> 8) & 0xFF,
            length & 0xFF
        ];  // Prepare the length header

        if (!_isConnected) {
            print('Client is not connected to a server.');
            return;
        }
        else {
            try{
            _socket[_j]!.add(lengthBytes);  // Send the length header
            _socket[_j]!.add(messageBytes); // Send the message bytes
            _socket[_j]!.flush(); } // Ensure the data is sent immediately
            catch(e){
                print(e);
            }
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
        try{
        _remoteSocket[key]!.close();
        _connectionKey = null;}
            catch(e){
            print(e);
            }
    }

    Future<dynamic> _processData(data) async{
        buffer.addAll(data);
       print('process data me agya');
        while (buffer.length >= 4) {
            // Ensure there's enough buffer to read the length
            // Reading length from the buffer
            int length = (buffer[0] << 24) +
                (buffer[1] << 16) +
                (buffer[2] << 8) +
                buffer[3];

            if (buffer.length >= 4 + length) {
                // Check if the whole message has arrived
                // Extract the message bytes after the length header
                List<int> messageBytes = buffer.sublist(4, 4 + length);

                // Decode the message from bytes to a UTF-8 string
                messageDecode = utf8.decode(messageBytes);
                print("Received message: $messageDecode");


                // Remove the processed message from the buffer
                buffer.removeRange(0, 4 + length);
                return parseMessageJson(messageDecode);
            } else {
                print('not enogh data');
                break; // Not enough data for a full message, wait for more data
            }

        }

    }
    // Receive data from the server
    void receive(Function(String message) onDataReceived) {
        print('receive function invoke');
        if (!_isConnected) {
            print('Client is not connected to a server.');
            return;
        }
        _socket[_j]!.listen(
                (data) async {
               print(data);
                //final serverMessage = String.fromCharCodes(data).trim();
                decodeNodeMessage= await _processData(data);
                print(decodeNodeMessage);
               // Map<String, dynamic> parsedMessage = parseMessageJson(serverMessage);
                if(decodeNodeMessage!=null){
                    print(decodeNodeMessage);
                    print('yha conditionme agya me');
                    _handleMessageNode(decodeNodeMessage);}
                else{
                    print('$decodeNodeMessage');
                }
            },
            onError: (error) {
                print('Error: $error');
                _isConnected = false;
            },
            onDone: () {
                    try{
                print('remoteNode  left.');
                _isConnected = false;
                _socket[_j]!.close();}
                        catch(e){
                            print('remoteNode  left.');
                            _isConnected = false;
                        }
            },
        );
    }

    // Close the connection
    Future<void> disconnect() async {
        try{
        await _socket[_j]!.close();
        _isConnected = false;
        _nodeHandler = null;
        print('Disconnected from the proxy');
        relayToNodeKey = null;}
            catch(e){
                _isConnected = false;
                _nodeHandler = null;
                print('Disconnected error=$e');
                relayToNodeKey = null;
            }
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

    void _handleMessagePublic(Socket socket,decodedMessage) async{
       print('hanlde msg me agya');
       print(decodedMessage['length']);
       print(decodedMessage['type']);
       print(decodedMessage['myKey']);
        if (decodedMessage['length'] == 6) {
            // Extract individual parts
            final type = decodedMessage['type'];
            final NodeKey = decodedMessage['remoteKey'];
            final Key = decodedMessage['myKey'];
            if (type == 'MP') {
                print('Mp me agya me ');
                try {
                    _message = createMessageJson(null, stunGet.getPublicIPv4(), socket.port, null, 'I am your proxy server i will let you connect to the world bro . Please press any key to continue.', 0);
                    _remoteSocket[Key] = socket;
                    _connectionKey = Key;
                    sendBackToClient(Key, _message);
                    _nodeHandler = 0;
                }
                catch (e) {
                    print('error me agya me =$e');
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
                        NodeKey, decodedMessage);
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
        else if (decodedMessage['length'] == 4) {
            final key = decodedMessage['relayToNodeKey'];
            final message = decodedMessage['message'];
            final type = decodedMessage['type'];
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
                print(decodedMessage['message']);
            }
        }
        else if (decodedMessage['length'] == 34) {
            final message = decodedMessage['message'];
            final requestingNodeKey = decodedMessage['myKey'];
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
        else if(decodedMessage['length'] == 5){

            final requestingNodeKey = decodedMessage['myKey'];
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
        else if (decodedMessage['type'] == 'SetMap') {
            _keySocketMap[socket.remoteAddress] =
            decodedMessage['myKey'];
        }
        else {

            print(decodedMessage['message']);
        }
    }
    Map<String, dynamic> parseMessageJson(message) {
        return json.decode(message); // Convert the JSON string back to a Map
    }

    void _handleMessageNode(decodeNodeMessage) async{

        if (decodeNodeMessage['length'] == 6) {
            if (relayToNodeKey != null) {
                send(createMessageJson('TP', null, relayToNodeKey, null,
                    '1/s;e45rfv.;hn,lgrFp0', 4));
            }
            relayToNodeKey = decodeNodeMessage['myKey'];
            print(decodeNodeMessage);
            print(relayToNodeKey);
            send(createMessageJson(
                'SetMap', null, null, relayToNodeKey, null, 0));
        }
        else if (decodeNodeMessage['length'] == 4) {
            if (decodeNodeMessage['message'] == '1/s;e45rfv.;hn,lgrFp0') {
                Null = 0;
                relayToNodeKey = null;
                print('relayDisconnected');
            }
            else {
                print(decodeNodeMessage['message']);
            }
        }
        else {
            print(decodeNodeMessage['message']);
        }
    }
    // Stop the server
    Future<void> stopServer() async {
        try{
        await _serverSocket?.close();
        _isListening = false;
        print('Server stopped.');
        _nodeHandler = null;}
            catch(e){
                _isListening = false;
                print('Server Stop error=$e');
                _nodeHandler = null;
            }
    }
}
