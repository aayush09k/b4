import 'dart:async';
import 'dart:io';
import 'connectivity_monitor.dart';
import 'stungetip.dart';
import 'tcpConnection.dart';

class B4connection  {
// This class is used to 
// 1. setup connection to other nodes directly or via their relays. For each other node, 
//  a separate connection instance is to be created, as connection is bound to nodeID of other node.
// 2. setup a server, either directly or via current nodes relay (root in non-NATed DHT) for IPv4
// 3. setup a server, either directly or via current nodes relay (root in non-NATed DHT) for IPv4
// 4. Sending message to other node as configured in the connection.
// 5. Receiving message from other node as configured in the connection.

    //Declaration of all required variables.

    String? stunServer;
    int? stunPort;

    String? _publicIPv4;
    String? _localIPv4;
    int? _localPortIPv4;
    String? _publicIPv6;

    int? natStatus; // According to this when we start connection a different type of messages is sent initially to other node.
    int K = 0;// for dart terminal app purpose.
    int skip = 0; // skipping the closing of sNode sockets for the first time in 'monitor.onConnectivityChanged.listen((interfaces){}' function.

    bool? chatMode;
    String? type; //It stores the input from the user.It helps in connection and messaging.
    // type can be 'TP=when someone wants to relay to NATed node via proxy',
    // 'MP=when you are NATed node and you need to connect to your proxy',
    // 'DTN=when you want direct connection from behind NAT to a public node',
    // 'D and else anything= for public nodes . for direct connection to each other'.


    String? subtype; //subtype used in special case when a NATed peer (ipv4) wants to talk to a ipv6 node.
    String _myNodeId='macbook';
    ServerSocket? listening;
    Socket? loCalcNodeSocket;


    InternetAddress? targetIp;
    int? targetPort;
    String? proxyIpPub = '35.185.142.164';
    int? proxyPortPub = 22350;
    dynamic rxData;
    String? remoteNodeID;





    //Instance of class used.
    final monitor = ConnectivityMonitor();
    StunClient stunClient = StunClient();
    TcpClient tcpClient = TcpClient();





    void remoteSocketClose() {
        if (tcpClient.Key() != null) {
            tcpClient.remoteSocketCloses(tcpClient.Key());
        }
    }

    void finishTheConnection(){
        tcpClient.disconnectFroMsNode();
    }

    void setMyNodeId(id){
        _myNodeId=id;
    }

//Below function can be use to connect with other peer.Here you have to give the type of connection 'TP(To proxy)','MP(be my proxy)','D'(direct connection),'DTP'(Direct through NAT).
    Future<Socket?> startConnection(targetIp, targetPort,typeOfConnection,remoteNodeId) async {
        remoteNodeID = remoteNodeId;
        type = typeOfConnection;

        if (tcpClient.isConnected()) {
            tcpClient.disconnectFroMsNode();
        }

        loCalcNodeSocket =await tcpClient.connect(targetIp, targetPort);

        if(type=='MP'){
            String toSend = tcpClient.createMessageJson(
                type, _localIPv4, _localPortIPv4, remoteNodeID, _myNodeId, 6);
            await sendMessage(toSend);
        }

        K =5;
        return loCalcNodeSocket;
    }



    // A callback function that will be used by the communication manager for receiving data.
    // receiveText FroM server Node.
    Future receiveTexFroMsNode(Function(dynamic message) onDataReceived) async {
        await  tcpClient.receiveAsaClient((text)  {
                onDataReceived(text);
        });
    }

    Future receiveTexFroMcNode(Function(dynamic message) onDataReceived) async {
        await  tcpClient.receiveAsaServer((text)  {
            onDataReceived(text);
        });
    }


    //sendMessage is used to sent message to any node either relayed msg or normal message.
    //For different scenarios message function is developed in such a way that you can send your message to any node.
    Future<void> sendMessage(message) async {

        if(type=='TP'){
            if (remoteNodeID != null) {
                print(
                    'case 1 ke relayToNodeKey null or remoteKey null nahi wale me agya me  ');
                String toSend = tcpClient.createMessageJson(
                    type, null, remoteNodeID, null, message, 4);
                tcpClient.send(toSend);
            }
            else {
                print(
                    'case 1 ke relayToNodeKey null or remoteKey null wale me agya me  ');
                print('no relay connection exits');
            }
        }
        else if (type=='D'){
            if (tcpClient.isConnected()) {
                print('case 3 ke tcpclient.isconnected me agye ');
                tcpClient.send(tcpClient.createMessageJson(
                    type, null, null, null, message, 6));
            }
            else if (tcpClient.isListening()) {
                print('case 3 ke tcpclient.isListening me agye ');
                var key = tcpClient.Key();
                await tcpClient.relayBackToNode(key,
                    tcpClient.createMessageJson(
                        null, null, null, null, message, 0));
            }
        }
        else if(type=='MP'){
         tcpClient.send(message);
         receiveTexFroMsNode((message) => print(message));
        }

    }

