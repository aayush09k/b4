import 'dart:async';
import 'package:flutter/material.dart';
import 'package:b4commgr/b4commgr.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final CommunicationManager communicationManager = CommunicationManager();


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter B4Commgr Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(communicationManager: communicationManager),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final CommunicationManager communicationManager;

  MyHomePage({required this.communicationManager});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
    startStreaming();
    sendMessage();
    getNetworkInformation();
    activateNode();
    sendMessages();
    getData();
  }
  int? natStatus;
  void startStreaming() async {
    String remoteNodeId = 'google';
    await widget.communicationManager.startStreaming(remoteNodeId);
  }

  void sendMessage() async {
    var bootstrapIp = '35.185.142.164';
    var bootstrapPort = 22355;
    var type = 'D';
    var message = 'RRT';
    final String remoteNodeId = 'google';
    await widget.communicationManager.sendMessage(
        bootstrapIp, bootstrapPort, type, message, remoteNodeId);
  }

  void getNetworkInformation() async {
    var stunIp = 'stun.l.google.com';
    var stunPort = 19302;
    natStatus = await widget.communicationManager.getNetworkInformation(stunIp, stunPort);
    print(natStatus);
  }

  void activateNode() async {
    var listeningPort = 22355;
    var proxyIp = '35.185.142.164';
    var proxyPort = 22355;
    var remoteNodeId3 = 'google';
    // Use the actual natStatus here
    await widget.communicationManager.activateNode(
        proxyIp, proxyPort, listeningPort, natStatus, remoteNodeId3);
  }

  void sendMessages() async {
    await Future.delayed(Duration(seconds: 15));

    var proxyIP = '35.185.142.164';
    var proxyPORT = 22355;
    var type1 = 'TP';
    var remoteNodeId1 = 'psj';
    var message1 = 'i am sending proxy message to myself';
    await widget.communicationManager.sendMessage(
        proxyIP, proxyPORT, type1, message1, remoteNodeId1);

    var proxyIP2 = '35.185.142.164';
    var proxyPORT2 = 22355;
    var type12 = 'TP';
    var remoteNodeId12 = 'aman';
    var message2 = 'THIS IS MESSAGE FROM PUSHPENDRA';
    await widget.communicationManager.sendMessage(
        proxyIP2, proxyPORT2, type12, message2, remoteNodeId12);
  }

  Future<void> getData() async {
    Timer.periodic(Duration(seconds: 3), (timer) async {
      print(await widget.communicationManager.getBufferData());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter B4Commgr Example'),
      ),
      body: Center(
        child: Text('B4Commgr Example'),
      ),
    );
  }
}
