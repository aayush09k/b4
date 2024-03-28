import 'dart:io';

import 'package:psjapp/stungetip.dart';


class TcpClient {

    late Socket _socket;
    bool _isConnected = false;
    ServerSocket? _serverSocket;
    final Map<String,Socket> _remoteSocket={};
    bool _isListening = false;
    var relayToNodeKey;
    String? message;
    final stunGet=StunClient();
    var publicIpv4;
    int step=0;
    var myKey;
    List<dynamic>? partGlobal;

    // Connect to the server
    Future<void> connect(String ip,int port) async {
        try {
            _socket = await Socket.connect(ip, port);
            _isConnected = true;
            print('Connected to remoteNode: ${_socket.remoteAddress.address}:${_socket.remotePort}');
        }
        on SocketException catch (e) {
            print('Failed to connect: $e');
            _isConnected = false;
        }
    }

    // Start as a server
    Future<ServerSocket?> startServer() async {
        try {
            _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv6, 0, v6Only: false);
            _isListening=true;

        }
        catch(e) {
            print('not able to create server on ipv6 so now creating on ipv4...');
            _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
            _isListening=true;
        }
        print('Server: started  on port ${_serverSocket!.port}');
        try {
            _serverSocket!.listen((socket)  {

                print('RemoteNode is Connected to us from ${socket.remoteAddress.address}:${socket.remotePort}');
                try {
                    socket.listen(
                            (List<int> data)  {
                            // Convert the received data to a string and trim whitespace
                            final clientMessage = String.fromCharCodes(data).trim();

                            List<String> parts = clientMessage.split('|');
                            // Check if the split operation produced the expected two parts

                            if (parts.length == 5) {
                                // Extract individual parts
                                final type = parts[0];
                                final ip = parts[1];
                                final port = parts[2];
                                relayToNodeKey = parts[3];
                                myKey=parts[4];
                                if(type=='MP'){
                                    message='$publicIpv4|${socket.port}|I am your proxy server i will let you connect to the world bro';
                                    _remoteSocket[myKey]=socket;
                                    sendBackToClient(myKey,message);}
                                else if(type=='TP'){
                                    sendBackToClient(relayToNodeKey,clientMessage);
                                    message='you can relay your message to the key:$relayToNodeKey';
                                    sendBackToClient(myKey, message);

                                }
                                else{
                                    step=3; //for terminal app purpose.
                                    print(relayToNodeKey);
                                    partGlobal = relayToNodeKey.split('-');
                                    if(partGlobal!.length==2){

                                    final toDo=partGlobal![2];
                                    if(toDo=='GP'){
                                        _remoteSocket['server']=socket;

                                    }
                                   }
                                    else{
                                        print(myKey);
                                        _remoteSocket[myKey]=socket;
                                    message='your are now directly connected to me as we both are publicly available';
                                    sendBackToClient(myKey, message);
                                    }
                                }

                            }
                            else if(parts.length==3){
                                    final key=parts[1];
                                    final message=parts[2];
                                    final type=parts[0];
                                if(type=='TP') {
                                    sendBackToClient(key, message);
                                }
                                else if(type=='MP'){
                                       List<dynamic> part = message.split('-');
                                       final ips=part[0];
                                       final ipPort=part[1];
                                       final toDo=part[2];
                                    if(toDo=='GP'){
                                        String typeNew='D';
                                        connect(ips, ipPort);
                                        String toSend='$typeNew|$ips|$ipPort|$message|$myKey';
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
                            else{
                                print('lulu');
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
                catch(e) {
                    print(e);
                }



            });
        }
        catch(e) {
            print(e);
        }

     return _serverSocket;
    }

    void sendBackToClient(key,message){

        _remoteSocket[key]?.write(message);

    }
    // Send a message to the server
    void send(String message) {

        if (!_isConnected) {
            print('Client is not connected to a server.');
            return;
        }
        else {
            _socket.write(message);
        }

    }



    // Receive data from the server
    void receive(Function(String message) onDataReceived) {
        print('recive function ivoke');
        if (!_isConnected) {
            print('Client is not connected to a server.');
            return;
        }
        _socket.listen(
                ( dynamic data) {
                    print('recevive hua ');
                final serverMessage = String.fromCharCodes(data).trim();

                List<String> parts = serverMessage.split('|');
                if(parts.length==5) {
                    relayToNodeKey = parts[3];
                    print(serverMessage);
                    print(relayToNodeKey);
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
                print('Server left.');
                _isConnected = false;
                _socket.destroy();
            },
        );
    }

    // Close the connection
    Future<void> disconnect() async {
        await _socket.close();
        _isConnected = false;
        print('Disconnected from the server');
    }


    bool isConnected()=>_isConnected;


    bool isListening()=>_isListening;

    // Stop the server
    Future<void> stopServer() async {
        await _serverSocket?.close();
        print('Server stopped.');
    }
}
