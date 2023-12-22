// Written by Sqn Ldr Aman Sharma...

library b4rttable;

import 'dart:math';
import 'package:nodeid/nodeid.dart';

class B4RoutingTable {
  Map<NodeID, int>? onHoldNodes; //NodeId & attemptsCounter
  Map<NodeID, Duration> mRtt = {};
  LocalNodeID? localIdb;
  List<List<NodeID?>> RoutingTable = List.generate(
      3, (_) => List.filled(40, null));

  B4RoutingTable(LocalNodeID localId) {
    onHoldNodes = {};

    localIdb = localId;
    // localId!.nodeid.hashID = "357E7DFC3E4616381DACA70A90CDF3C59EA80D32"; //this is the node id for testing purpose, during testing un-comment this line of code.
  }

  // Function to update the nodeID in the routing table.When any new Node Id is received by the node, it is always updated in RT table using this function only.

  void updateNodeID(NodeID nodeID, Duration rtt) {
    //check if node is present in putonHold, if present them remove from there.
    if (onHoldNodes != null) {
      if (onHoldNodes!.containsKey(nodeID)) {
        onHoldNodes!.remove(nodeID);
      }
    }
    mRtt[nodeID] = rtt;
    List<String>? nodeIdC = nodeID.hashID.split('');
    String? localNodeId = localIdb!.nodeid.hashID;
    List<String> localNodeIdC = localNodeId.split('');

    int m = -1; // initialising variable for index for finding first mis-match....
    for (int i = 0; i < 40; i++) {
      if (nodeIdC[i] != localNodeIdC[i]) {
        m = i;
        i = 40; // to exit the loop after getting index of first mismatch
      }
    }
    if (nodeIdC[m] != localNodeIdC[m]) {
      //
      if (RoutingTable[0][m] == null && RoutingTable[1][m] == null &&
          RoutingTable[2][m] == null) {
        RoutingTable[2][m] =
            nodeID; // If routing table is null in the column then copy the nodeID in all 3 rows of column.
        RoutingTable[1][m] = nodeID;
        RoutingTable[0][m] = nodeID;
      }
      // If routing table is not null, then we take node id of pre, succ and mid nodes.Then splitting the string node id into string of characters to compare.
      else {
        String? preNodeId = RoutingTable[2][m]?.hashID;
        String? midNodeId = RoutingTable[1][m]?.hashID;
        String? sucNodeId = RoutingTable[0][m]?.hashID;

        List<String>? preNodeIdC = preNodeId!.split('');
        List<String>? midNodeIdC = midNodeId!.split('');
        List<String>? sucNodeIdC = sucNodeId!.split('');

        int preNodeIdint = int.parse(preNodeIdC[m],
            radix: 16); // coverting hexadecimal value into int for comparison
        int midNodeIdint = int.parse(midNodeIdC[m], radix: 16);
        int sucNodeIdint = int.parse(sucNodeIdC[m], radix: 16);
        int localnodeIdint = int.parse(localNodeIdC[m], radix: 16);
        int nodeIdint = int.parse(nodeIdC[m], radix: 16);
        int idealMidNodeIdint = (localnodeIdint + 16) % 16;

        if (((localnodeIdint - preNodeIdint + 16) % 16) >
            ((nodeIdint - preNodeIdint + 16) % 16)) {
          if (mRtt.containsKey(RoutingTable[2][m]!.hashID) &&
              (RoutingTable[2][m] != RoutingTable[1][m] ||
                  RoutingTable[2][m] != RoutingTable[0][m])) {
            mRtt.remove(RoutingTable[2][m]!
                .hashID); // this is done so that if node ID is not present anywhere in RT then it should also not be present in mRTT table.
          }
          RoutingTable[2][m] = nodeID; //replacing pre-decessor nodeID


        } else if (((sucNodeIdint - localnodeIdint + 16) % 16) >
            ((nodeIdint - localnodeIdint + 16) % 16)) {
          if (mRtt.containsKey(RoutingTable[0][m]) &&
              (RoutingTable[0][m]!.hashID != RoutingTable[1][m]!.hashID ||
                  RoutingTable[0][m]!.hashID != RoutingTable[2][m]!.hashID)) {
            mRtt.remove(RoutingTable[0][m]);
          }

          RoutingTable[0][m] = nodeID; //replacing successor node id


        } else if (min(((idealMidNodeIdint - midNodeIdint + 16) % 16),
            ((midNodeIdint - idealMidNodeIdint + 16) % 16)) >
            min(((idealMidNodeIdint - nodeIdint + 16) % 16),
                ((nodeIdint - idealMidNodeIdint + 16) % 16))) {
          if (mRtt.containsKey(RoutingTable[1][m]!.hashID) &&
              (RoutingTable[1][m] != RoutingTable[0][m] ||
                  RoutingTable[1][m] != RoutingTable[2][m])) {
            mRtt.remove(RoutingTable[1][m]!.hashID);
          }


          RoutingTable[1][m] = nodeID; // replacing middle node id

        } else if (nodeIdint == preNodeIdint && mRtt[nodeID]! > rtt) {
          if (mRtt.containsKey(RoutingTable[2][m]!.hashID) &&
              (RoutingTable[2][m] != RoutingTable[1][m] ||
                  RoutingTable[2][m] != RoutingTable[0][m])) {
            mRtt.remove(RoutingTable[2][m]!.hashID);
          }


          //Next 3 conditions are checking rtt if nodeID nibble matches which any of pre,success,mid nodeID.


          RoutingTable[2][m] =
              nodeID; // NodeID having less rtt is kept in the routing table.

        } else if (nodeIdint == midNodeIdint && mRtt[nodeID]! > rtt) {
          if (mRtt.containsKey(RoutingTable[1][m]!.hashID) &&
              (RoutingTable[1][m] != RoutingTable[0][m] ||
                  RoutingTable[1][m] != RoutingTable[2][m])) {
            mRtt.remove(RoutingTable[1][m]!.hashID);
          }
          RoutingTable[1][m] = nodeID;
        } else if (nodeIdint == sucNodeIdint && mRtt[nodeID]! > rtt) {
          if (mRtt.containsKey(RoutingTable[0][m]!.hashID) &&
              (RoutingTable[0][m] != RoutingTable[1][m] ||
                  RoutingTable[0][m] != RoutingTable[2][m])) {
            mRtt.remove(RoutingTable[0][m]!.hashID);
          }
          RoutingTable[0][m] = nodeID;
        }
      }
    }
    else if (mRtt.containsKey(nodeID)) {
      mRtt.remove(nodeID);
    }
  }

