import 'dart:async';

import 'package:b4commgr/b4commgr.dart';
import 'package:b4rttable/b4rttable.dart';
import 'package:b4rttable/routingmanager.dart';
import 'package:b4utils/bufferdata.dart';

void main () async {

  CommunicationManager communicationManager = CommunicationManager();
  DataBuffer dataBuffer=DataBuffer();
  RoutingManager routingManager=RoutingManager.instance;


//for getting data from the  common buffer.
  Future<void> getData() async {
    Timer.periodic(const Duration(seconds: 3), (timer) async {
      print(dataBuffer.pull());
    });
  }

  await Future.delayed(const Duration(seconds: 10));
//await getData();
}