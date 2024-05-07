import 'dart:async';
import 'dart:io';
import 'package:web_socket_channel/status.dart';

import 'tcpConnection.dart';
import 'package:b4commgr/bufferdata.dart';

class B4connection {
// This class is used to 
// 1. setup connection to other nodes directly or via their relays. For each other nodeID,
//  a separate connection instance is to be created, as connection is bound to nodeID of other node.
// 2. setup a server, either directly or via current nodes relay (root in non-NATed DHT) for IPv4
// 3. setup a server, either directly or via current nodes relay (root in non-NATed DHT) for IPv4
// 4. socket received from the client type node will create a b4connection instance and set its private variable
// _nodeIdSocket=received socket, hence this can be further used for send and disconnect.
// 5. Sending message to other node as configured in the connection.
// 6. Receiving message from other node as configured in the connection.


    //Declaration of all required variables.

    Timer? _inactivityTimer;
    int? natStatus; // According to this when we start connection a different type of messages is sent initially to other node.


    String? _type;

    //It stores the input from the user.It helps in connection and messaging.
    // type can be 'TP=when someone wants to relay to NATed node via proxy(relay=yes)',
    // 'MP=when you are NATed node and you need to connect to your proxy(relay registration)',
    // 'D and else anything= for public nodes . for direct connection to each other(relay=no)'.

    String _myNodeId = 'macbook';
    ServerSocket? listening;
    Socket? _nodeIdSocket;

    Function? onClosed; // Callback to execute when the connection is closed.


    String? _remoteNodeID;
    bool skip = false;

    //Instance of class used.
    TcpClient tcpClient = TcpClient();
    DataBuffer dataBuffer = DataBuffer();


    void setMyNodeId(id) {
        _myNodeId = id;
    }

    void _resetTimer() {
        _inactivityTimer?.cancel();
        _inactivityTimer = Timer(const Duration(minutes: 4), () {
            // This code will execute after 5 minutes of inactivity
            close();
        });
    }


    //Below function can be use to connect with other peer.Here you have to give the type of connection 'TP(To proxy)','MP(be my proxy)','D'(direct connection),'DTP'(Direct through NAT).
    Future<Socket?> startConnection(targetIp, targetPort, typeOfConnection,
        remoteNodeId) async {
        _remoteNodeID = remoteNodeId;
        _type = typeOfConnection;

        _nodeIdSocket = await tcpClient.connect(targetIp, targetPort);

        await bufferReceivingData();

        return _nodeIdSocket;
    }

    void close() {
        if (onClosed != null) {
            onClosed!(); // Trigger the callback when closing.
        }
        if (_nodeIdSocket != null) {
            tcpClient.closeConnection(_nodeIdSocket!);
        }

        _inactivityTimer?.cancel();
    }


    // A callback function that will be used by the communication manager for receiving data.
    // receiveText FroM server Node.
    Future bufferReceivingData() async {
        if (_nodeIdSocket != null) {
            await tcpClient.invokeListening((dynamic text, active) {
                if (!active) {
                    if (onClosed != null) {
                        onClosed!();
                    }
                }
                dataBuffer.push(text);
                _resetTimer();
            }, _nodeIdSocket!);
        }
    }


    void setNodeSocketAndSkip(Socket socket) {
        skip = true;
        _nodeIdSocket = socket;
    }

    Future getRemoteIdCreationOfInstance(
        Function(dynamic message, Socket socket) onDataReceived) async {
        await tcpClient.receiveSocketsFromCNode((socket) async {
            await tcpClient.invokeListening((message, active) {
                onDataReceived(message['p3'], socket);
                dataBuffer.push(message['p4']);
            }, socket);
        });
    }


    //sendMessage is used to sent message to any node either relayed msg or normal message.
    //For different scenarios message function is developed in such a way that you can send your message to any node.
    Future<void> sendMessage(message) async {
        if (_nodeIdSocket != null) {
            _resetTimer();
            if (_type == 'TP') {
                if (_remoteNodeID != null) {
                    String toSend = tcpClient.createMessageJson(
                        _type, null, _remoteNodeID, _myNodeId, message, 4);
                    tcpClient.send(toSend, _nodeIdSocket!);
                }
                else {
                    print('no relay connection exits');
                }
            }
            else if (_type == 'D') {
                String toSend = tcpClient.createMessageJson(
                    'D', null, null, _myNodeId, message, 6);
                tcpClient.send(toSend, _nodeIdSocket!);
            }
            else if (_type == 'MP') {
                String toSend = tcpClient.createMessageJson(
                    _type, '_localIPv4', '_localPortIPv4', _myNodeId,
                    _remoteNodeID,
                    6);

                await tcpClient.send(toSend, _nodeIdSocket!);
                _type = 'D';
            }
        }
        else {
            print('_nodeSocket is null');
        }
    }


    Future<void> startNodeLiseNing(listeningPort) async {
        listening = await tcpClient.startASsNode(listeningPort);
    }


}
