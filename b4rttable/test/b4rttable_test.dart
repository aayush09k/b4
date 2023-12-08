

import 'package:flutter_test/flutter_test.dart';
import 'package:nodeid/nodeid.dart';

import 'dart:typed_data';
import 'package:b4rttable/b4rttable.dart';
import 'package:pointycastle/api.dart';
import 'package:basic_utils/basic_utils.dart';

// Written by Sqn Ldr Aman Sharma....

void main() {

  //LocalNodeID localnd = LocalNodeID();
  AsymmetricKeyPair keyPair1 = CryptoUtils.generateRSAKeyPair(keySize: 2048);
  NodeID nodeID=NodeID(keyPair1);
  var rtt = Duration(hours: 0, minutes: 0, seconds: 0,milliseconds: 766);

  AsymmetricKeyPair keyPair2 = CryptoUtils.generateRSAKeyPair(keySize: 2048);
  var rtt2 = Duration(hours: 0, minutes: 0, seconds: 0,milliseconds: 800);
  NodeID nodeID2=NodeID(keyPair2);

  group('B4rtTableTestCase', () {

    test('Testing updation of node id when entire RT contains only null', () {

      // Arrange
      B4RoutingTable b4RoutingTable = B4RoutingTable();
      nodeID.hashID="3C3DFF86B4573BAC05C8BD40FAAE7FE4938D3E13";


      // Act
      b4RoutingTable.updateNodeID(nodeID, rtt);

      List<String> result = [];
      result.add(b4RoutingTable.RoutingTable[0][1]!.hashID);
      result.add(b4RoutingTable.RoutingTable[1][1]!.hashID);
      result.add(b4RoutingTable.RoutingTable[2][1]!.hashID);

      // Assert
     List<String>  testString =["3C3DFF86B4573BAC05C8BD40FAAE7FE4938D3E13","3C3DFF86B4573BAC05C8BD40FAAE7FE4938D3E13","3C3DFF86B4573BAC05C8BD40FAAE7FE4938D3E13"];

        print(b4RoutingTable.RoutingTable);
         expect(result, testString);

    });


    test('Testing updation of node id when RT is non-empty', () {

      // Arrange
      B4RoutingTable b4RoutingTable = B4RoutingTable();
      nodeID.hashID="3C3DFF86B4573BAC05C8BD40FAAE7FE4938D3E13";
      nodeID2.hashID="3AE815704A566EB541D91F5D58DEE4E627D2BB1E";



      // Act
     b4RoutingTable.updateNodeID(nodeID, rtt);
     b4RoutingTable.updateNodeID(nodeID2, rtt2);


      String result=b4RoutingTable.RoutingTable[0][1]!.hashID;

      // Assert

          for(int i=0;i<3;i++){

        print(b4RoutingTable.RoutingTable[i][1]!.hashID);
      }


      expect(result,  nodeID2.hashID);

    });


    test('Testing  put on hold functionality and remove from RT table functionality ', () {

      // Arrange
      B4RoutingTable b4RoutingTable = B4RoutingTable();
      nodeID.hashID="3C3DFF86B4573BAC05C8BD40FAAE7FE4938D3E13";
      nodeID2.hashID="4AE815704A566EB541D91F5D58DEE4E627D2BB1E";



      // Act
      b4RoutingTable.updateNodeID(nodeID, rtt);
      b4RoutingTable.updateNodeID(nodeID2, rtt2);

      for(int i=0;i<3;i++){

        print("suc,mid,pre node ids before calling put on hold  ${b4RoutingTable.RoutingTable[i][1]!.hashID}"); // printing the node id of pre,suc and mid node IDs before put on hold


      }
      b4RoutingTable.putOnHold(nodeID2);


      String result=b4RoutingTable.RoutingTable[0][1]!.hashID;

      // Assert
         print("\n");
      for(int i=0;i<3;i++){

        print("suc,mid,pre node ids after calling put on hold ${b4RoutingTable.RoutingTable[i][1]!.hashID}"); // printing the node id of pre,suc and mid node IDs


      }
      print("value of counter of node id in onHold Map ${b4RoutingTable.onHoldNodes![nodeID2]}");
      print("calling putonhold fucntion again 3 times ");
      b4RoutingTable.putOnHold(nodeID2);
      b4RoutingTable.updateNodeID(nodeID2, rtt2);

      b4RoutingTable.putOnHold(nodeID2);
      b4RoutingTable.putOnHold(nodeID2);
      print("value of counter of node id in onHold Map ${b4RoutingTable.onHoldNodes![nodeID2]}");

      expect(result,  nodeID.hashID);

    });



    // Add more tests as needed
  });

}
