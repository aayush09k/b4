import 'dart:async';
import 'dart:io';
import 'connectivity_monitor.dart';
import 'stungetip.dart';
import 'tcpConnection.dart';

class B4connection {

    //Declaration of all required variables.
    int? reset;
    String? stunServer;
    int? stunPort;

    String? _publicIPv4;
    String? _localIPv4;
    int? _localPortIPv4;
    int? _publicPortIPv4;
    String? _publicIPv6;
    int? _publicPortIPv6;

    int? natStatus; //When
    String? sendLocalAnswer = 'hey bro  this is my answer for your offer';
    String? remoteAnswer;
    String? sendLocalOffer = 'hey bro this offer from my side';
    String? remoteOffer;


    InternetAddress? targetIp;
    int? targetPort;
    String? proxyIpv4Pub = '35.185.142.164';
    int? proxyIpv4Port = 22356;
    int K = 0;

    ServerSocket? Listening;
    bool? chatMode;
    String? type; //It stores the input from the user.It helps in connection and messaging.
    String? remoteKey;

    String? subtype;
    String? _myKey = 'google';
    int M = 0; //for Handling sendMessage function for different kinds of scenarios.
    int skip = 0;

    //Instance of class used.
    final monitor = ConnectivityMonitor();
    StunClient stunClient = StunClient();
    TcpClient tcpClient = TcpClient();


    B4connection(this.stunServer, this.stunPort) {
        monitor.onConnectivityChanged.listen((interfaces) {
            natStatus = 0;
            reset = 0;
            M = 0;
            if (skip >= 1) {
                if (tcpClient.isListening()) {
                    tcpClient.stopServer();
                    Listening!.close();
                }
            }
            _getNetworkInformation();
            skip = 2;
            print('Network interfaces changed');
            for (var interface in interfaces) {
                print('Interface: ${interface.name}');
            }
        });
    }

    //When you are not requesting for connection to someone . then you will be listening in background automatically.
    //function for starting server. if you are publicly available then this function will invoke automatically according to layerID assigned.
    Future<void> _startServerTcp() async {
        switch (natStatus) {
            case 1:
                {
                    print('server is running for private nodes');
                    try {
                        await tcpClient.startServer();
                    }
                    catch (e) {
                        print('problem in socket');
                    }
                    break;
                }
            case 0:
                {
                    try {
                        await tcpClient.startServer();
                    }
                    catch (e) {
                        print('problem in scoket');
                    }
                    break;
                }
            case 2:
                {
                    try {
                        await tcpClient.startServer();
                    }
                    catch (e) {
                        print('problem in socket');
                    }
                    break;
                }
            case 3:
                {
                    await tcpClient.startServer();
                    break;
                }
            case 4:
                {
                    try {
                        await tcpClient.startServer();
                    }
                    catch (e) {
                        print('problem in socket');
                    }
                    break;
                }
            case null:
                {
                    print('natStatus not defined');
                }
        }
    }

    void setRemoteNodeKey(key) {
        remoteKey = key;
    }

    void remoteSocketClose() {
        if (tcpClient.Key() != null) {
            tcpClient.remoteSocketCloses(tcpClient.Key());
        }
    }

    Future<void> disconnectRelay() async {
        if (tcpClient.relayToNodeKey != null) {
            tcpClient.send(tcpClient.createMessageJson(
                type, null, tcpClient.relayToNodeKey, null, 'disconnect', 4));
        }
        else {
            tcpClient.send(tcpClient.createMessageJson(
                type, null, remoteKey, null, 'disconnect', 4));
        }

        remoteKey = null;
        print('relayDisconnected');
    }

//Below function can be use to connect with other peer.Here you have to give the type of connection 'TP(To proxy)','MP(be my proxy)','D'(direct connection),'DTP'(Direct through NAT).
    Future<void> startConnection(targetIp, targetPort, T) async {
        print(T);
        if (tcpClient.isConnected()) {
            tcpClient.disconnect();
            // for dart terminal app purpose.
        }
        await _creatingConnection(targetIp, targetPort, T);
        K = 5;
    }

    void setSubtype() {
        subtype = 'GP';
    }

    Future _creatingConnection(targetIp, targetPort, T) async {
        type = T;
        if (T == 'DTN') {
            await tcpClient.connect(targetIp, targetPort);
            String toSend = tcpClient.createMessageJson(
                type, _localIPv4, _localPortIPv4, remoteKey, _myKey, 6);
            tcpClient.send(toSend);
            return;
        }

        switch (natStatus) {
            case 0:
                await tcpClient.connect(targetIp, targetPort);
                tcpClient.receive((message) => null);
                String toSend = tcpClient.createMessageJson(
                    type, _localIPv4, _localPortIPv4, remoteKey, _myKey, 6);
                tcpClient.send(toSend);
                break;
            case 1:
                await tcpClient.connect(targetIp, targetPort);
                tcpClient.receive((message) => null);
                String toSend = tcpClient.createMessageJson(
                    type, _publicIPv4, Listening!.port, remoteKey, _myKey, 6);
                tcpClient.send(toSend);
                break;
            case 2:
                await tcpClient.connect(targetIp, targetPort);
                tcpClient.receive((message) => null);
                String toSend = tcpClient.createMessageJson(
                    type, _publicIPv6, Listening!.port, remoteKey, _myKey, 6);
                tcpClient.send(toSend);
                break;
        }
    }

