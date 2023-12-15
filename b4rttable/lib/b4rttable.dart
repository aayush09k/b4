library b4rttable;

import 'dart:math';
import 'package:nodeid/nodeid.dart';

class B4RoutingTable {

    Map<NodeID, int>? onHoldNodes; //NodeId & attemptsCounter; If a node is not reachable even after three attempts, it is purged.
    Map<NodeID, Duration> mRtt = {}; // For each nodeID, RTT value is also stored.
    LocalNodeID? localId; // Local Node's nodeID.
    List<List<NodeID?>> RoutingTable = List.generate(3, (_) => List.filled(40, null));

    B4RoutingTable() { // newly generated Local nodeID should be passed by calling module, after testing duplicate in the network.
        onHoldNodes = {};
        localId = LocalNodeID(); // Not to be generated here.
        localId!.nodeid.hashID="357E7DFC3E4616381DACA70A90CDF3C59EA80D32";
        //this is the node id for testing purpose, during testing un-comment this line of code.
    }

    // Function to update the nodeID in the routing table
    void updateNodeID(NodeID nodeID, Duration rtt) {
        //check if node is present in putOnHold, if present then remove from there.
        if (onHoldNodes != null) {
            if (onHoldNodes!.containsKey(nodeID)) {
                onHoldNodes!.remove(nodeID);
            }
        }
        mRtt![nodeID] = rtt;
        List<String>? nodeIdC = nodeID.hashID.split('');
        String? localnodeId = localId!.nodeid.hashID;
        List<String>? localnodeIdC = localnodeId!.split('');

        int m=-1;// index for finding first mis-match....
        for (int i = 0; i < 40; i++) {
            if (nodeIdC[i] != localnodeIdC[i]) {
                m=i;
                i=40;// to exit the loop after getting index of first mismatch
            }
        }
        if (nodeIdC[m] != localnodeIdC[m]) {
            //
            if (RoutingTable[0][m] == null && RoutingTable[1][m] == null && RoutingTable[2][m] == null) {

                RoutingTable[2][m] = nodeID;// If routing table is null in the column then copy the nodeID in all 3 rows of column.
                RoutingTable[1][m] = nodeID;
                RoutingTable[0][m] = nodeID;
            }
            // If routing table is not null, then we take node id of pre, succ and mid nodes. Then splitting the string node id into string of characters to compare.
            else {
                String? preNodeId = RoutingTable[2][m]?.hashID ;
                String? midNodeId = RoutingTable[1][m]?.hashID ;
                String? sucNodeId = RoutingTable[0][m]?.hashID ;

                List<String>? preNodeIdC = preNodeId!.split('');
                List<String>? midNodeIdC = midNodeId!.split('');
                List<String>? sucNodeIdC = sucNodeId!.split('');

                int preNodeIdint = int.parse(preNodeIdC[m], radix: 16);// converting hexadecimal value into int for comparison
                int midNodeIdint = int.parse(midNodeIdC[m], radix: 16);
                int sucNodeIdint = int.parse(sucNodeIdC[m], radix: 16);
                int localnodeIdint = int.parse(localnodeIdC[m], radix: 16);
                int nodeIdint = int.parse(nodeIdC[m], radix: 16);
                int idealMidNodeIdint = (localnodeIdint + 16) % 16;

                if (((localnodeIdint - preNodeIdint + 16) % 16) >
                        ((nodeIdint - preNodeIdint + 16) % 16)) {
                    RoutingTable[2][m] = nodeID;
                    //replacing pre-decessor nodeID
                } else if (((sucNodeIdint - localnodeIdint + 16) % 16) >
                           ((nodeIdint - localnodeIdint + 16) % 16)) {
                    RoutingTable[0][m] = nodeID; //replacing successor node id

                } else if (min(((idealMidNodeIdint - midNodeIdint + 16) % 16),
                               ((midNodeIdint - idealMidNodeIdint + 16) % 16)) >
                           min(((idealMidNodeIdint - nodeIdint + 16) % 16),
                               ((nodeIdint - idealMidNodeIdint + 16) % 16))) {
                    RoutingTable[1][m] = nodeID; // replacing middle node id
                }
                else if (nodeIdint == preNodeIdint && mRtt![nodeID]! > rtt) {
                    //Next 3 conditions are checking rtt if nodeID nibble matches which any of pre,success,mid nodeID.
                    RoutingTable[2][m] = nodeID; // NodeID having less rtt is kept in the routing table.
                } else if (nodeIdint == midNodeIdint && mRtt![nodeID]! > rtt) {
                    RoutingTable[1][m] = nodeID;
                } else if (nodeIdint == sucNodeIdint && mRtt![nodeID]! > rtt) {
                    RoutingTable[0][m] = nodeID;
                } else  {
                     mRTT!.remove(nodeID);
                }
            }
        }


    }

