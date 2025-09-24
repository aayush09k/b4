import 'dart:async';
import 'dart:io';
import 'package:b4utils/bufferdata.dart';
import 'TcpConnection.dart';

/// A high-level communication manager for establishing peer-to-peer connections between nodes.
///
/// The [B4connection] class provides a complete networking abstraction that handles:
/// - Direct connections between publicly accessible nodes
/// - NAT traversal using proxy/relay servers for nodes behind firewalls
/// - Automatic connection management with cleanup timers
/// - Message buffering and routing
///
/// ## Connection Types
///
/// The class supports three connection types:
/// - **'TP' (To Proxy)**: Send messages to NATed nodes via a proxy server
/// - **'MP' (My Proxy)**: Register a NATed node with its proxy server
/// - **'D' (Direct)**: Direct peer-to-peer connections between public nodes
///
/// ## Usage Example
///
/// ```dart
/// // Direct connection
/// B4connection conn = B4connection();
/// conn.setMyNodeId('myNode');
/// Socket? socket = await conn.startConnection('192.168.1.100', 8080, 'D', 'remoteNode');
/// await conn.sendMessage('Hello!', 'D', 'remoteNode');
///
/// // NAT traversal setup
/// B4connection natedNode = B4connection();
/// natedNode.setMyNodeId('natedClient');
/// await natedNode.startConnection('proxy.com', 9090, 'MP', 'natedClient');
/// ```
///
/// ## Key Features
///
/// - **Automatic Cleanup**: Connections auto-close after 5 minutes of inactivity
/// - **Message Buffering**: All received messages flow into a shared buffer
/// - **Flexible Architecture**: Supports both client and server modes
/// - **NAT Traversal**: Sophisticated proxy-based system for firewall traversal
class B4connection {
// This class is used to
// 1. Establish a complete communication pathway between nodes,
//    either with direct connections or by utilising their reRouter nodes.
// 2. to setup a server.
// 3. setup a listener for sockets and corresponding nodeId.
// 3. Setup a listener to receive incoming messages, either directly or through a reRouter node.
// 5. Send message to other node as configured in the connection.
// 6. Receive message from other node as configured in the connection and add received messages in the common buffer of cm module.



    //Declaration of all required variables.
    /// Timer used to automatically close the connection after 5 minutes of inactivity.
    ///
    /// The timer is reset on every send/receive operation to prevent premature closure
    /// of active connections. When the timer expires, [close] is automatically called.
    Timer? _inactivityTimer; // Timer used to delete the b4connection instance if the connection is not used before the timer expiry.
    /// The connection type that determines how messages are routed.
    ///
    /// Supported values:
    /// - **'TP'**: Route messages to NATed nodes via proxy (relay=yes)
    /// - **'MP'**: Register this NATed node with proxy (relay registration)
    /// - **'D'**: Direct connection between public nodes (relay=no)
    /// - **null/other**: Treated as direct connection
    String? _type;
    //It stores the input from the user.It helps in connection and messaging.
    // type can be 'TP=when someone wants to relay to NATed node via proxy(relay=yes)',
    // 'MP=when you are NATed node and you need to connect to your proxy(relay registration)',
    // 'D and else anything= for public nodes . for direct connection to each other(relay=no)'.



    // Below two very important variable for each instance of b4connection.
    /// The identifier of the remote node to communicate with.
    ///
    /// This is set during [startConnection] or [sendMessage] calls and determines
    /// the target for outgoing messages. For proxy connections, this identifies
    /// which registered NATed node to reach.
    String? _remoteNodeID; // The remote node ID to whom one want to send the message or relay the message.
    /// The primary TCP socket for this connection instance.
    ///
    /// This socket is established during [startConnection] and used for all
    /// communication. Each B4connection instance manages exactly one primary socket.
    Socket? _nodeIdSocket; // it will be fixed and unique after creating the b4connection instance.
    /// The local node identifier for this connection instance.
    ///
    /// Must be set via [setMyNodeId] before establishing connections. This ID
    /// is included in all outgoing messages and used for node identification
    /// in proxy registration scenarios.
    String? _myNodeId; // For each of b4connection instance you need to set this.
    /// Optional callback function executed when the connection is closed.
    ///
    /// This callback is triggered when [close] is called, either manually
    /// or automatically via the inactivity timer. Useful for cleanup operations
    /// or notifying higher-level components about connection state changes.
    ///
    /// Example:
    /// ```dart
    /// connection.onClosed = () {
    ///   print('Connection to $_remoteNodeID closed');
    ///   // Perform cleanup...
    /// };
    /// ```
    Function? onClosed; // Callback to execute when the connection is closed.
    /// Internal mapping used to track socket-to-nodeID associations.
    ///
    /// This map helps manage multiple incoming connections and their corresponding
    /// node identifiers during server operations. Used internally by
    /// [receiveSocketAndCorrespondingNodeID].
    Map <Socket,dynamic> eliminate={};