    //sendMessage is used to sent message to any node either relayed msg or normal message.
    //For different scenarios message function is developed in such a way that you can send your message to any node.
    Future<void> sendMessage(message) async {
        if (tcpClient.makeRemoteKeyNull()) {
            remoteKey = null;
            print('remotekey ko null bnane wale if me agya me ');
        }
        switch (tcpClient.nodeHandler()) {
            case 0:
                {
                    if (tcpClient.relayToNodeKey != null) {
                        print(
                            'send function ke case 0 me agya me usme relayToNode key null nhi wale condition me agya');
                        String toSend = tcpClient.createMessageJson(
                            type, null, tcpClient.relayToNodeKey, null, message,
                            4);
                        tcpClient.send(toSend);
                    }
                    else {
                        print(
                            'send function ke case 0 me agya me usme relayToNode key null wale condition me agya');
                        if (subtype != null) {
                            print('subtype null nahi wale mw agya me');
                            String msg = tcpClient.createMessageJson(
                                subtype, null, null, targetIp, targetPort, 3);
                            String toSend = tcpClient.createMessageJson(
                                type, null, tcpClient.relayToNodeKey, _myKey,
                                msg, 34);
                            tcpClient.send(toSend);
                        }
                        else {
                            print('subtype null he  wale mw agya me');
                            String toSend = tcpClient.createMessageJson(
                                type, null, tcpClient.relayToNodeKey, _myKey,
                                message, 5);
                            tcpClient.send(toSend);
                        }
                    }
                }
            case 1:
                {
                    if (tcpClient.relayToNodeKey != null) {
                        print(
                            'case 1 ke relayToNodeKey null nahi wale me agya me  ');
                        String toSend = tcpClient.createMessageJson(
                            type, null, tcpClient.relayToNodeKey, null, message,
                            4);
                        tcpClient.send(toSend);
                    }
                    else {
                        if (remoteKey != null) {
                            print(
                                'case 1 ke relayToNodeKey null or remoteKey null nahi wale me agya me  ');
                            String toSend = tcpClient.createMessageJson(
                                type, null, remoteKey, null, message, 4);
                            tcpClient.send(toSend);
                        }
                        else {
                            print(
                                'case 1 ke relayToNodeKey null or remoteKey null wale me agya me  ');
                            print('no relay connection exits');
                        }
                    }
                }
            case 2:
                {
                    if (tcpClient.isListening()) {
                        print('case 2 ke tcpclient.listening me agye ');
                        await tcpClient.relayBackToNode('ipv6',
                            tcpClient.createMessageJson(
                                'TP', null, tcpClient.relayToNodeKey, null,
                                message, 4));
                    }
                }
            case 3:
                {
                    if (tcpClient.isConnected()) {
                        print('case 3 ke tcpclient.isconnected me agye ');
                        tcpClient.send(tcpClient.createMessageJson(
                            null, null, null, null, message, 0));
                    }
                    else if (tcpClient.isListening()) {
                        print('case 3 ke tcpclient.isListening me agye ');
                        var key = tcpClient.Key();
                        await tcpClient.relayBackToNode(key,
                            tcpClient.createMessageJson(
                                null, null, null, null, message, 0));
                    }
                }
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
                _publicPortIPv4 = stunClient.getPublicPortIPv4();
            }

            if (stunClient.getPublicIPv6() != null) {
                _publicIPv6 = stunClient.getPublicIPv6()!.address;
                _publicPortIPv6 = stunClient.getPublicPortIPv6();
            }
        }
        catch (e) {
            print('error in getting all ports');
        }
        _printAllPort();
    }

    //This below function will check whether node is behind NAT or not  also public availability.
    //According to the information gathered it will start server or else it will start collecting nearest proxy servers list.
    Future<void> _natCheckAndStartNode() async {
        if (_publicIPv6 != null) {
            print('System is on ipv6 ');
            natStatus = 2;
            _startServerTcp();
        }
        else {
            switch (stunClient.NATcheckIpv4()) {
                case true:
                    {
                        print('Not behind NAT in ipv4 system');
                        natStatus = 1;
                        _startServerTcp();
                        break;
                    }
                case false:
                    {
                        print('Behind NAT in ipv4system');
                        natStatus = 0;
                        _startServerTcp();
                       //startConnection(proxyIpv4Pub, proxyIpv4Port, 'MP');
                        break;
                    }
            }
        }
    }


    //Below function is for checking your network environment. According to your network you will be provided a layerID.
    //Hence after getting a layerID either you will be working as a server or  a leaf node.
    //You behaving as server can connect with other public node also you can help others to connect(Those are behind NAT) .
    Future<void> _getNetworkInformation() async {
        //Start connection with STUN server for all the network information.
        //first try to connect to stun server by ipv4 and ipv6 both one by one.
        try {
            await stunClient.initializeIpv4();
            await stunClient.fetchPublicIPIpv4(stunServer, stunPort);
            await stunClient
                .closeIpv4(); //After getting information closed immediately.
            stunClient.N = 2;
            stunClient.resetIP();
            try {
                await stunClient.initializeIpv6();
                await stunClient.fetchPublicIPIpv6(stunServer, stunPort);
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
                await stunClient.fetchPublicIPIpv6(stunServer, stunPort);
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
        //This below function body is defined above already. I will call here after getting all information of the system.
        _natCheckAndStartNode();
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

