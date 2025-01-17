
//import 'package:b4rttable/routingmanager.dart';
//import 'package:b4commgr/b4commgr.dart';

import '../lib/b4commgr.dart';

void main () async {

  final stunServer1 = 'stun.l.google.com';
//  RoutingManager routingManager=RoutingManager.instance;
CommunicationManager bcom=CommunicationManager();
//bcom.getIps();
//await bcom.getPublicIPAddresses();
//String publicIP = await bcom.getPublicIP('stun.l.google.com', 19302);
//print('Public IP: $publicIP');
//await bcom.printNetworkInterfaces();

  await bcom.determineNATType();

  List<List<dynamic>> activeIPs = await bcom.getNetworkInfo();

  if (activeIPs.isEmpty) {
    print('No active IPs found.');
  } else {
    print('All IPs of active interface:');
    for (var ipInfo in activeIPs) {
      print('Type: ${ipInfo[0]}, Address: ${ipInfo[1]}, Private: ${ipInfo[2]},Public IP: ${ipInfo[3]},Public Port: ${ipInfo[4]} NATed: ${ipInfo[5]}, NAT Type: ${ipInfo[6]}');
      //print('Public IP: ${ipInfo[3]},Public Port: ${ipInfo[4]} NATed: ${ipInfo[5]}, NAT Type: ${ipInfo[6]}');
    }
  }
/*
    bcom.getNetworkAddress();
    String? publicIP = await bcom.getPublicIP1(stunServer1 , 19302);
    print('Public IP: $publicIP');
    if (publicIP != null) {
      bool isBehindNAT = await bcom.checkIfBehindNAT(publicIP);
      print(isBehindNAT
          ? "The device is behind a NAT."
          : "The device is not behind a NAT.");
    } else {
      print("Failed to determine public IP.");
    }


 //    var sip4 =bcom.stunIpAddress4('stun.l.google.com');
  //   var sip6=bcom.stunIpAddress6('stun.l.google.com');
    // print(sip6);

     bcom.getStunPublicIPAddresses(stunServer1);

    */

}