    //Instance of class used.
    /// Low-level TCP connection manager.
    ///
    /// Handles the actual socket operations, message framing, and basic
    /// network communication. The B4connection class builds higher-level
    /// abstractions on top of this foundation.
    TcpConnection tcpClient =TcpConnection();
    /// Shared message buffer for incoming messages.
    ///
    /// All received messages are automatically pushed into this buffer,
    /// making them available to higher-level components. The buffer handles
    /// message queuing and can be accessed by other parts of the system.
    DataBuffer dataBuffer = DataBuffer();

    /// Sets the local node identifier for this connection instance.
    ///
    /// The node ID is required before establishing connections and is included
    /// in all outgoing messages for node identification purposes.
    ///
    /// [id] The unique identifier for this node
    ///
    /// Example:
    /// ```dart
    /// connection.setMyNodeId('node_123');
    /// ```
    void setMyNodeId(id) {
        _myNodeId = id;
    }
    /// Resets the inactivity timer to prevent automatic connection closure.
    ///
    /// This method is called automatically on every send/receive operation
    /// to ensure active connections remain open. The timer is set to 5 minutes
    /// and will call [close] when it expires.
    ///
    /// Manual calls to this method can extend the connection lifetime if needed.
    // When you receive or else you send you need to reset the timer for existence of the b4connection instance.
    void _resetTimer() {
        _inactivityTimer?.cancel();
        _inactivityTimer = Timer(const Duration(minutes: 5), () {
            // This code will execute after 5 minutes of inactivity
            close();
        });
    }

    /// Establishes a connection to a remote node.
    ///
    /// This method creates a TCP connection to the specified target and sets up
    /// message buffering. The connection type determines how messages will be
    /// routed through the established connection.
    ///
    /// **Parameters:**
    /// - [targetIp] The IP address of the target node
    /// - [targetPort] The port number of the target node
    /// - [typeOfConnection] Connection routing type ('TP', 'MP', or 'D')
    /// - [remoteNodeId] Identifier of the remote node
    ///
    /// **Returns:** The established [Socket] or null if connection failed
    ///
    /// **Connection Types:**
    /// - **'TP'**: Connect to proxy server to send messages to NATed nodes
    /// - **'MP'**: Connect to proxy server to register this NATed node
    /// - **'D'**: Direct connection to a public node
    ///
    /// **Example:**
    /// ```dart
    /// // Direct connection
    /// Socket? socket = await conn.startConnection('192.168.1.100', 8080, 'D', 'peer1');
    ///
    /// // Register with proxy (for NATed nodes)
    /// Socket? proxy = await conn.startConnection('proxy.com', 9090, 'MP', 'myNodeId');
    ///
    /// // Connect to proxy to reach NATed nodes
    /// Socket? relay = await conn.startConnection('proxy.com', 9090, 'TP', 'natedNode');
    /// ```
    //Below function can be use to connect with other peer.Here you have to give the type of connection 'TP(To proxy)','MP(be my proxy)','D'(direct connection).
    Future<Socket?> startConnection(targetIp, targetPort, typeOfConnection,
        remoteNodeId) async {
        _remoteNodeID = remoteNodeId;
        _type = typeOfConnection;

        _nodeIdSocket = await tcpClient.connect(targetIp, targetPort);

        await _bufferReceivingData();

        return _nodeIdSocket;
    }