  // Put on hold function

  void putOnHold(NodeID nodeID) {
    {
      //  nodeiD(to be  place in hold table and remove from RT).ALso update number of attempts(ctr),
      //  if attempts>3 purge the NodeID
      // first check in on hold table and then check in RT for nearest bits.implements in else part this logic
      // Check if the NodeID is in RoutingTable and process it

      if (onHoldNodes != null && onHoldNodes!.containsKey(nodeID)) {
        if (onHoldNodes![nodeID]! >= 2) {
          onHoldNodes!.remove(nodeID); // purge the NodeId
        } else {
          onHoldNodes![nodeID] = onHoldNodes![nodeID]! + 1;
          if (mRtt.containsKey(nodeID)) {
            mRtt.remove(nodeID);
          }
        }
      } else {
        List<String> nodeIdC = nodeID.hashID.split('');
        String? localnodeId = localIdb!.nodeid.hashID;
        List<String> localnodeIdC = localnodeId.split('');
        for (int i = 0; i < 40; i++) {
          if (nodeIdC[i] != localnodeIdC[i]) {
            for (int k = 0; k < 3; k++) {
              if (RoutingTable[k][i]!.hashID == nodeID.hashID) {
                onHoldNodes![nodeID] = 1;
                removeNodeFromRoutingTable(k, i);
              }
            }
            i = 40;
          }
        }
      }
    }
  }

