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
    int Null=4;
    String? _extraKey;

    // Connect to the server
    Future<void> connect(ip, port) async {
        _nodeHandler = null;
        Null=1;
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
        Null=2;
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
                                    try{
                                    _message = '${stunGet.getPublicIPv4()}|${socket
                                        .port}|I am your proxy server i will let you connect to the world bro . Please press any key to continue.';
                                    _remoteSocket[Key] = socket;
                                    _connectionKey = Key;
                                    sendBackToClient(Key, _message);
                                    _nodeHandler = 0;}
                                        catch(e){
                                        sendBackToClient(Key,'error in proxy connection=$e');
                                        }
                                }
                                else if (type == 'DTN') {
                                    try{
                                    _connectionKey = Key;
                                    _remoteSocket[Key] = socket;
                                    _message =
                                    'your are now directly connected to me as we both are publicly available';
                                    sendBackToClient(Key, _message);
                                    _nodeHandler = 3;}
                                        catch(e){
                                        sendBackToClient(Key,'having error in connection=$e');
                                        }
                                }
                                else if (type == 'TP') {
                                  try{
                                     sendBackToClient(NodeKey, clientMessage);
                                    _remoteSocket[Key] = socket;
                                    _extraKey=NodeKey;
                                    _message =
                                    'you can relay your message to the key:$NodeKey';
                                    _connectionKey = Key;
                                    sendBackToClient(Key, _message);
                                    _nodeHandler = 1;}
                                      catch(e){
                                      sendBackToClient(Key,'having some error in your entered key=$e' );
                                      }
                                }
                                else {
                                    print(NodeKey);
                                    partGlobal = NodeKey.split('-');
                                    if (partGlobal!.length == 2) {
                                        final toDo = partGlobal![2];
                                        if (toDo == 'GP') {
                                            try{
                                            _remoteSocket['ipv6'] = socket;
                                            var msg = 'you can relay message to me through your proxy node';
                                            String toSend = 'TP|$Key|$msg';
                                            relayToNodeKey=Key;
                                            sendBackToClient('ipv6', toSend);
                                            _nodeHandler = 2;}
                                                catch(e){
                                                print(e);
                                                }
                                        }
                                    }
                                    else {
                                        try{
                                        _connectionKey = Key;
                                        _remoteSocket[Key] = socket;
                                        _message =
                                        'your are now directly connected to me as we both are publicly available';
                                        sendBackToClient(Key, _message);
                                        _nodeHandler = 3;}
                                            catch(e){
                                            print(e);
                                            }
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
                                    try{
                                    sendBackToClient(key, message);}
                                    catch(e){print(e);}
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
                                    final ipPort = part[1];
                                    final toDo = part[2];
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
                                        try{
                                        String toSend = 'no relaying connection exits ';
                                        sendBackToClient(requestingNodeKey, toSend);}
                                            catch(e){print(e);}
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
                            print('${socket.address} Node left.');
                            try{
                                sendBackToClient(_connectionKey,'relay-disconnect');
                            }
                            catch(e){print('error=$e');}
                            try{
                                sendBackToClient(_extraKey,'relay-disconnect');
                            }
                            catch(e){print('error=$e');}

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
        print('message sent=$message');
        if (!_isConnected) {
            print('Client is not connected to a server.');
            return;
        }
        else {
            _socket[_j]!.write(message);
        }
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
                List<String> part = serverMessage.split('-');

                if (parts.length == 5) {
                    if(relayToNodeKey!=null){
                        send('TP|$relayToNodeKey|relay-disconnect');
                    }
                    relayToNodeKey = parts[4];
                    print(serverMessage);
                    print(relayToNodeKey);
                }
                else if(part.length==2){

                 if(part[1]=='disconnect')
                     {   Null=0;
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

    dynamic nullMaker()=>Null;

    // Stop the server
    Future<void> stopServer() async {
        await _serverSocket?.close();
        _isListening = false;
        print('Server stopped.');
        _nodeHandler = null;
    }
}