    //It is used to close the socket and triggers the callback function.
    /// Closes the connection and performs cleanup operations.
    ///
    /// This method:
    /// 1. Closes the primary TCP socket via [TcpConnection.closeConnection]
    /// 2. Executes the [onClosed] callback if one is registered
    /// 3. Cancels the inactivity timer to prevent memory leaks
    ///
    /// The method can be called manually or is automatically triggered
    /// by the inactivity timer after 5 minutes without activity.
    ///
    /// Example:
    /// ```dart
    /// connection.onClosed = () => print('Connection closed');
    /// connection.close(); // Triggers callback and cleanup
    /// ```
    void close() {

        if (_nodeIdSocket != null) {
            tcpClient.closeConnection(_nodeIdSocket!);
            if (onClosed != null) {
                onClosed!(); // Trigger the callback when closing.
            }
        }

        _inactivityTimer?.cancel();
    }



    // Listen data on socket.Received data put in common buffer of the CM module.
    /// Sets up continuous listening for incoming data on the primary socket.
    ///
    /// This private method establishes a data listener that:
    /// 1. Receives incoming messages from the connected socket
    /// 2. Automatically pushes received messages to the shared [dataBuffer]
    /// 3. Resets the inactivity timer on each received message
    /// 4. Handles connection closure by calling [close]
    ///
    /// The method is automatically called by [startConnection] and should not
    /// be called manually. All received messages become available through
    /// the shared buffer system.
    Future _bufferReceivingData() async {
        if (_nodeIdSocket != null) {
            await tcpClient.invokeListening((dynamic text, active) {
                if (!active) {
                  close();
                } else{

                dataBuffer.pushIntemp(text['message']);
                _resetTimer();
                }
            }, _nodeIdSocket!);
        }
    }
    /// Manually assigns a socket to this connection instance.
    ///
    /// This method is typically used when accepting incoming connections
    /// in server scenarios, where the socket is created externally and
    /// needs to be associated with a B4connection instance.
    ///
    /// [socket] The pre-established socket to associate with this connection
    ///
    /// Example:
    /// ```dart
    /// // In server code after accepting a connection
    /// B4connection clientConn = B4connection();
    /// clientConn.setNodeSocket(acceptedSocket);
    /// clientConn.setMyNodeId('server');
    /// ```

    void setNodeSocket(Socket socket) {
        _nodeIdSocket = socket;
    }

    // It listen for the receiving socket and Corresponding NodeId and help CM to create new instance correspond to the received nodeId.
    /// Sets up a listener for incoming socket connections and their associated node IDs.
    ///
    /// This method is used in server scenarios to handle multiple incoming connections.
    /// It establishes a listener that:
    /// 1. Accepts incoming socket connections
    /// 2. Extracts node IDs from incoming messages
    /// 3. Manages socket-to-nodeID mappings in the [eliminate] map
    /// 4. Calls the provided callback with connection information
    /// 5. Automatically buffers received messages
    ///
    /// **Parameters:**
    /// - [onDataReceived] Callback function that receives:
    ///   - `message`: The node ID or message content
    ///   - `socket`: The associated socket
    ///   - `active`: Boolean indicating if connection is still active
    ///
    /// **Message Handling:**
    /// - Regular messages (type=null): Added to buffer normally
    /// - 'TP' type messages: Special proxy routing (not buffered)
    /// - Other typed messages: Added to buffer
    ///
    /// **Example:**
    /// ```dart
    /// await connection.receiveSocketAndCorrespondingNodeID((nodeId, socket, active) {
    ///   if (active) {
    ///     print('Node $nodeId connected via $socket');
    ///     // Create new B4connection for this client...
    ///   } else {
    ///     print('Node $nodeId disconnected');
    ///     // Cleanup for this client...
    ///   }
    /// });
    /// ```
    Future receiveSocketAndCorrespondingNodeID(
        Function(dynamic message, Socket socket,bool active) onDataReceived) async {
        Socket? store;
        await tcpClient.receiveSocketsFromCNode((socket) async {

            await tcpClient.invokeListening((message, active) {

                if(active){
                    eliminate[socket]=message['myNodeID'];
                    store =socket;
                    if((message['type']==null)){
                        dataBuffer.pushIntemp(message['message']);}
                    else{
                        if(message['type']=='TP'){}
                        else{
                            dataBuffer.pushToPeerBuffer1(message['message']);
                        }
                    }

                onDataReceived(message['myNodeID'], socket,active);}
                else{

                    onDataReceived(eliminate[store], socket,active);
                }

            }, socket);
        });
    }


