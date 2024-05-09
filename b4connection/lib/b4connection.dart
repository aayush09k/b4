import 'dart:async';
import 'dart:io';
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

    Timer? _inactivityTimer; // Timer used to delete the b4connection instance if it is not used the connection.

    String? _type;
    //It stores the input from the user.It helps in connection and messaging.
    // type can be 'TP=when someone wants to relay to NATed node via proxy(relay=yes)',
    // 'MP=when you are NATed node and you need to connect to your proxy(relay registration)',
    // 'D and else anything= for public nodes . for direct connection to each other(relay=no)'.



    // Below two very important variable for each instance of b4connection.
    String? _remoteNodeID; // Two which you want to send the message or relay the message.
    Socket? _nodeIdSocket; // it will be fixed and unique after creating the b4connection instance.
    String _myNodeId = 'google'; // For each of b4connection instance you need to set this.

    Function? onClosed; // Callback to execute when the connection is closed.
    Map <Socket,dynamic> eliminate={};


    //Instance of class used.
    TcpClient tcpClient = TcpClient();
    DataBuffer dataBuffer = DataBuffer();


    void setMyNodeId(id) {
        _myNodeId = id;
    }

    // When you receive or else you send you need to reset the timer for existence of the b4connection instance.
    void _resetTimer() {
        _inactivityTimer?.cancel();
        _inactivityTimer = Timer(const Duration(minutes: 5), () {
            // This code will execute after 5 minutes of inactivity
            close();
        });
    }


    //Below function can be use to connect with other peer.Here you have to give the type of connection 'TP(To proxy)','MP(be my proxy)','D'(direct connection).
    Future<Socket?> startConnection(targetIp, targetPort, typeOfConnection,
        remoteNodeId) async {
        _remoteNodeID = remoteNodeId;
        _type = typeOfConnection;

        _nodeIdSocket = await tcpClient.connect(targetIp, targetPort);

        await bufferReceivingData();

        return _nodeIdSocket;
    }

    void close() {

        if (_nodeIdSocket != null) {
            tcpClient.closeConnection(_nodeIdSocket!);
            if (onClosed != null) {
                onClosed!(); // Trigger the callback when closing.
            }
        }

        _inactivityTimer?.cancel();
    }


    // A callback function that will be used by the communication manager for receiving data.
    // receiveText FroM  any socket of the node.
    Future bufferReceivingData() async {
        if (_nodeIdSocket != null) {
            await tcpClient.invokeListening((dynamic text, active) {
                if (!active) {
                  close();
                } else{
                dataBuffer.push(text['message']);
                _resetTimer();
                }
            }, _nodeIdSocket!);
        }
    }

   // Whenever we receive socket from the any cNode we create a b4connection instance in CM corresponding to that nodeID.
    // then we set _nodeIdSocket fo created instance =socket received.
    void setNodeSocket(Socket socket) {
        _nodeIdSocket = socket;
    }

    // It listen for the receiving socket and help CM to create new instance correspond to the received socket and nodeId.
    Future getRemoteIdCreationOfInstance(
        Function(dynamic message, Socket socket,bool active) onDataReceived) async {
        Socket? store;
        await tcpClient.receiveSocketsFromCNode((socket) async {

            await tcpClient.invokeListening((message, active) {

                if(active){
                    eliminate[socket]=message['myNodeID'];
                    store =socket;
                    if((message['type']==null)){
                dataBuffer.push(message['message']);}
                    else{
                        if(message['type']=='TP'){}
                        else{
                            dataBuffer.push(message['message']);
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
    Future<void> sendMessage(message, typeOfConnection, remoteNodeID) async {
        _type = typeOfConnection;
        _remoteNodeID = remoteNodeID;

        if (_nodeIdSocket != null) {
            _resetTimer();
            if (_type == 'TP') {
                if (_remoteNodeID != null) {
                    String toSend = tcpClient.createMessageJson(
                        _type, _remoteNodeID, _myNodeId, message);
                    tcpClient.send(toSend, _nodeIdSocket!);
                }
                else {
                    print('no relay connection exits');
                }
            }
            else if (_type == 'D') {
                String toSend = tcpClient.createMessageJson(
                    _type,_remoteNodeID, _myNodeId, message);
                tcpClient.send(toSend, _nodeIdSocket!);
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
            if (onClosed != null) {
                onClosed!(); // Trigger the callback when closing.
            }
        }
    }


    Future<void> startNodeLiseNing(listeningPort) async {
         await tcpClient.startASsNode(listeningPort);
    }


}