    //Putting all the ip and port inside the global variables.
    Future<void> _getAllIpPort() async {
        try {
            if (stunClient.getPublicIPv4() != null) {
                _localIPv4 = stunClient.getLocalIPv4()!.address;
                _localPortIPv4 = stunClient.getLocalPortIPv4();
            }

            if (stunClient.getPublicIPv4() != null) {
                _publicIPv4 = stunClient.getPublicIPv4()!.address;
                //_publicPortIPv4 = stunClient.getPublicPortIPv4();
            }

            if (stunClient.getPublicIPv6() != null) {
                _publicIPv6 = stunClient.getPublicIPv6()!.address;
               // _publicPortIPv6 = stunClient.getPublicPortIPv6();
            }
        }
        catch (e) {
            print('error in getting all ports');
        }
        _printAllPort();
    }


    //According to the information gathered it will start Listening for connection or
    // else it will be connected to provided  proxy sNode.

    Future<void> activateNode(proxyIp,proxyPort,listeningPort) async {
     switch(natStatus){
         case 0:print('Behind NAT in ipv4system');
     // listening= await tcpClient.startASsNode(listeningPort);
     //receiveTexFroMcNode((message) => print(message));
      startConnection(proxyIp, proxyPort, 'MP',null);
         case 1:print('Not behind NAT in ipv4 system');startNodeLiseNing(listeningPort); receiveTexFroMcNode((message) => print(message));
         case 2:print('System is on ipv6 ');  await startNodeLiseNing(listeningPort);receiveTexFroMcNode((message) => print(message));
     }
    }

    Future<void> startNodeLiseNing(listeningPort) async {
        listening= await tcpClient.startASsNode(listeningPort);
    }


    //Below function is for checking your network environment.
    Future<int?> getNetworkInformation(String stunIp,int stunPort) async {
        //Start connection with STUN server for all the network information.
        // Try to connect to stun server by ipv4 and ipv6 both one by one.
        monitor.onConnectivityChanged.listen((interfaces) async {
            natStatus = 0;

            if (skip >= 1) {
                if (tcpClient.isListening()) {
                    tcpClient.stopASsNode();
                    listening!.close();
                }
            }

            print('Network interfaces changed');
            for (var interface in interfaces) {
                print('Interface: ${interface.name}');
            }

            try {
                await stunClient.initializeIpv4();
                await stunClient.fetchPublicIPIpv4(stunIp, stunPort);
                await stunClient.closeIpv4(); //After getting information closed immediately.
                stunClient.N = 2;
                stunClient.resetIP();
                try {
                    await stunClient.initializeIpv6();
                    await stunClient.fetchPublicIPIpv6(stunIp, stunPort);
                    await stunClient
                        .closeIpv6(); //After getting information closed immediately.
                }
                catch (e) {
                    print(
                        'Node can not bind to both at a time . Node is not on dual network ');
                    stunClient.N = 2;
                    stunClient.resetIP();
                }
            }
            catch (e) {
                print("Error with IPv4 STUN client: $e");
                try {
                    //error connecting by ipv4 hence shift to ipv6.
                    await stunClient.initializeIpv6();
                    await stunClient.fetchPublicIPIpv6(stunIp, stunPort);
                    await stunClient
                        .closeIpv6(); //After getting information closed immediately.
                    //Below logic is implemented to making previous values of ip and port null.
                    stunClient.N = 0;
                    stunClient.resetIP();
                }
                catch (e) {
                    print("Error with IPv6 STUN client: $e");
                    stunClient.N = 3;
                    stunClient.resetIP();
                }
            }
            await _getAllIpPort();
            skip = 2;
            if (_publicIPv6 != null) {
                natStatus = 2;
            }
            else {
                switch (stunClient.NATcheckIpv4()) {
                    case true:
                        {
                            natStatus = 1;
                            break;
                        }
                    case false:
                        {
                            natStatus = 0;
                            break;
                        }
                }
            }

            activateNode(proxyIpPub, proxyPortPub, 22350);

        });
      return natStatus;
    }

    void dispose() {
        monitor.dispose();
    }

    void _printAllPort() {
        print('PUBLIC IPV4=${stunClient
            .getPublicIPv4()}, PUBLIC IPV4 PORT=${stunClient
            .getPublicPortIPv4()}');
        print('LOCAL IPV4=${stunClient
            .getLocalIPv4()}, LOCAL IPV4 PORT=${stunClient
            .getLocalPortIPv4()}');
        print('PUBLIC IPV6=${stunClient
            .getPublicIPv6()}, PUBLIC IPV6 PORT=${stunClient
            .getPublicPortIPv6()}');
    }

}