    //sendMessage is used to sent message to any node either relayed msg or normal message.
    //For different scenarios message function is developed in such a way that you can send your message to any node.

    /// Sends a message to a remote node using the specified routing method.
    ///
    /// This method handles different message routing scenarios based on the
    /// connection type. It automatically resets the inactivity timer and
    /// formats messages appropriately for the target routing method.
    ///
    /// **Parameters:**
    /// - [message] The content to send to the remote node
    /// - [typeOfConnection] How to route the message ('TP', 'MP', or 'D')
    /// - [remoteNodeID] The identifier of the target node
    ///
    /// **Routing Types:**
    /// - **'TP' (To Proxy)**: Routes message through proxy to a NATed node
    ///   - Requires [remoteNodeID] to specify the target NATed node
    ///   - Message is wrapped with routing information for proxy
    /// - **'MP' (My Proxy)**: Sends proxy registration message
    ///   - Used by NATed nodes to register with their proxy server
    ///   - Establishes the node in proxy's routing table
    /// - **'D' (Direct)**: Sends message directly to connected peer
    ///   - Standard peer-to-peer message without proxy involvement
    ///
    /// **Example Usage:**
    /// ```dart
    /// // Send direct message
    /// await conn.sendMessage('Hello World', 'D', 'peerNode');
    ///
    /// // Send via proxy to NATed node
    /// await conn.sendMessage('Hello NATed Node', 'TP', 'natedNode123');
    ///
    /// // Register with proxy (from NATed node)
    /// await conn.sendMessage('register_me', 'MP', 'myNodeId');
    /// ```
    ///
    /// **Error Handling:**
    /// - Prints error if no socket is available
    /// - Prints error if trying to use 'TP' without a valid [remoteNodeID]

    Future<void> sendMessage(message, typeOfConnection, remoteNodeID) async {
        _type = typeOfConnection;
        _remoteNodeID = remoteNodeID;

        if (_nodeIdSocket != null) {
            _resetTimer();
            if (_type == 'TP') {
                if (_remoteNodeID != null) {
                    String toSend = tcpClient.createMessageJson(
                        _type, _remoteNodeID, _myNodeId, message);
                    await tcpClient.send(toSend, _nodeIdSocket!);
                }
                else {
                    print('no relay connection exits');
                }
            }
            else if (_type == 'D') {
                String toSend = tcpClient.createMessageJson(
                    _type,_remoteNodeID, _myNodeId, message);
                await tcpClient.send(toSend, _nodeIdSocket!);
            }
            else if (_type == 'MP') {
                String toSend = tcpClient.createMessageJson(
                    _type,_remoteNodeID ,_myNodeId,message
                    );

                await tcpClient.send(toSend, _nodeIdSocket!);
            }
        }
        else {
            print('_nodeSocket is null');

        }
    }

  //Use to start server .

    /// Starts the node as a server listening on the specified port.
    ///
    /// This method configures the node to accept incoming connections from
    /// other nodes. Once started, the server can handle multiple simultaneous
    /// connections and should be used in conjunction with
    /// [receiveSocketAndCorrespondingNodeID] to process incoming connections.
    ///
    /// [listeningPort] The port number to bind the server socket to
    ///
    /// **Example:**
    /// ```dart
    /// B4connection server = B4connection();
    /// server.setMyNodeId('serverNode');
    ///
    /// // Start listening for connections
    /// await server.startNodeLiseNing(8080);
    ///
    /// // Handle incoming connections
    /// await server.receiveSocketAndCorrespondingNodeID((nodeId, socket, active) {
    ///   // Process new connections...
    /// });
    /// ```

    Future<void> startNodeLiseNing(listeningPort) async {
         await tcpClient.startASsNode(listeningPort);
    }


}