  void removeNodeFromRoutingTable(int row, int col) {
    // This function ensures that while removing node  RT table in a particular column , that column should not remain partially empty.
    if (row == 0) {
      RoutingTable[row][col] =
      RoutingTable[1][col]; //cyclically copies the previous node, where node id needs to be removed
    }
    if (row == 1) {
      RoutingTable[row][col] = RoutingTable[2][col];
    }
    if (row == 2) {
      RoutingTable[row][col] = RoutingTable[1][col];
    }
  }

  List<List<NodeID?>> retrieveFullRT() {
    return RoutingTable;
  }

  // Function to retrieve an array of changed entries since the last update
  List<String> retrieveRTArrayChangedSinceLastUpdate() {
    return ["test", "test"];
    // updated flag entries in RT to be stored separately and Reset the update flag and return the list
  }

  // Function to determine the next hop based on hashID
  // String nextHop(String hashID) {
  //   //search in RT & based on Distance metric return the nearest Node.// return the object/Null
  //   return "";
  // }

  int calculateDistance(String nodeID, String hashId) {
    int nodeIDint = int.parse(nodeID, radix: 16);
    int hashIdint = int.parse(hashId, radix: 16);

    int distance1 = (nodeIDint - hashIdint + 16) % 16;
    int distance2 = (hashIdint - nodeIDint + 16) % 16;

    int result = min(distance1, distance2);

    return result;
  }





  // Function to update the local node ID and endpoint address
  void updateLocalNodeID(String localNodeID, String endpointAddress) {
    //based on location changes the End Point Add may changed
  }

// DISTANCE METRIC

  String nextHop(String hashID) {
    if (localIdb!.nodeid.hashID == hashID) {
      return localIdb!.nodeid.hashID; // current node is the root node

    }
    else {
      List<String> hashIdC = hashID.split('');
      String localNodeId = localIdb!.nodeid.hashID;
      List<String> localNodeIdC = localNodeId.split('');
      List<int>? distanceHashId;
      int distanceLocalID;
      int firstMisMatch = -1;
      int l = -1,
          i = -1;

      for (i = 0; i < 40; i++) {
        if (hashIdC[i] != localNodeIdC[i]) {
          firstMisMatch = i;
          if (RoutingTable[0][i] == null) {
            for ( l = i; l < 40; l++) {
              if (RoutingTable[0][l] == null) {
                l++;
                i++;
              }
              else {
                l = 40;
              }
            }
          }
          i = 40;
        }
      }

      String? preNodeId = RoutingTable[2][i]?.hashID;
      String? midNodeId = RoutingTable[1][i]?.hashID;
      String? sucNodeId = RoutingTable[0][i]?.hashID;

      List<String>? preNodeIdC = preNodeId!.split('');
      List<String>? midNodeIdC = midNodeId!.split('');
      List<String>? sucNodeIdC = sucNodeId!.split('');


      if (hashIdC[firstMisMatch] != localNodeIdC[firstMisMatch])
      {
        distanceHashId![0] = calculateDistance(preNodeIdC[firstMisMatch], hashIdC[firstMisMatch]);
        distanceHashId[1] = calculateDistance(midNodeIdC[firstMisMatch], hashIdC[firstMisMatch]);
        distanceHashId[2] = calculateDistance(sucNodeIdC[firstMisMatch], hashIdC[firstMisMatch]);
        distanceLocalID = calculateDistance(localNodeIdC[firstMisMatch], hashIdC[firstMisMatch]);


        if (distanceHashId[0] < distanceLocalID && distanceHashId[1] > distanceLocalID && distanceHashId[2] > distanceLocalID)
        {
          return preNodeId;
        }
        else if (distanceHashId[1] < distanceLocalID && distanceHashId[0] > distanceLocalID && distanceHashId[2] > distanceLocalID) {
          return midNodeId;
        }

        else if (distanceHashId[2] < distanceLocalID && distanceHashId[1] > distanceLocalID && distanceHashId[0] > distanceLocalID) {
          return sucNodeId;
        }


        }
      else {
        return localNodeId;
      }

    }
   throw(e);
  }

}
