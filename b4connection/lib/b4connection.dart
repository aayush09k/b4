import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'connectivity_monitor.dart';
import 'stungetip.dart';
import 'tcpConnection.dart';

class B4connection {


    int? step=0;
    int? reset;
    String? stunServer;
    int? stunPort;
    String? _publicIPv4;
    String? _localIPv4;
    int? _localPortIPv4;
    int? _publicPortIPv4;
    String? _publicIPv6;
    int? _publicPortIPv6;
    int? layerID;
    String? sendLocalAnswer='hey bro  this is my answer for your offer';
    String? remoteAnswer;
    String? sendLocalOffer='hey bro this offer from my side';
    String? remoteOffer;
    TcpClient tcpClient=TcpClient();
    List<List<String>>? rtTable;
    InternetAddress? targetIp;
    String? ipv4Pub='172.17.85.135';
    int? ipv4Port=65248;
    final monitor = ConnectivityMonitor();

    StunClient stunClient = StunClient();
    ServerSocket? Listening;
    bool? chatMode;
    Socket? socketMe;


    B4connection(this.stunServer,this.stunPort) {
        var i=0;

        monitor.onConnectivityChanged.listen((interfaces) {
            layerID=0;
            reset=0;
            if(i>1) {
                tcpClient.stopServer();
                Listening!.close();
            }
            systemInformation();
            i++;
            print('Network interfaces changed');
            for (var interface in interfaces) {
                print('Interface: ${interface.name}');
            }
        });
    }

//When you are not requesting for connection to someone . then you will be listening in background automatically.
//function for starting server. if you are publicly available then this function will invoke automatically.
Future<void> startServerTcp()async{
    print('layerID=$layerID');
    print(reset);
    print('\nPlease enter the target IP:');
    switch(layerID) {
    case 0: {
        print('server is running for private nodes');
        try {
            await tcpClient.startServer();
        }
        catch(e) {
            print('problem in socket');
        }
        break;
    }
    case 1:
        try {
            await tcpClient.startServer();
        }
        catch(e) {
            print('problem in scoket');
        }
        break;
    case 2:
        try {
            await tcpClient.startServer();
        }
        catch(e) {
            print('problem in socket');
        }
        break;
    case 3:
        await tcpClient.startServer();
        tcpClient.startServer();
        break;
    case 4:
        try {
            await tcpClient.startServer();
        }
        catch(e) {
            print('problem in socket');
        }
        break;
    case null:
        print('layerID not defined');
    }

}

//Start connection will always call by the initiating peer who wants to connect.
Future<void>startConnection(targetIp,targetPort) async {
    // here below you can send the offer and ice candidates to the remote peer and you will switch to Webrtc. you should close tcpserver then.
    step=2;
    if(reset==0) {
        print(reset);
        await tcpClient.connect(targetIp, targetPort);

        switch (layerID) {
        case 0:
            String toSend = "D|$_localIPv4|$_publicPortIPv4|macbook";
            tcpClient.receive((message) => null);
            sendMessage(toSend);
            break;
        case 1:
            String toSend = "D|$_publicIPv4|${Listening!.port}";
            sendMessage(toSend);
            break;
        case 2:
            String toSend = "D|$_publicIPv6|${Listening!.port}|dellpublic";
            sendMessage(toSend);
            break;
        }
    }

}

void sendMessage(message) {
if(tcpClient.isConnected()){
    tcpClient.send(message);
    reset=1;}
else if(tcpClient.isListening()) {
    var remoteSocket = tcpClient.getRemoteSocket();
    remoteSocket!.write(message);
}

else{
    print('neither Listening nor connected cant send message');
}

}

    Future<void> getAllIpPort() async{
        //Putting all the ip and port inside the global variables.
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
        catch(e) {
            print('error in geting all ports');
        }
        printAllPort();
    }

//systemInformation function is for checking your network environment. According to your network you will be provided a layerID.
//Hence after getting a layerID either you will be working as a server or  a leaf node.
//You behaving as server can connect with other public node also you can help others to connect(Those are behind NAT) .
Future<void> systemInformation() async {


    // Start connection with STUN server for all the network information.
    try {
        await stunClient.initializeIpv4();
        await stunClient.fetchPublicIPIpv4(stunServer,stunPort);
        await stunClient.closeIpv4();
        stunClient.N=2;
        stunClient.resetIP();
        try {

            await stunClient.initializeIpv6();
            await stunClient.fetchPublicIPIpv6(stunServer,stunPort);
            await stunClient.closeIpv6();
        }
        catch(e) { //After getting information closed immediately.
            print('both cant bind');
        }
    }
    catch (e) {
        print("Error with IPv4 STUN client: $e");
        try {
            await stunClient.initializeIpv6();
            await stunClient.fetchPublicIPIpv6(stunServer,stunPort);
            await stunClient.closeIpv6();//CLOSED because getting error in connection by ipv4.
            stunClient.N=0;
            stunClient.resetIP();
            //error connecting by ipv4 hence shift to ipv6.
            // After getting information closed immediately.

        }
        catch (e) {
            print("Error with IPv6 STUN client: $e");
            stunClient.N=3;
            stunClient.resetIP();
        }
    }
    await getAllIpPort();
    //This function is inside the systemInformation.It will check whether node is behind NAT or not  also public availability.
    //According to the information gathered it will start server or else it will start collecting nearest proxy servers list.
    Future<void> startSystem() async {
        if(_publicIPv6!=null) {
            print('System is on ipv6 ');
            layerID = 2;
            startServerTcp();
        }

        else {
            switch(stunClient.NATcheckIpv4()) {
            case true: {
                print('Not behind NAT in ipv4 system');
                layerID=1;
                startServerTcp();
                break;
            }
            case false: {
                print('Behind NAT in ipv4system');
                layerID=0;
                startConnection(ipv4Pub,ipv4Port);
            }
            }
        }
    }
    //This function body is defined above already. i will call here after getting all information of the system.

    startSystem();
}

void dispose() {
    monitor.dispose();

}

void printAllPort() {
    print('PUBLIC IPV4=${stunClient.getPublicIPv4()}, PUBLIC IPV4 PORT=${stunClient.getPublicPortIPv4()}');
    print('LOCAL IPV4=${stunClient.getLocalIPv4()}, LOCAL IPV4 PORT=${stunClient.getLocalPortIPv4()}');
    print('PUBLIC IPV6=${stunClient.getPublicIPv6()}, PUBLIC IPV6 PORT=${stunClient.getPublicPortIPv6()}');

}

}

