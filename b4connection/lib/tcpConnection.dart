import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'stungetip.dart';

class TcpClient {

  late Socket _socket;
  bool _isConnected = false;
  ServerSocket? _serverSocket;

  // Connect to the server
  Future<void> connect(String ip,int port) async {
    try {
      _socket = await Socket.connect(ip, port);
      _isConnected = true;
      print('Connected to remoteNode: ${_socket.remoteAddress.address}:${_socket.remotePort}');
    } on SocketException catch (e) {
      print('Failed to connect: $e');
      _isConnected = false;
    }
  }

  // Start as a server
  Future<ServerSocket>? startServer() async {

    try{_serverSocket = await ServerSocket.bind(InternetAddress.anyIPv6, 0, v6Only: false);}
    catch(e){
      print('not able to create server on ipv6 so now creating on ipv4...');
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    }
    print('Server: started  on port ${_serverSocket!.port}');

    return _serverSocket!;
  }

  // Send a message to the server
  void send(String message) {

    if (!_isConnected) {
      print('Client is not connected to a server.');
      return;
    }
    else{
      _socket.write(message);}

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
        print(data);
        String jsonString = utf8.decode(data);

// Decode the JSON string into a Map<String, dynamic>
            Map<String, dynamic> dataMap = jsonDecode(jsonString);

// Now you can access your data
            String proxyIp = dataMap['proxyIp'];
            String proxyPort = dataMap['proxyPort'].toString(); // Converting int to String for consistency
            String yourIp = dataMap['yourIp'];
            String yourPort = dataMap['yourPort'];
            String myResponse = dataMap['myResponse'];
        print('Proxy IP: $proxyIp');
        print('Proxy Port: $proxyPort');
        print('Your IP: $yourIp');
        print('Your Port: $yourPort');
        print('My Response: $myResponse');
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

  // Stop the server
  Future<void> stopServer() async {
    await _serverSocket?.close();
    print('Server stopped.');
  }
}
