//import 'package:b4rttable/routingmanager.dart';
//import 'package:b4commgr/b4commgr.dart';

import 'package:b4commgr/endPointAddress.dart';
import 'package:b4commgr/networkInformation.dart';
import 'package:nodeid/nodeid.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:pointycastle/ecc/api.dart';

import '../lib/testcomm.dart';

// Example demonstrating access to Node fields
void main() {
  /*
  final signature = ECSignature(
    r: BigInt.parse('1234567890123456789012345678901234567890'),
    s: BigInt.parse('9876543210987654321098765432109876543210'),
  );
      */
  /* final signature = {
    'r': BigInt.parse('123456789023456789012345678901234567890'),
    's': BigInt.parse('987654321087654321098765432109876543210'),
   };
   */
  dynamic signature = (
    BigInt.parse(
        '59113115870259811539959274853633452658244023164923021678175195815962387543400'),
    BigInt.parse(
        '82286668277613101558052527540933406110085242196986137870735735549510749303569')
  );
  // Create a NodeID with sample values
  final nodeID = NodeID.fromRaw(
    hashID: '24b7cced2e92a3a782698f59218c14e76e567f38',
    pubKey: '04a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2',
    sign: signature,
  );

  // Create an EndpointAddress with sample values
  final endpointAddress = EndpointAddress(
    nodeID: nodeID,
    publicipv4: '192.168.1.100',
    publicipv6: '2001:db8::1',
    publicipv4port: 8080,
    publicipv6port: 8080,
    proxyipv4: false,
    proxyipv6: true,
    protocol: 'UDP',
  );

  // Create a Node
  final node = Node(
    nodeID: nodeID,
    endpointAddress: endpointAddress,
  );

  // Access and print specific fields
  print('Node ID: ${node.nodeID.hashID}');
  print('Node Public Key: ${node.nodeID.pubKey}');
  print('Node Signature: ${node.nodeID.sign}');
  print('Protocol: ${node.endpointAddress.protocol}');
  print('Public IPv4: ${node.endpointAddress.publicipv4}');
  print('Public IPv6: ${node.endpointAddress.publicipv6}');
  print('IPv4 Port: ${node.endpointAddress.publicipv4port}');
  print('IPv6 Port: ${node.endpointAddress.publicipv6port}');
  print('Proxy IPv4: ${node.endpointAddress.proxyipv4}');
  print('Proxy IPv6: ${node.endpointAddress.proxyipv6}');

  // Print the full Node as JSON for reference
  print('\nFull Node JSON: ${node.toString()}');
}

/*
void main () async {

  final stunServer1 = 'stun.l.google.com';
  int stunport=19302;
//  RoutingManager routingManager=RoutingManager.instance;
CommunicationManager bcom=CommunicationManager();
NetworkDetails nd=NetworkDetails();
//bcom.getIps();NetworkDetails
//await bcom.getPublicIPAddresses();
//String publicIP = await bcom.getPublicIP('stun.l.google.com', 19302);
//print('Public IP: $publicIP');
//await bcom.printNetworkInterfaces();

  //await bcom.determineNATType();

 // List<List<dynamic>> activeIPs = await bcom.getNetworkInfo();

  List<List<dynamic>> activeIPs = await nd.getNetworkInfo(stunServer1,stunport);

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
*/
  /*
// ECSignature class for elliptic curve signature
class ECSignature {
  final BigInt r;
  final BigInt s;

  const ECSignature({
    required this.r,
    required this.s,
  });

  factory ECSignature.fromJson(Map<String, dynamic> json) {
    return ECSignature(
      r: BigInt.parse(json['r'] as String),
      s: BigInt.parse(json['s'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'r': r.toString(),
        's': s.toString(),
      };

  @override
  String toString() => 'ECSignature(r: $r, s: $s)';
}
    */