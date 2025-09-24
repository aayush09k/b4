import 'dart:io';
import 'dart:async';
import 'package:web_socket_channel/io.dart';

/// A utility class for creating a simple WebSocket server and client in the same process.
///
/// The [WebSocketNode] class allows:
/// - Hosting a WebSocket server that listens on an IPv6 port.
/// - Connecting as a WebSocket client to any given IPv6 WebSocket server.
/// - Sending messages from the client to the server.
/// - Automatically echoing back messages from the server.
/// - Gracefully stopping the server and disconnecting the client.
///
/// ## Example
///
/// ```dart
/// final node = WebSocketNode(8080);
/// await node.startServer();
/// node.connectClient('::1', 8080);  // Connect to self using IPv6 loopback
/// node.send('Hello');
/// node.disconnectClient();
/// await node.stopServer();
/// ```
///
class WebSocketNode {
    /// The HTTP server that listens for WebSocket upgrade requests.
  ///
  /// Initialized when [startServer] is called. Used to accept and upgrade HTTP requests to WebSocket connections.

    HttpServer? _server;
    /// The WebSocket client channel used to send and receive data.
  ///
  /// Initialized when [connectClient] is called.
    IOWebSocketChannel? _clientChannel;
    /// The port number on which the WebSocket server runs, and to which the client connects.
    int _port;
/// Creates a new [WebSocketNode] bound to the given port.
  ///
  /// This port will be used for both hosting the server and connecting the client.
    WebSocketNode(this._port);

    // Start the WebSocket server
    /// Starts the WebSocket server on the provided [_port].
  ///
  /// The server accepts WebSocket upgrade requests and listens for messages from clients.
  /// Incoming messages are printed to the console and echoed back to the client.
  ///
  /// This method is asynchronous and returns a [Future] that completes when the server stops.
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
 /// Connects this node as a WebSocket client to the given IPv6 [ipv6Address] and [port].
  ///
  /// The client listens for incoming messages and prints them to the console.
  /// Make sure the server is already running on the target address and port before connecting.
    // Adjusted connectClient method
    void connectClient(String ipv6Address, int port) {
        String url = 'ws://[$ipv6Address]:$port';
        _clientChannel = IOWebSocketChannel.connect(Uri.parse(url));
        _clientChannel!.stream.listen((message) {
            print('Client received message: $message');
        });
    }
 /// Sends a message to the WebSocket server from the connected client.
  ///
  /// The [message] is sent through the client channel. This requires that [connectClient] has been called beforehand.

    // Send a message to the WebSocket server
    void send(String message) {
        _clientChannel?.sink.add(message);
        print('Client sent message: $message');
    }
 /// Stops the WebSocket server gracefully.
  ///
  /// Closes the underlying [HttpServer] and releases the port.
    // Stop the server
    Future<void> stopServer() async {
        await _server?.close();
        print('Server stopped.');
    }
/// Disconnects the client from the WebSocket server.
  ///
  /// Closes the client connection gracefully.
    // Disconnect the client
    void disconnectClient() {
        _clientChannel?.sink.close();
        print('Client disconnected.');
    }
}
