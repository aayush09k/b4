import 'dart:io';
import 'dart:async';
import 'package:web_socket_channel/io.dart';

class WebSocketNode {
    HttpServer? _server;
    IOWebSocketChannel? _clientChannel;
    int _port;

    WebSocketNode(this._port);

    // Start the WebSocket server
    Future<void> startServer() async {
        _server = await HttpServer.bind(InternetAddress.anyIPv6, _port);
        print('WebSocket Server is running on [::]:$_port');

        await for (var request in _server!) {
            if (WebSocketTransformer.isUpgradeRequest(request)) {
                WebSocketTransformer.upgrade(request).then((websocket) {
                    var serverChannel = IOWebSocketChannel(websocket);
                    serverChannel.stream.listen((message) {
                        print('Server received message: $message');
                        serverChannel.sink.add('Server echo: $message');
                    });
                });
            } else {
                request.response
                ..statusCode = HttpStatus.forbidden
                               ..write('This server only supports WebSocket connections.')
                               ..close();
            }
        }
    }

    // Adjusted connectClient method
    void connectClient(String ipv6Address, int port) {
        String url = 'ws://[$ipv6Address]:$port';
        _clientChannel = IOWebSocketChannel.connect(Uri.parse(url));
        _clientChannel!.stream.listen((message) {
            print('Client received message: $message');
        });
    }

    // Send a message to the WebSocket server
    void send(String message) {
        _clientChannel?.sink.add(message);
        print('Client sent message: $message');
    }

    // Stop the server
    Future<void> stopServer() async {
        await _server?.close();
        print('Server stopped.');
    }

    // Disconnect the client
    void disconnectClient() {
        _clientChannel?.sink.close();
        print('Client disconnected.');
    }
}
