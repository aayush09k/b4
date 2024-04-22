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
            _socket[_j] =  await Socket.connect(ip, port) ;
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
    Future<void> startServer() async {
        _nodeHandler = null;
        relayToNodeKey = null;
        _nullRemoteKey = false;
        _keySocketMap.clear();

        try {
            _serverSocket =
            await ServerSocket.bind(
                InternetAddress.anyIPv6, 22356, v6Only: false);
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
                        onError: (error) async {
                            print('Server: Error: $error');
                            print(_keySocketMap[socket.remoteAddress]);
                            if (_keySocketMap[socket.remoteAddress] !=
                                null) {
                                print(
                                    'koi client node left kiya he toh usk corresponding to realytonode key wale node ko disconnect bhejne agye me ');
                                await relayBackToNode(_keySocketMap[socket
                                    .remoteAddress],
                                createMessageJson(
                                    null, null, null, null,
                                    'disconnect', 4));
                                _keySocketMap.remove(socket.remoteAddress);
                            }else{
                            _keySocketMap.remove(socket.remoteAddress);}

                        },
                        onDone: () async {
                            try {
                                print(_keySocketMap[socket.remoteAddress]);
                                if (_keySocketMap[socket.remoteAddress] !=
                                    null) {
                                    print(
                                        'koi client node left kiya he toh usk corresponding to realytonode key wale node ko disconnect bhejne agye me ');
                                    await relayBackToNode(_keySocketMap[socket
                                        .remoteAddress],
                                        createMessageJson(
                                            null, null, null, null,
                                            'disconnect', 4));
                                    _keySocketMap.remove(socket.remoteAddress);
                                }
                                _keySocketMap.remove(socket.remoteAddress);

                            }
                            catch (e) {
                                print('disconnect send nhi ho paya');
                                print('error=$e');
                            }

                          /*  try {
                                try {
                                    socket.close();
                                }
                                catch (e) {
                                    print(e);
                                }

                            catch (e) {
                                print('error=$e');
                            }*/
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

        }
        catch (e) {
            print(e);
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
            remoteSocket[key]!.add(lengthBytes); // Send the length header
            remoteSocket[key]!.add(messageBytes); // Send the message bytes
            remoteSocket[key]!.flush();
        } // Ensure the data is sent immediately
        catch (e) {
            print(e);
        }
    }

    // Send a message to the server
    Future<void> send(message) async {
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
    void disconnect()  {
        try {
            _socket[_j]!.close();
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
        print(
            'public message handler kerne agye me or mera msg = $decodedMessage');
        if (decodedMessage['l'] == 6) {
            if (decodedMessage['t'] == 'MP') {
                _keySocketMap.remove(socket.remoteAddress);

                print('me t=MP,l=6 ke if me agya');
                try {
                    print(decodedMessage);
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
                    print('me t=MP,l=6 ke if ke catch me agya');
                    await relayBackToNode(
                        decodedMessage['p4'], createMessageJson(
                        null, null, null, null,
                        'error in proxy connection=$e', 0));
                }
            }
            else if (decodedMessage['t'] == 'DTN') {
                try {
                    print('me t=DTN,l=6 ke try me agya');
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
                    print('me t=DTN,l=6 ke catch me agya');
                    await relayToNodeKey(
                        decodedMessage['p4'], createMessageJson(
                        null, null, null, null,
                        'having error in connection=$e',
                        0));
                }
            }
            else if (decodedMessage['t'] == 'TP') {
                _keySocketMap[socket.remoteAddress] = decodedMessage['p3'];
                print('key socket mapping =$_keySocketMap');

                try {
                    print('me t=TP,l=6 ke try me agya');
                    await relayBackToNode(decodedMessage['p3'],
                        jsonEncode(decodedMessage));


                    remoteSocket[decodedMessage['p4']] = socket;
                    _message = createMessageJson(null, null, null, null,
                        "you can relay your message to the key:${decodedMessage['p3']})",
                        0);
                    _connectionKey = decodedMessage['p4'];

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
                    remoteSocket[decodedMessage['p4']] = socket;
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
        else if (decodedMessage['l'] == 4) {
            if (decodedMessage['t'] == 'TP') {
                print('me t=TP,l=4 ke if me agya');
                print(_keySocketMap);
                try {
                    if (decodedMessage['p4'] == 'disconnect') {
                        print(
                            'me t=TP,l=4  ke try ke if  me agya.disconnect krne k liye');
                        await relayBackToNode(decodedMessage['p2'],
                            createMessageJson(
                                null, null, null, null, decodedMessage['p4'],
                                4));

                        //Mapping remove logic when relay is disconnected.
                        _keySocketMap.remove(socket.remoteAddress);

                        String? keyToRemove = _keySocketMap.keys.firstWhere(
                                (k) => _keySocketMap[k] == decodedMessage['p2'],
                            // looking for an age that doesn't exist
                            orElse: () => 'null');
                        _keySocketMap.remove(keyToRemove);
                    }
                    else {
                        print('me t=TP,l=4  ke try ke else  me agya.');
                        if (remoteSocket[decodedMessage['p2']] != null) {
                            await relayBackToNode(decodedMessage['p2'],
                                createMessageJson(
                                    null, null, null, null,
                                    decodedMessage['p4'],
                                    0));
                        }
                        else {
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
                        //Mapping remove logic when relay is disconnected.
                        _keySocketMap.remove(socket.remoteAddress);

                        String? keyToRemove = _keySocketMap.keys.firstWhere(
                                (k) => _keySocketMap[k] == decodedMessage['p2'],
                            // looking for an age that doesn't exist
                            orElse: () => 'null');
                        _keySocketMap.remove(keyToRemove);
                    }
                    else {
                        print('me t=MP,l=4 ke try ke else  me agya');
                        await relayBackToNode(decodedMessage['p2'],
                            createMessageJson(
                                null, null, null, null, decodedMessage['p4'],
                                0));
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
        else if (decodedMessage['l'] == 34) {
            print('l=34 me agya');
            Map<dynamic, dynamic> part = jsonDecode(
                decodedMessage['p4']);
            if (part['l'] == 3) {
                print(
                    'l=34 me akr phr message ko khola or part kiya usme l=3 ke if me  agya');
                if (part['t'] == 'GP') {
                    print('l=3 t=GP me agya');
                    connect(part['p3'], part['p4']);
                    String toSend = createMessageJson(
                        'D', part['p3'], part['p4'],
                        decodedMessage['p4'],
                        decodedMessage['p3'],
                        6);
                    await send(toSend);
                }
            }
            else {
                print(
                    'l=34 me akr phr message ko khola or part kiya usme l=3 ke else me  agya');
                if (_isConnected) {
                    send(decodedMessage['p4']);
                }
                else {
                    try {
                        print(
                            'l=34 me akr phr message ko khola or part kiya usme l=3 ke else ke else ke try me client ko "no relayin connection bhejne " me agya  ');
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
        else if (decodedMessage['l'] == 5) {
            try {
                print('l=5 me try me "no reyling connection bhejne agya me "');
                await relayBackToNode(decodedMessage['p3'], createMessageJson(
                    null, null, null, null,
                    'no relaying connection exits ',
                    0));
            }
            catch (e) {
                print('l=5 me catch me agya');
                print(e);
            }
        }
        else if (decodedMessage['t'] == 'SetMap') {
            print('default l ke t=setMap me agya ');
            _keySocketMap[socket.remoteAddress] = decodedMessage['p3'];
            print('Set has Mapped');
        }
        else {
            print(decodedMessage['p4']);
        }
    }


    void _handleMessageNode(decodeNodeMessage) async {
        print('me node mesgg handle krne agya mera msg=$decodeNodeMessage');
        if (decodeNodeMessage['l'] == 6) {
            print(relayToNodeKey);
            if (relayToNodeKey != null) {
                await send(createMessageJson('TP', null, relayToNodeKey, null,
                    'disconnect', 4));
            }
            relayToNodeKey = decodeNodeMessage['p4'];
            await send(createMessageJson(
                'SetMap', null, null, relayToNodeKey, null, 0));
            print('relay connected to $relayToNodeKey');
        }
        else if (decodeNodeMessage['l'] == 4) {
            if (decodeNodeMessage['p4'] == 'disconnect') {

                if(stunGet.getPublicPortIPv6()!=null){
                    disconnect();
                    relayToNodeKey = null;
                    _nullRemoteKey = true;
                    print('Disconnected proxy and Relay');
                }
                else if(stunGet.getPublicIPv4()!=null){
                    disconnect();
                    relayToNodeKey = null;
                    _nullRemoteKey = true;
                    print('Disconnected proxy and Relay');
                }
                else{
                    relayToNodeKey = null;
                    _nullRemoteKey = true;
                    print('relayDisconnected');
                }

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
