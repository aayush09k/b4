import 'dart:io';
import 'package:psjapp/stungetip.dart';


class TcpClient {

    final stunGet = StunClient();
    final Map<int, Socket> _socket = {
    }; // Sockets as Map. so that we can differentiate connected clients.
    bool _isConnected = false;
    ServerSocket? _serverSocket;

    final Map<String, Socket> _remoteSocket = {}; // To save all remote Sockets.
    bool _isListening = false;
    dynamic relayToNodeKey; //The receiving node sets a unique node key to facilitate the  brokering of messages from the proxy server.


    String? _message;
    dynamic _publicIpv4;
    String? _connectionKey;

    List<dynamic>? partGlobal;
    int _j = 0;
    int? _nodeHandler;
    int? _relayCount;

    // Connect to the server
    Future<void> connect(ip, port) async {
        _nodeHandler = null;
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

                            List<String> parts = clientMessage.split('|');
                            // Check if the split operation produced the expected two parts

                            if (parts.length == 5) {
                                // Extract individual parts
                                final type = parts[0];
                                final ip = parts[1];
                                final port = parts[2];
                                final NodeKey = parts[3];
                                final Key = parts[4];
                                if (type == 'MP') {
                                    _message = '${stunGet.getPublicIPv4()}|${socket
                                        .port}|I am your proxy server i will let you connect to the world bro . \n Please press any key to continue.';
                                    _remoteSocket[Key] = socket;
                                    _connectionKey = Key;
                                    sendBackToClient(Key, _message);
                                    _nodeHandler = 0;
                                }
                                else if (type == 'DTN') {
                                    _connectionKey = Key;
                                    _remoteSocket[Key] = socket;
                                    _message =
                                    'your are now directly connected to me as we both are publicly available';
                                    sendBackToClient(Key, _message);
                                    _nodeHandler = 3;
                                }
                                else if (type == 'TP') {

                                     sendBackToClient(NodeKey, clientMessage);
                                    _remoteSocket[Key] = socket;
                                    _message =
                                    'you can relay your message to the key:$NodeKey';
                                    _connectionKey = Key;
                                    sendBackToClient(Key, _message);
                                    _nodeHandler = 1;
                                }
                                else {
                                    print(NodeKey);
                                    partGlobal = NodeKey.split('-');
                                    if (partGlobal!.length == 2) {
                                        final toDo = partGlobal![2];
                                        if (toDo == 'GP') {
                                            _remoteSocket['ipv6'] = socket;
                                            var msg = 'you can relay message to me through your proxy node';
                                            String toSend = 'TP|$Key|$msg';
                                            relayToNodeKey=Key;
                                            sendBackToClient('ipv6', toSend);
                                            _nodeHandler = 2;
                                        }
                                    }
                                    else {
                                        _connectionKey = Key;
                                        _remoteSocket[Key] = socket;
                                        _message =
                                        'your are now directly connected to me as we both are publicly available';
                                        sendBackToClient(Key, _message);
                                        _nodeHandler = 3;
                                    }
                                }
                            }
                            else if (parts.length == 3) {
                                final key = parts[1];
                                final message = parts[2];
                                final type = parts[0];
                                if (type == 'TP') {
                                    try{
                                    sendBackToClient(key, message);}
                                        catch(e){
                                        socket.write('Other Node is no more connected. error=$e');
                                        }
                                }
                                else if (type == 'MP') {
                                    sendBackToClient(key, message);
                                }
                                else {
                                    print(clientMessage);
                                }
                            }
                            else if (parts.length == 4) {
                                final key = parts[1];
                                final message = parts[3];
                                final type = parts[0];
                                final requestingNodeKey = parts[2];
                                List<dynamic> part = message.split('-');
                                if (part.length == 3) {
                                    final ips = part[0];
                                    print(ips);
                                    final ipPort = part[1];
                                    print(ipPort);
                                    final toDo = part[2];
                                    print(toDo);
                                    if (toDo == 'GP') {
                                        print('i am inside GP');
                                        connect(ips, ipPort);
                                        String toSend = 'D|$ips|$ipPort|$message|$requestingNodeKey';
                                        send(toSend);
                                    }
                                }
                                else {
                                    if (_isConnected) {
                                        send(message);
                                    }
                                    else {
                                        String toSend = 'you are not connected to ipv6 node ';
                                        sendBackToClient(requestingNodeKey, toSend);
                                    }
                                }
                            }
                            else {
                                print(clientMessage);
                            }
                        },
                        onError: (error) {
                            print('Server: Error: $error');
                        },
                        onDone: () {
                            print('Server: Client left.');
                            try{
                            socket.close();}
                                catch(e){
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
    void send(String message) {
        List<dynamic> split = message.split('|');
        switch (split[0]) {
            case 'MP':
                _nodeHandler = 0;
            case 'TP':
                _nodeHandler = 1;
            case 'DTN':
                _nodeHandler = 3;
            case 'D' :
                _nodeHandler = 3;
        }
        if (!_isConnected) {
            print('Client is not connected to a server.');
            return;
        }
        else {
            _socket[_j]!.write(message);
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

                List<String> parts = serverMessage.split('|');
                if (parts.length == 5) {
                    relayToNodeKey = parts[4];
                    print(serverMessage);
                    print(relayToNodeKey);
                }
                else if(parts.length==2){

                 if(parts[1]=='disconnect')
                     {
                         relayToNodeKey=null;
                         print('relaytonodekey=$relayToNodeKey');
                         print('relayDisconnected');
                     }
                 else{
                     print(serverMessage);
                 }

                }
                else{
                    print(serverMessage);
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
        relayToNodeKey=null;
    }

    String? Key() => _connectionKey;

    bool isConnected() => _isConnected;

    bool isListening() => _isListening;

    int? nodeHandler() => _nodeHandler;

    // Stop the server
    Future<void> stopServer() async {
        await _serverSocket?.close();
        _isListening = false;
        print('Server stopped.');
        _nodeHandler = null;
    }
}
