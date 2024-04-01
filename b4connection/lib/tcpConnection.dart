import 'dart:io';
import 'package:psjapp/stungetip.dart';


class TcpClient {

    final Map<int, Socket> _socket = {};
    bool _isConnected = false;
    ServerSocket? _serverSocket;
    final Map<String, Socket> _remoteSocket = {};
    bool _isListening = false;
    var relayToNodeKey;
    String? message;
    final stunGet = StunClient();
    var publicIpv4;
    int? k;
    String? _myKey;
    List<dynamic>? partGlobal;
    int j=0;

    // Connect to the server
    Future<void> connect(String ip, int port) async {
        try {
            _socket[j] = await Socket.connect(ip, port);
            _isConnected = true;
            print('Connected to remoteNode: ${_socket[j]!.remoteAddress
                .address}:${_socket[j]!.remotePort}');
        }
        on SocketException catch (e) {
            print('Failed to connect: $e');
            _isConnected = false;
        }
    }

    // Start as a server
    Future<ServerSocket?> startServer() async {
        try {
            _serverSocket =
            await ServerSocket.bind(InternetAddress.anyIPv6, 22300, v6Only: false);
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
                                relayToNodeKey = parts[3];
                                final Key = parts[4];
                                if (type == 'MP') {
                                    message = '$publicIpv4|${socket.port}|I am your proxy server i will let you connect to the world bro';
                                    _remoteSocket[Key] = socket;
                                    _myKey = Key;
                                    sendBackToClient(Key, message);
                                }
                                else if (type == 'TP') {
                                    sendBackToClient(relayToNodeKey, clientMessage);
                                    message = 'you can relay your message to the key:$relayToNodeKey';
                                    _myKey = Key;
                                    sendBackToClient(Key, message);
                                }
                                else {
                                    k = 3; //for terminal app purpose.
                                    print(relayToNodeKey);
                                    partGlobal = relayToNodeKey.split('-');
                                    if (partGlobal!.length == 2) {
                                        final toDo = partGlobal![2];
                                        if (toDo == 'GP') {
                                            _remoteSocket['server'] = socket;
                                        }
                                    }
                                    else {
                                        _myKey = Key;
                                        _remoteSocket[Key] = socket;
                                        message =
                                        'your are now directly connected to me as we both are publicly available';
                                        sendBackToClient(Key, message);
                                    }
                                }
                            }
                            else if (parts.length == 3) {
                                final key = parts[1];
                                final message = parts[2];
                                final type = parts[0];
                                if (type == 'TP') {
                                    sendBackToClient(key, message);
                                }
                                else if (type == 'MP') {
                                    List<dynamic> part = message.split('-');
                                    final ips = part[0];
                                    final ipPort = part[1];
                                    final toDo = part[2];
                                    if (toDo == 'GP') {
                                        String typeNew = 'D';
                                        connect(ips, ipPort);
                                        String toSend = '$typeNew|$ips|$ipPort|$message|$_myKey';
                                        send(toSend);
                                    }
                                    else {
                                        send(message);
                                    }
                                }
                                else {
                                    print(clientMessage);
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
                            socket.destroy();
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
        if (!_isConnected) {
            print('Client is not connected to a server.');
            return;
        }
        else {
            _socket[j]!.write(message);
        }
    }


    // Receive data from the server
    void receive(Function(String message) onDataReceived) {
        print('recive function ivoke');
        if (!_isConnected) {
            print('Client is not connected to a server.');
            return;
        }
        _socket[j]!.listen(
                (dynamic data) {
                final serverMessage = String.fromCharCodes(data).trim();

                List<String> parts = serverMessage.split('|');
                if (parts.length == 5) {
                    relayToNodeKey = parts[3];
                    print(serverMessage);
                    print(relayToNodeKey);
                }
                else {
                    print(serverMessage);
                }
            },
            onError: (error) {
                print('Error: $error');
                _isConnected = false;
            },
            onDone: () {
                print('Server left.');
                _isConnected = false;
                _socket[j]!.destroy();
            },
        );
    }

    // Close the connection
    Future<void> disconnect() async {
        await _socket[j]!.close();
        _isConnected = false;
        print('Disconnected from the server');
    }

    String? Key() => _myKey;

    bool isConnected() => _isConnected;

    bool isListening() => _isListening;

    // Stop the server
    Future<void> stopServer() async {
        await _serverSocket?.close();
        print('Server stopped.');
    }
}
