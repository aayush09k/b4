import 'dart:async';

import 'package:b4commgr/b4commgr.dart';
import 'package:b4rttable/b4rttable.dart';
import 'package:b4rttable/routingmanager.dart';

void main () async {

  CommunicationManager communicationManager = CommunicationManager();
  RoutingManager routingManager=RoutingManager.instance;


//for getting data from the  common buffer.
  Future<void> getData() async {
    Timer.periodic(Duration(seconds: 3), (timer) async {
      print(await communicationManager.getBufferData());
    });
  }

  await Future.delayed(Duration(seconds: 10));
//await getData();
}