    // Put on hold function

    void putOnHold(NodeID nodeID) {
        {
            //  nodeiD(to be  place in hold table and remove from RT).ALso update number of attempts(ctr),
            //  if attempts>3 purge the NodeID
            // first check in on hold table and then check in RT for nearest bits.implements in else part this logic
            // Check if the NodeID is in RoutingTable and process it

            if (onHoldNodes!=null && onHoldNodes!.containsKey(nodeID)) {

                if (onHoldNodes![nodeID]! > 2) {
                    onHoldNodes!.remove(nodeID); // purge the NodId
                } else {
                    onHoldNodes![nodeID]=onHoldNodes![nodeID]!+1;
                }
            } else {
                List<String> nodeIdC = nodeID.hashID.split('');
                String? localnodeId = localId!.nodeid.hashID;
                List<String> localnodeIdC = localnodeId.split('');
                for (int i = 0; i < 40; i++) {
                    if (nodeIdC[i] != localnodeIdC[i]) {
                        for (int k = 0; k < 3; k++) {
                            if (RoutingTable[k][i]!.hashID == nodeID.hashID) {
                                onHoldNodes![nodeID] = 1;
                                removeNodeFromRoutingTable(k, i);
                                //RoutingTable[k][i] = null;
                            }
                        }
                        i=40;
                    }
                }
            }
        }
    }

    void removeNodeFromRoutingTable(int row, int col) {
        // RoutingTable[row][col] = null;
        if(row==0) {
            RoutingTable[row][col]=RoutingTable[1][col]; //cyclically copies the previous node, where node id needs to be removed
        }
        if(row==1) {
            RoutingTable[row][col]=RoutingTable[2][col];
        }
        if(row==2) {
            RoutingTable[row][col]=RoutingTable[0][col];

        }
    }

    List<List<NodeID?>> retrieveFullRT() {
        return RoutingTable;
    }



}


//       // Function to retrieve an array of changed entries since the last update
//       List<String> retrieveRTArrayChangedSinceLastUpdate() {
//         // updated flag entries in RT to be stored separately and Reset the update flag and return the list
//       }
//
//       // Function to determine the next hop based on hashID
//       // String nextHop(String hashID) {
//       //   //search in RT & based on Distance metric return the nearest Node.// return the object/Null
//       //   return "";
//       // }
//
//       String nextHop(String hashID) {
//         if (localId.nodeid.hashID == hashID) {
//           return localId.nodeid.hashID; // current node is the root node
//         }
//
//         else {
//           List<String> nodeIdC = hashID.split('');
//           String localnodeId = localId.nodeid.hashID;
//           List<String> localnodeIdC = localnodeId.split('');
//           List<int>? distance;
//
//           for (int i = 0; i < 40; i++) {
//             if (nodeIdC[i] != localnodeIdC[i]) {
//               for (int k = 0; k < 3; k++) {
//                 distance![k] =
//                     calculateDifference(RoutingTable[i][k]!.hashID, hashID);
//               }
//               if (distance!.isEmpty) {
//                 print("The list is empty.");
//               } else {
//                 int minDistance = distance.reduce((value, element) => value < element ? value : element);
//                 String hopID = RoutingTable[i][distance.indexOf(minDistance)]!.hashID;
//                 return hopID;
//               }
//             }
//           }
//           throw(e);
//                }
//       }
//
//       // Function to update the local node ID and endpoint address
//       void updateLocalNodeID(String localNodeID, String endpointAddress) {
//         //based on location changes the End Point Add may changed
//
//       }
//
//
//
//
// // DISTANCE METRIC
//
//     }
//

//   }
//   int calculateDifference(String nodeID, String hashId) {
//
//     int nodeIDint = int.parse(nodeID, radix: 16);
//     int hashIdint = int.parse(hashId, radix: 16);
//
//     int distance1 = (nodeIDint - hashIdint + 2^140) % 2^140;
//     int distance2 = (hashIdint - nodeIDint + 2^140) % 2^140;
//
//
//     //hexResult = distance.toRadixString(16).toUpperCase();
//     int Result = min(distance1, distance2);
//
//     return Result;
//   }
//
//   bool compareList(List<int> list1, List<int> list2)
//   {
//         bool flag=false;
//         for (int i = 0; i < list1.length && i < list2.length; i++) {
//           if (list1[i] > list2[i]) {
//             flag=true;
//           } else if (list1[i] < list2[i]) {
//             flag=false;
//           }
//
//     return flag;
//   }

// Function to put a node on hold
