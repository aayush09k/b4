//
// // Written by Sqn Ldr Aman Sharma......
// import 'dart:convert';
//
// import 'package:b4rttable/routingmanager.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:nodeid/nodeid.dart';
//
//
// import 'package:b4rttable/b4rttable.dart';
// import 'package:pointycastle/api.dart';
// import 'package:basic_utils/basic_utils.dart';
// import 'dart:io';
//
//
// void main() {
//
//   //LocalNodeID localnd = LocalNodeID();
//   LocalNodeID localId;
//   localId = LocalNodeID();
//   localId.nodeid.hashID = "3B7E7DFC3E4616381DACA70A90CDF3C59EA80D32";// setting hash ID of local node ID for testing purposes.
//   RoutingManager routingManager=RoutingManager.instance;
//   AsymmetricKeyPair keyPair1 = CryptoUtils.generateEcKeyPair();
//   NodeID nodeID=NodeID(keyPair1);
//   var rtt = Duration(hours: 0, minutes: 0, seconds: 0,milliseconds: 766);
//
//   AsymmetricKeyPair keyPair2 = CryptoUtils.generateEcKeyPair();
//   var rtt2 = Duration(hours: 0, minutes: 0, seconds: 0,milliseconds: 800);
//   NodeID nodeID2=NodeID(keyPair2);
//
//   AsymmetricKeyPair keyPair3 = CryptoUtils.generateEcKeyPair();
//   var rtt3 = Duration(hours: 0, minutes: 0, seconds: 0,milliseconds: 120);
//   NodeID nodeID3=NodeID(keyPair3);
//
//   group('B4rtTableTestCase', () {
//
//     test('Testing updation of node id when entire RT contains only null', () {
//
//       // Arrange
//
//
//       nodeID.hashID="3C3DFF86B4573BAC05C8BD40FAAE7FE4938D3E13";
//
//       B4RoutingTable b4RoutingTable = B4RoutingTable(localId);
//
//
//       // Act
//       b4RoutingTable.updateNodeID(nodeID, rtt);
//
//       List<String> result = [];
//       result.add(b4RoutingTable.RoutingTable[0][1]!.hashID);
//       result.add(b4RoutingTable.RoutingTable[1][1]!.hashID);
//       result.add(b4RoutingTable.RoutingTable[2][1]!.hashID);
//
//       // Assert
//      List<String>  testString =["3C3DFF86B4573BAC05C8BD40FAAE7FE4938D3E13","3C3DFF86B4573BAC05C8BD40FAAE7FE4938D3E13","3C3DFF86B4573BAC05C8BD40FAAE7FE4938D3E13"];
//
//         print(b4RoutingTable.RoutingTable);
//          expect(result, testString);
//
//     });
//
//
//     test('Testing updation of node id when RT is non-empty', () {
//       B4RoutingTable b4RoutingTable = B4RoutingTable(localId);
//       // Arrange
//       //B4RoutingTable b4RoutingTable = B4RoutingTable(localId);
//       // nodeID.hashID="3C3DFF86B4573BAC05C8BD40FAAE7FE4938D3E13";
//       // nodeID2.hashID="3AE815704A566EB541D91F5D58DEE4E627D2BB1E";
//       // nodeID3.hashID="37E815704A566EB541D91F5D58DEE4E627D2BB1E";
//
//    //   routingManager.createMessageRM();
//
// //Act
//      b4RoutingTable.updateNodeID(nodeID, rtt);// updating the first nodeID.It is similar to above test ie. RT contains only null.
//       b4RoutingTable.updateNodeID(nodeID2, rtt);
//       b4RoutingTable.updateNodeID(nodeID3, rtt);
//
//
//
//
//       List<List<Map<String, dynamic>?>> jsonList = b4RoutingTable.RoutingTable.map((innerList) {
//         return innerList.map((nodeID) {
//           if (nodeID != null) {
//             return {
//               'hashID': nodeID.hashID,
//               'publicKey': nodeID.pubKey.toString(),
//               'sign':{'r':nodeID.sign.r.toString(),
//                        's':nodeID.sign.s.toString()},
//               'publicKeyPem':nodeID.publicKeyPem.toString(),
//               // Add other properties if needed
//             };
//           } else {
//             return null;
//           }
//         }).toList();
//       }).toList();
//
//       // Convert to JSON String
//       String jsonString = jsonEncode(jsonList);
//
//       // Write to file
//       final file = File('C:\\Users\\Aman Sharma\\OneDrive\\Desktop\\New folder\\data.json');
//       file.writeAsStringSync(jsonString);
//       // Write the JSON data to a file
//
//
//       final file_read = File('C:\\Users\\Aman Sharma\\OneDrive\\Desktop\\New folder\\data.json');
//       final jsonString_read = file_read.readAsStringSync();
//
//       // Parse JSON
//       List<dynamic> jsonList1 = jsonDecode(jsonString_read);
//
//       // Convert back to List<List<NodeID?>>
//       List<List<NodeID?>> nodeList = jsonList1.map((innerList) {
//         return (innerList as List<dynamic>).map((jsonNode) {
//           if (jsonNode != null) {
//             ECSignature?  signature = ECSignature(BigInt.parse( jsonNode['sign']['r']),BigInt.parse(jsonNode['sign']['s']));
//             return NodeID.createFromTable(
//               jsonNode['pubKey'], // Assuming this is how you reconstruct pubKey
//               jsonNode['hashID'],
//               signature, // Assuming this is how you reconstruct sign
//               jsonNode['publicKeyPem'],
//             );
//           } else {
//             return null;
//           }
//         }).toList();
//       }).toList();
// print(nodeList);
//
//
//       // print("same node id is present on all 3 rows(first update function call)");
//      //  for(int i=0;i<3;i++){
//      //
//      //    print(b4RoutingTable.RoutingTable[i][1]!.hashID);
//      //  }
//      // b4RoutingTable.updateNodeID(nodeID2, rtt2);// updating the new node ID , when RT already contains a nodeID(ie not null)
//      //  print("mrtt value of node id2 ${b4RoutingTable.mRtt[nodeID2]}");
//      //  b4RoutingTable.updateNodeID(nodeID3, rtt3);
//      //  print("mrtt value of node id2 when node is removed from entire RT  ${b4RoutingTable.mRtt[nodeID2]}");
//      //
//      //  print("status of node if after update function(third update function call)");
//      //  String result=b4RoutingTable.RoutingTable[0][1]!.hashID;
//      //
//      //  // Assert
//      //
//      //      for(int i=0;i<3;i++){
//      //
//      //    print(b4RoutingTable.RoutingTable[i][1]!.hashID);
//      //  }
//      //
//      //
//      //  expect(result,  nodeID3.hashID);
//
//     });
//
//
//     // test('Testing  put on hold functionality and remove from RT table functionality when nodeID is not present in onHold Map ', () {
//     //
//     //   // Arrange
//     //
//     //   B4RoutingTable b4RoutingTable = B4RoutingTable(localId);
//     //   nodeID.hashID="3C3DFF86B4573BAC05C8BD40FAAE7FE4938D3E13";
//     //   nodeID2.hashID="3AE815704A566EB541D91F5D58DEE4E627D2BB1E";
//     //
//     //
//     //
//     //   // Act
//     //   b4RoutingTable.updateNodeID(nodeID, rtt);
//     //   b4RoutingTable.updateNodeID(nodeID2, rtt2);
//     //
//     //   for(int i=0;i<3;i++){
//     //
//     //     print("suc,mid,pre node ids before calling put on hold  ${b4RoutingTable.RoutingTable[i][1]!.hashID}"); // printing the node id of pre,suc and mid node IDs before put on hold
//     //
//     //
//     //   }
//     //
//     //   b4RoutingTable.putOnHold(nodeID2);// calling putOnHold function.
//     //
//     //
//     //   String result=b4RoutingTable.RoutingTable[0][1]!.hashID;
//     //
//     //   // Assert
//     //      print("\n");
//     //   for(int i=0;i<3;i++){
//     //
//     //     print("suc,mid,pre node ids after calling put on hold ${b4RoutingTable.RoutingTable[i][1]!.hashID}"); // printing the node id of pre,suc and mid node IDs
//     //
//     //
//     //   }
//     //
//     //   expect(result,  nodeID.hashID);
//     //
//     // });
//     //
//     //
//     // test('Testing  put on hold functionality and remove from RT table functionality when nodeID is  present in onHold Map', () {
//     //
//     //   // Arrange
//     //
//     //   B4RoutingTable b4RoutingTable = B4RoutingTable(localId);
//     //   nodeID.hashID="3C3DFF86B4573BAC05C8BD40FAAE7FE4938D3E13";
//     //   nodeID2.hashID="3AE815704A566EB541D91F5D58DEE4E627D2BB1E";
//     //
//     //
//     //
//     //   // Act
//     //   b4RoutingTable.updateNodeID(nodeID, rtt);
//     //   b4RoutingTable.updateNodeID(nodeID2, rtt2);
//     //
//     //   for(int i=0;i<3;i++){
//     //
//     //     print("suc,mid,pre node ids before calling put on hold  ${b4RoutingTable.RoutingTable[i][1]!.hashID}"); // printing the node id of pre,suc and mid node IDs before put on hold
//     //
//     //
//     //   }
//     //   b4RoutingTable.putOnHold(nodeID2);
//     //
//     //
//     //   String result=b4RoutingTable.RoutingTable[0][1]!.hashID;
//     //
//     //   // Assert
//     //   print("\n");
//     //   for(int i=0;i<3;i++){
//     //
//     //     print("suc,mid,pre node ids after calling put on hold ${b4RoutingTable.RoutingTable[i][1]!.hashID}"); // printing the node id of pre,suc and mid node IDs
//     //
//     //
//     //   }
//     //   print("value of counter of node id in onHold Map ${b4RoutingTable.onHoldNodes![nodeID2]}");
//     //   print("calling putonhold fucntion again 2 times ");
//     //   b4RoutingTable.putOnHold(nodeID2);
//     //   b4RoutingTable.putOnHold(nodeID2);
//     //   print("value of counter of node id in onHold Map ${b4RoutingTable.onHoldNodes![nodeID2]}");
//     //
//     //
//     //   expect(result,  nodeID.hashID);
//     //
//     // });
//     //
//     //
//     //
//     // test('Testing  put on hold functionality and remove from RT table functionality by calling update node id', () {
//     //
//     //   // Arrange
//     //
//     //   B4RoutingTable b4RoutingTable = B4RoutingTable(localId);
//     //   nodeID.hashID="3C3DFF86B4573BAC05C8BD40FAAE7FE4938D3E13";
//     //   nodeID2.hashID="3AE815704A566EB541D91F5D58DEE4E627D2BB1E";
//     //
//     //
//     //
//     //   // Act
//     //   b4RoutingTable.updateNodeID(nodeID, rtt);
//     //   b4RoutingTable.updateNodeID(nodeID2, rtt2);
//     //
//     //   for(int i=0;i<3;i++){
//     //
//     //     print("suc,mid,pre node ids before calling put on hold  ${b4RoutingTable.RoutingTable[i][1]!.hashID}"); // printing the node id of pre,suc and mid node IDs before put on hold
//     //
//     //
//     //   }
//     //   b4RoutingTable.putOnHold(nodeID2);
//     //
//     //
//     //   String result=b4RoutingTable.RoutingTable[0][1]!.hashID;
//     //
//     //   // Assert
//     //   print("\n");
//     //   for(int i=0;i<3;i++){
//     //
//     //     print("suc,mid,pre node ids after ${b4RoutingTable.RoutingTable[i][1]!.hashID}"); // printing the node id of pre,suc and mid node IDs
//     //
//     //
//     //   }
//     //   print("value of counter of node id in onHold Map ${b4RoutingTable.onHoldNodes![nodeID2]}");
//     //   print("calling updateNodeId function ");
//     //   b4RoutingTable.updateNodeID(nodeID2,rtt);
//     //
//     //   print("\nvalue of counter of node id in onHold Map ${b4RoutingTable.onHoldNodes![nodeID2]}");
//     //
//     //
//     //   expect(result,  nodeID.hashID);
//     //
//     // });
//     // test('Testing  function for finding Next Hop when column contains null', () {
//     //
//     //   // Arrange
//     //
//     //   B4RoutingTable b4RoutingTable = B4RoutingTable(localId);
//     //   nodeID.hashID="3C3DFF86B4573BAC05C8BD40FAAE7FE4938D3E13";
//     //   nodeID2.hashID="3AE815704A566EB541D91F5D58DEE4E627D2BB1E";
//     //   //localID =3B7E7DFC3E4616381DACA70A90CDF3C59EA80D32
//     //
//     //   // Act
//     //   b4RoutingTable.updateNodeID(nodeID, rtt);
//     //   b4RoutingTable.updateNodeID(nodeID2, rtt2);
//     //
//     //   print(b4RoutingTable.RoutingTable);
//     //   print("\n");
//     //
//     //
//     //   for(int i=0;i<3;i++){
//     //
//     //     print("suc,mid,pre node ids before calling put on hold  ${b4RoutingTable.RoutingTable[i][1]!.hashID}"); // printing the node id of pre,suc and mid node IDs before put on hold
//     //
//     //
//     //   }
//     //
//     //
//     //
//     //   String result=b4RoutingTable.nextHop("4CE815704A566EB541D91F5D58DEE4E627D2BB1E");
//     //
//     //
//     //   // Assert
//     //   print("\n");
//     //
//     //
//     //
//     //   expect(result,  "3C3DFF86B4573BAC05C8BD40FAAE7FE4938D3E13");
//     //
//     // });
//     //
//     // test('Testing  function for finding Next Hop when all column after first mismatch between local id and hashid are null', () {
//     //
//     //   // Arrange
//     //
//     //   B4RoutingTable b4RoutingTable = B4RoutingTable(localId);
//     //   nodeID.hashID="3C3DFF86B4573BAC05C8BD40FAAE7FE4938D3E13";
//     //   nodeID2.hashID="3AE815704A566EB541D91F5D58DEE4E627D2BB1E";
//     //   //localID =3B7E7DFC3E4616381DACA70A90CDF3C59EA80D32
//     //
//     //   // Act
//     //   b4RoutingTable.updateNodeID(nodeID, rtt);
//     //   b4RoutingTable.updateNodeID(nodeID2, rtt2);
//     //
//     //   print(b4RoutingTable.RoutingTable);
//     //   print("\n");
//     //
//     //
//     //   for(int i=0;i<3;i++){
//     //
//     //     print("suc,mid,pre node ids before calling put on hold  ${b4RoutingTable.RoutingTable[i][1]!.hashID}"); // printing the node id of pre,suc and mid node IDs before put on hold
//     //
//     //
//     //   }
//     //
//     //
//     //
//     //   String result=b4RoutingTable.nextHop("3BE815704A566EB541D91F5D58DEE4E627D2BB1E");
//     //
//     //
//     //   // Assert
//     //   print("\n");
//     //
//     //
//     //
//     //   expect(result,  "3B7E7DFC3E4616381DACA70A90CDF3C59EA80D32");
//     //
//     // });
//     // // Add more tests as needed
//   });
//
// }
