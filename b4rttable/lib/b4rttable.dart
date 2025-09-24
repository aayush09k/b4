// Written by Sqn Ldr Aman Sharma, Sqn Ldr Tarun Chaudhary...
// Improved, Documented and Unit Tested by Sampurn Gupta...

library b4rttable;

import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:nodeid/nodeid.dart';
import 'package:b4connection/B4connection.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:b4commgr/endPointAddress.dart';
// import 'package:nodeid/src/nodeid_base.dart';
//import 'package:latlong2/latlong.dart';
//import 'package:geolocator/geolocator.dart';

/// Represents a B4 Routing Table that stores and manages node IDs and related data.
///
/// refer package: nodeid/src/nodeid_base.dart for info on [NodeID] class and [LocalNodeID] class.
class B4RoutingTable {
  Map<NodeID, int>? onHoldNodes;
  Map<String, Duration> mRtt = {};
  String? LayerID;
  LocalNodeID?
  localIdb; //this is just a variable of type LocalNodeID: NOT an OBJECT
  // localIdb gets initialied when the B4RoutingTable's Object is created ie. Constructor is Called
  // and this constructor is called after the peer joins the Network and its LocalNodeID is created.

  ///creating a sample Routing Table with 3 rows and 40 columns: each column represents a node at different level
  List<List<NodeID?>> RoutingTable =
  List.generate(3, (_) => List.filled(40, null)); // To be removed later.
  List<NodeID?> neibhourTable = List.generate(16, (index) => null);
  List<NodeID?> latLongTable = List.generate(16, (index) => null);
  Map<NodeID, List<String>>? latLongLocal;

  ///  initialising the co-ordinates
  List<double>? coords = [0.0, 0.0];

  /// Constructor: Creates a [B4RoutingTable] with the given [localIdb].
  ///
  /// it is constructor in which local node is passed as a parameter.
  B4RoutingTable(this.localIdb) : onHoldNodes = {};

  /// This function receives Routing table of other node and has access to the local Routing table.
  /// It checks for each nodeID in RT and update it's own local Routing table, based on the routing algorithm(chord-tapestry).
  void updateRtTable(List<List<NodeID?>> rtTable) async {
    List<NodeID> mainList = [];

    // traversing through the received routing table
    // and creating a mainList of nodes that are not in the local routing table
    for (int j = 0; j < 40; j++) {
      for (int i = 0; i < 3; i++) {
        // optimizing
        if (i > 0) {
          if (rtTable[0][j] == rtTable[1][j] &&
              rtTable[1][j] == rtTable[2][j]) {
            //all three levels are same, so no need to check further
            break;
          } else if (rtTable[i][j] == rtTable[i - 1][j]) {
            //two levels are same, so no need to check further
            continue;
          }
        }
        NodeID? node = rtTable[i][j];
        //check if the node is not NULL and is not the local node
        if (node != null && node.hashID != localIdb!.nodeid.hashID) {
          // Check if the node is present in the onHoldNodes map
          // If yes: ping it: if it replies, add it to the mainList
          // If no: do not add it to the mainList
          if (onHoldNodes!.containsKey(node)) {
            B4connection connection = B4connection();
            Socket? socketcheck;

            if (node.publicIpv4 != null && node.publicIpv4Port != null) {
              // If the node has public IPv4 address, try to connect to it
              socketcheck = await connection.startConnection(node.publicIpv4,
                  node.publicIpv4Port, node.natStatus, node.hashID);
            } else if (node.publicIpv6 != null && node.publicIpv6Port != null) {
              // If the node has public IPv6 address, try to connect to it
              socketcheck = await connection.startConnection(node.publicIpv6,
                  node.publicIpv6Port, node.natStatus, node.hashID);
            }

            if (socketcheck != null) {
              // If the connection is successful, add the node to the mainList
              mainList.add(node);
              // Remove the node from the onHoldNodes map
              onHoldNodes!.remove(node);
              connection.close();
            } else {
              putOnHold(node);
            }
          } else {
            // Check if the node is already in the local routing table
            // Check all three levels of the local routing table
            // If not, add it to the local routing table
            // also check if it is not already in the mainList
            if (!RoutingTable[0].contains(node) &&
                !RoutingTable[1].contains(node) &&
                !RoutingTable[2].contains(node) &&
                !mainList.contains(node)) {
              mainList.add(node);
            }
          }
        }
      }
    }

    // Now we have a mainList of nodes that are not in the local routing table
    // We will now update the local routing table with these nodes
    // 1. sort the mainList based on the Local NodeID hashID
    // 2. add the nodes to the local routing table
    // 3. move to the next nibble
    for (int i = 0; i < 40; i++) {
      String prefix = localIdb!.nodeid.hashID.substring(0, i + 1);
      List<List<NodeID>> splitList = helper_updateRtTable(mainList, prefix);

      mainList = splitList[0]; //updated mainList with matching nodes
      List<NodeID> nonMatching = splitList[1];

      // nonMatching.sort(); // Sorts lexicographically : but nonMatching is of type NodeID
      // Sort the nonMatching list based on the hashID of NodeID
      // nonMatching.sort((a, b) => a.hashID.compareTo(b.hashID));
      // NOTE: we cannot use the default sort method as it sorts lexicographically
      // We need to sort based on the hashID of NodeID, which is a hexadecimal
      // Sort by numeric value (base-16)
      // Not lexicographic (where '10' < '2') also

      nonMatching.sort((a, b) =>
          BigInt.parse(a.hashID, radix: 16)
              .compareTo(BigInt.parse(b.hashID, radix: 16)));
      // Now we have a SORTED list of nodes that DONOT match the prefix
      // We will now update the local routing table COLUMN i with these nodes

      int insertPosition = helper_updateRtTable_findInsertPosition(nonMatching,
          localIdb!.nodeid.hashID); //passing the local nodeID hashID
      int mid = nonMatching.length ~/ 2;
      // ~/ : integer division
      // / : floating point division
      int finalMid = insertPosition + mid;
      if (finalMid >= nonMatching.length) {
        finalMid %=
            nonMatching.length; // wrap around if finalMid exceeds length
      }

      // Check if the column is null in the local routing table
      if (RoutingTable[0][i] == null) {
        // Pre --> Succ --> Middle
        // Element just before the insert position is the PREDECESSOR of the target NodeID.
        // Element at the insert position is the SUCCESSOR of the target NodeID.
        RoutingTable[0][i] = nonMatching[insertPosition - 1];
        RoutingTable[1][i] = nonMatching[insertPosition];
        RoutingTable[2][i] = nonMatching[finalMid];
      } else {
        // If the column is not null, we need to compare the distance
        if (calculateDistanceHopbyHashId(nonMatching[insertPosition - 1].hashID,
            localIdb!.nodeid.hashID) <
            calculateDistanceHopbyHashId(
                RoutingTable[0][i]!.hashID, localIdb!.nodeid.hashID)) {
          // If the distance of the new node is less than the existing node, replace it
          RoutingTable[0][i] = nonMatching[insertPosition - 1];
        }
        if (calculateDistanceHopbyHashId(
            nonMatching[insertPosition].hashID, localIdb!.nodeid.hashID) <
            calculateDistanceHopbyHashId(
                RoutingTable[1][i]!.hashID, localIdb!.nodeid.hashID)) {
          // If the distance of the new node is less than the existing node, replace it
          RoutingTable[1][i] = nonMatching[insertPosition];
        }
        if (calculateDistanceHopbyHashId(
            nonMatching[finalMid].hashID, localIdb!.nodeid.hashID) <
            calculateDistanceHopbyHashId(
                RoutingTable[2][i]!.hashID, localIdb!.nodeid.hashID)) {
          // If the distance of the new node is less than the existing node, replace it
          RoutingTable[2][i] = nonMatching[finalMid];
        }
      }
    }
  }


  /// Helper function to find the insert position for a target NodeID in a sorted list of NodeIDs.
  /// Element just before the insert position is the PREDECESSOR of the target NodeID.
  /// Element at the insert position is the SUCCESSOR of the target NodeID.
  int helper_updateRtTable_findInsertPosition(List<NodeID> nonMatching,
      String targetHex) {
    BigInt target = BigInt.parse(targetHex, radix: 16);
    int low = 0;
    int high = nonMatching.length;

    while (low < high) {
      int mid = low + ((high - low) >> 1);
      BigInt midValue = BigInt.parse(nonMatching[mid].hashID, radix: 16);

      if (midValue.compareTo(target) < 0) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  /// Helper function to split the mainList into two lists based on a prefix.
  List<List<NodeID>> helper_updateRtTable(List<NodeID> mainList, String pf) {
    List<List<NodeID>> result = [];
    List<NodeID> matching = [];
    // List<String> matching = [];
    List<NodeID> nonMatching = [];

    for (var str in mainList) {
      if (str.hashID.startsWith(pf)) {
        matching.add(str);
      } else {
        nonMatching.add(str);
      }
    }
    result.add(matching);
    result.add(nonMatching);
    return result;
  }

  /// Moves [node] to on-hold after it fails to respond, removing it from [localRTtable].
  ///
  /// PutonHold function is called when a node in RT does not respond to a ping test(which is periodic in our app) then node has to be moved into onHold Map. After this the node is also removed from RT.Counter key with data type integer is also created to track the number of attempts made to reach node.If node is un-responsive even after three attempts then node is  purged from on hold Map.
  // void putOnHold(NodeID node, List<List<NodeID?>> localRTtable) {
  //   // String nodeID=node["nodeID"];
  //   if (onHoldNodes != null && onHoldNodes!.containsKey(node)) {
  //     if (onHoldNodes![node]! >= 2) {
  //       onHoldNodes!.remove(node); // purge the NodeId after 3 attempts
  //     } else {
  //         // onHoldNodes![node]! + 1; // it doesnt increment the attempts counter.
  //         onHoldNodes![node] = onHoldNodes![node]! + 1; // increment the attempts
  //         // if (mRtt.containsKey(nodeID)) {
  //         //     mRtt.remove(nodeID);//removing the rtt of node from mrtt map
  //         // }
  //     }
  //   } else {
  //     onHoldNodes![node] = 1;
  //     List<String> nodeIdC = node.hashID.split('');
  //     String? localnodeId = localIdb!.nodeid.hashID;
  //     List<String> localnodeIdC = localnodeId.split('');
  //     for (int i = 0; i < 40; i++) {
  //       if (nodeIdC[i] != localnodeIdC[i]) {
  //         for (int k = 0; k < 3; k++) {
  //           if (localRTtable[k][i] == node) {
  //             if (k == 0) {
  //               localRTtable[k][i] = localRTtable[1][i]; //cyclically copies the previous node, where node id needs to be removed.
  //             }
  //             if (k == 1) {
  //               localRTtable[k][i] = localRTtable[2][i];
  //             }
  //             if (k == 2) {
  //               localRTtable[k][i] = localRTtable[1][i];
  //             }
  //           }
  //         }
  //         i = 40;
  //       }
  //     }
  //     // for (int i = 0; i < 40; i++) {
  //     //   if (nodeIdC[i] != localnodeIdC[i]) {
  //     //     for (int k = 0; k < 3; k++) {
  //     //       if (localRTtable[k][i] == node) {
  //     //         localRTtable[k][i] = null; // remove the node
  //     //       }
  //     //     }
  //     //     i = 40; // exit after the first mismatch
  //     //   }
  //     // }
  //   }
  // }

  // void putOnHold(NodeID node, List<List<NodeID?>> localRTtable) {  : previous signature
  /*
   Currently the onHoldNodes is a map present inside the b4RoutingTable object and this object gets destroyed after object use. But we need to store this map inside the users hard-disk. therefore we need to add:
    - a file to store onHoldNodes
    - its path :. we need to modify the read write (Logic is correct)
    - file path of the Peer's LocalRoutingTable. Assign the Peer's LocalRT to the b4RoutingTable object (created for the peer) to perform the operation.
    - similarly do the same for onHoldNodes.
  
  Similarly FIX: updateRtTable function and nextHop function.
  */

  /// Moves [node] to on-hold after it fails to respond, removing it from Local [RoutingTable].
  ///
  /// When a node in the routing table fails to respond to a ping test:
  /// 1. The node is moved to the onHold map with an attempt counter
  /// 2. The node is removed from the routing table
  /// 3. If the node remains unresponsive after 3 attempts (counter >= 2), it's purged
  /// 4. The routing table entry is replaced with a backup node when available
  void putOnHold(NodeID node) {
    // Handle existing on-hold nodes
    if (onHoldNodes != null) {
      if (onHoldNodes!.containsKey(node)) {
        if (onHoldNodes![node]! >= 2) {
          onHoldNodes!.remove(node); // Purge after 3 attempts
        } else {
          onHoldNodes![node] =
              onHoldNodes![node]! + 1; // Increment attempt counter
        }
        return; // Early return for existing on-hold nodes
      }
    }

    // New on-hold node processing
    onHoldNodes![node] = 1; // Initialize attempt counter

    // Remove node from routing table with backup node replacement
    List<String> nodeIdChars = node.hashID.split('');
    List<String> localNodeIdChars = localIdb!.nodeid.hashID.split('');

    // Find the first differing digit between the nodes
    for (int i = 0; i < 40; i++) {
      if (nodeIdChars[i] != localNodeIdChars[i]) {
        // Replace the node in all three positions of the bucket
        for (int k = 0; k < 3; k++) {
          if (RoutingTable[k][i] == node) {
            //check if the node to be removed (to be put in onHoldNodes) is present in the routing table or not.
            // Replace with next available backup node
            //Standard/Procedure: cyclically copies the previous [PREDECESSOR] node, where node id needs to be removed.
            RoutingTable[k][i] = _getReplacementNode(node, k, i);
          }
        }
        break; // Only process first differing digit
      }
    }
  }

  /// Helper function to get a replacement node from the routing table
  ///
  /// Standard/Procedure: cyclically copies the previous [PREDECESSOR NODE] node, where node id needs to be removed.
  /// Priority: For row [k], checks deeper rows (k+1, k+2) for replacements. Returns null if no backups available
  /// First checks if the backup node available in the next row (is DIFFERENT from the current node): if yes then returns the backup node,
  /// else: check the next Backup node : check if different (if YES: return the backup one) (else: make all three nodes NULL)
  /// K: ROW
  /// I: COLUMN
  NodeID? _getReplacementNode(
      // NodeID node, List<List<NodeID?>> rt, int k, int i) {
      NodeID node,
      int k,
      int i) {
    // Try to get a replacement from deeper levels
    if (k == 0) {
      if (RoutingTable[1][i] != node && RoutingTable[1][i] != null)
        return RoutingTable[1][i];
      else if (RoutingTable[2][i] != node && RoutingTable[2][i] != null)
        return RoutingTable[2][i];
      else
        return null;
    }
    if (k == 1) {
      if (RoutingTable[2][i] != node && RoutingTable[2][i] != null)
        return RoutingTable[2][i];
      else if (RoutingTable[1][i] != node && RoutingTable[1][i] != null)
        return RoutingTable[1][i];
      else
        return null;
    }
    if (k == 2) {
      if (RoutingTable[0][i] != node && RoutingTable[0][i] != null)
        return RoutingTable[0][i];
      else if (RoutingTable[1][i] != node && RoutingTable[1][i] != null)
        return RoutingTable[1][i];
      else
        return null;
    }

    return null;
  }

  //defined to access the private method _getReplacementNode for testing purposes.
  NodeID? getReplacementNodeForTest(NodeID node, int k, int i) {
    return _getReplacementNode(node, k, i);
  }

  /// Calculates the distance between hexadecimal [HASHIDs: hashId] for routing decisions.
  ///
  /// This function will be used to calculate distance in nextHop function.
  /// It receives COMPLETE HASHIDs and calculates distance between the two.
  /// a ^ b == b ^ a : XOR operation is commutative.
  /// Is distance(a, d) equal to distance(d, g)? : No, not necessarily.
  int calculateDistanceHopbyHashId(String nodeId, String proxyNodeId) {
    // Convert hex node IDs to BigInt for comparison
    BigInt nodeBigInt =
    BigInt.parse(nodeId, radix: 16); //int to BigInt conversion: Base 16
    BigInt proxyBigInt = BigInt.parse(proxyNodeId, radix: 16);
    int dist = (nodeBigInt ^ proxyBigInt)
        .toInt(); //bitwise XOR : ^ — used for XOR distances for DHTs.
    return dist; // XOR and convert to integer distance
  }

  /// Calculates the distance between hexadecimal nibbles for routing decisions.
  ///
  /// This function will be used to calculate distance in nextHop function.
  /// It receives nodeID nibble and HashID nibble and calculates distance between the two.
  int calculateDistanceHopbyNibble(String nodeID, String hashId) {
    int nodeIdInt = int.parse(nodeID,
        radix: 16); // converts each hex string to its integer (decimal) value.
    int hashIdInt = int.parse(hashId, radix: 16);

    int clockwise = (nodeIdInt - hashIdInt + 16) % 16;
    int counterClockwise = (hashIdInt - nodeIdInt + 16) % 16;

    return min(
        clockwise, counterClockwise); // shortest distance in either direction
  }

  /// Helper function to determine the next hop within a given RT Table Column (based on the given HashID).
  String helperNextHop(int hopPos, String HashID,
      List<List<NodeID?>> localRTtable) {
    List<int> dis = [0, 0, 0]; // distance from pre,suc,mid nodeID from hashID.
    dis[0] =
        calculateDistanceHopbyHashId(HashID, localRTtable[0][hopPos]!.hashID);
    dis[1] =
        calculateDistanceHopbyHashId(HashID, localRTtable[1][hopPos]!.hashID);
    dis[2] = calculateDistanceHopbyHashId(
        HashID, localRTtable[2][hopPos]!.hashID); // distance
    int mini = dis[0];
    mini = min(
        dis[0],
        min(dis[1],
            dis[2])); // minimum distance from pre,suc,mid nodeID from hashID.
    switch (dis.indexOf(mini)) {
      case 0:
        return localRTtable[0][hopPos]!.hashID; // pre nodeID
      case 1:
        return localRTtable[1][hopPos]!.hashID; // mid nodeID
      case 2:
        return localRTtable[2][hopPos]!.hashID; // suc nodeID
    }
    return "";
  }

  /// Determines the next hop destination for [hashID] based on [localRTtable].
  ///
  /// nextHop function receives a node ID (HashID) and local RT and then returns the next hop destination(nodeID) based on node entries in local RT.
  ///
  //String nextHop(String hashID, List<List<NodeID?>> localRTtable, {required bool useDHT}) {
  String nextHop(String hashID, List<List<NodeID?>> localRTtable) {
    // if hashID matches with local nodeID then return local nodeID as root nodeID.Otherwise proceed to else condition of the code.
    if (localIdb!.nodeid.hashID == hashID) {
      return localIdb!.nodeid.hashID; // current node is the Destination node
    }

    List<String> hashIdC = hashID.split('');
    String localNodeId = localIdb!.nodeid.hashID;
    List<String> localNodeIdC = localNodeId.split('');
    List<int>? distanceHashId = [
      0,
      0,
      0
    ]; //It is array of distance,it stores distance from pre,succ,mid nodeID from hashID.
    int distanceLocalID; // It distance between localNodeID to HashID.
    // initialising variables.
    int misMatch =
    -1; //It will store first mis-match index.It will bes used later in code to find pre,mid and succ node at index fi first mis-match.

    for (int i = 0; i < 40; i++) {
      if (hashIdC[i] != localNodeIdC[i]) {
        misMatch = i;
        // This part of code runs only when, the column in localRTtable is null at mismatch index.
        if (localRTtable[0][misMatch] == null) {
          //if any of the cell in the column is null => all three cells in the column are null.

          // This part of code is used to find the nearest node in the column by moving left and right from the mismatch index.
          // we move both left and right from the mismatch index to find the nearest non-null node.
          // We prefer to move left first, then right. Reason: Upper Layers are populated first, so more chance of finding a route to the final destination.

          //moving left
          int leftHops = 0; // counter for left hops
          int tempMisMatch = misMatch - 1; // temporary variable
          while (tempMisMatch >= 0) {
            leftHops++;
            if (localRTtable[0][tempMisMatch] != null) {
              break; // If we find a non-null node, we break out of the loop.
            }
            tempMisMatch--;
          }
          if (tempMisMatch < 0) {
            leftHops =
            -1; // If we reach the start of the column without finding a non-null node, we set leftHops to -1.
            // This indicates that there is no node to the left of the mismatch index.
          }

          //moving right
          int rightHops = 0; // counter for right hops
          tempMisMatch = misMatch +
              1; // reset temporary variable //intentially +1 : what if misMatch is at the end of the column? 39
          while (tempMisMatch < 40) {
            rightHops++;
            if (localRTtable[0][tempMisMatch] != null) {
              break; // If we find a non-null node, we break out of the loop.
            }
            tempMisMatch++;
          }
          if (tempMisMatch >= 40) {
            rightHops =
            -1; // If we reach the end of the column without finding a non-null node, we set rightHops to -1.
          }

          if (leftHops == -1 && rightHops == -1) {
            return localNodeId; // If both left and right hops are -1, return local node ID ie. complete RT is empty.
          } else if (rightHops == -1 || leftHops <= rightHops) {
            // If right hops is -1, we only have left hops.
            return helperNextHop(misMatch - leftHops, hashID, localRTtable);
          } else {
            return helperNextHop(misMatch + rightHops, hashID, localRTtable);
          }
        }
        break;
      }
    }

    String preNodeId = localRTtable[0][misMatch]!.hashID;
    String sucNodeId = localRTtable[1][misMatch]!.hashID;
    String midNodeId = localRTtable[2][misMatch]!.hashID;

    List<String>? preNodeIdC = preNodeId.split('');
    List<String>? sucNodeIdC = sucNodeId.split('');
    List<String>? midNodeIdC = midNodeId.split('');

    distanceHashId[0] =
        calculateDistanceHopbyNibble(preNodeIdC[misMatch], hashIdC[misMatch]);
    distanceHashId[1] =
        calculateDistanceHopbyNibble(sucNodeIdC[misMatch], hashIdC[misMatch]);
    distanceHashId[2] =
        calculateDistanceHopbyNibble(midNodeIdC[misMatch], hashIdC[misMatch]);
    distanceLocalID =
        calculateDistanceHopbyNibble(localNodeIdC[misMatch], hashIdC[misMatch]);

    int minValue = distanceHashId.reduce((min, current) =>
    current < min
        ? current
        : min); //iterates through the list and keeps the smallest value found.

    if (distanceLocalID < minValue) {
      return localNodeId; // If local node is closer than any of the pre,mid,suc node then return local nodeID.
    } else {
      switch (distanceHashId.indexOf(minValue)) {
        case 0:
          return preNodeId;
        case 1:
          return sucNodeId;
        case 2:
          return midNodeId;
        default:
          return localNodeId;
      }
    }
  }
  /// find node hash from given local routing table
  Node? findNode(String requiredhashId, List<List<Node?>> localRTtable) {
    for (var row in localRTtable) {
      for (Node? node in row) {
        if (node!.nodeID.hashID == requiredhashId) {
          return node;
        }
      }
    }
    return null;
  }



Future<NodeID?> findNodeByHash(String filePath, String targetHashID) async {
  try {
    final file = File(filePath);

    if (!await file.exists()) {
      print("File not found at: $filePath");
      return null;
    }

    final jsonString = await file.readAsString();
    final List<dynamic> jsonData = jsonDecode(jsonString);

    for (final item in jsonData) {
      if (item['hashID'] == targetHashID) {
        return NodeID.createFromTable(
          item['publicKeyPem'] ?? '',
          ECSignature(BigInt.zero, BigInt.zero),
          item['hashID'] ?? '',
          item['publicKey'] ?? '',
          item['localIpv4'] ?? '',
          item['publicIpv4'] ?? '',
          item['publicIpv6'] ?? '',
          int.tryParse(item['natStatus'].toString()) ?? 0,
          int.tryParse(item['localIpv4Port'].toString()) ?? 0,
          int.tryParse(item['publicIpv4Port'].toString()) ?? 0,
          int.tryParse(item['publicIpv6Port'].toString()) ?? 0,
          item['communicatorIP'] ?? '',
          int.tryParse(item['communicatorPort'].toString()) ?? 0,
          int.tryParse(item['listeningPort'].toString()) ?? 22800,
        );
      }
    }

    print("Node with hashID $targetHashID not found.");
    return null;
  } catch (e) {
    print("Error reading or parsing JSON: $e");
    return null;
  }
}

}//end of the class

  // /// Not Used Now...This function was made first to update object of NodeID for simplified implementation and testing.
  // ///
  // /// Called once in routingmanager.dart.
  // ///
  // /// It was later modified to function updateRtTable which is implemented above.It will be removed later. It is currently used to create a routing table initially for testing.
  // ///
  // /// Main Aim: Function to update the nodeID in the routing table. When any new Node Id is received by the node, it is always updated in RT table using this function only.
  // void updateNodeID(NodeID nodeID, Duration rtt, List<List<NodeID?>> localRT) {
  //   //check if node is present in putonHold, if present then remove from there.
  //   if (onHoldNodes != null) {
  //     if (onHoldNodes!.containsKey(nodeID)) {
  //       onHoldNodes!.remove(nodeID);
  //     }
  //   }
  //   mRtt[nodeID.hashID] = rtt;
  //   List<String>? nodeIdC = nodeID.hashID.split('');
  //   String? localNodeId = localIdb!.nodeid.hashID;
  //   List<String> localNodeIdC = localNodeId.split('');
  //   int m = -1;
  //   // initialising variable for index for finding first mis-match....
  //   for (int i = 0; i < 40; i++) {
  //     if (nodeIdC[i] != localNodeIdC[i]) {
  //       m = i;
  //       i = 40; // to exit the loop after getting index of first mismatch
  //     }
  //   }
  //   if (nodeIdC[m] != localNodeIdC[m]) {
  //     if (localRT[0][m] == null &&
  //         localRT[1][m] == null &&
  //         localRT[2][m] == null) {
  //       localRT[2][m] =
  //           nodeID; // If routing table is null in the column then copy the nodeID in all 3 rows of column.
  //       localRT[1][m] = nodeID;
  //       localRT[0][m] = nodeID;
  //     }
  //     // If routing table is not null, then we take node id of pre, succ and mid nodes.Then splitting the string node id into string of characters to compare.
  //     else {
  //       String? preNodeId = localRT[2][m]?.hashID;
  //       String? midNodeId = localRT[1][m]?.hashID;
  //       String? sucNodeId = localRT[0][m]?.hashID;
  //       List<String>? preNodeIdC = preNodeId!.split('');
  //       List<String>? midNodeIdC = midNodeId!.split('');
  //       List<String>? sucNodeIdC = sucNodeId!.split('');
  //       int preNodeIdint = int.parse(preNodeIdC[m],
  //           radix: 16); // coverting hexadecimal value into int for comparison
  //       int midNodeIdint = int.parse(midNodeIdC[m], radix: 16);
  //       int sucNodeIdint = int.parse(sucNodeIdC[m], radix: 16);
  //       int localnodeIdint = int.parse(localNodeIdC[m], radix: 16);
  //       int nodeIdint = int.parse(nodeIdC[m], radix: 16);
  //       int idealMidNodeIdint = (localnodeIdint + 8) % 16;
  //       if (((localnodeIdint - preNodeIdint + 16) % 16) >
  //           ((nodeIdint - preNodeIdint + 16) % 16)) {
  //         if (mRtt.containsKey(localRT[2][m]!.hashID) &&
  //             (localRT[2][m] != localRT[1][m] ||
  //                 localRT[2][m] != localRT[0][m])) {
  //           mRtt.remove(localRT[2][m]!
  //               .hashID); // this is done so that if node ID is not present anywhere in RT then it should also not be present in mRTT table.
  //         }
  //         localRT[2][m] = nodeID; //replacing pre-decessor nodeID
  //       } else if (((sucNodeIdint - localnodeIdint + 16) % 16) >
  //           ((nodeIdint - localnodeIdint + 16) % 16)) {
  //         if (mRtt.containsKey(localRT[0][m]) &&
  //             (localRT[0][m]!.hashID != localRT[1][m]!.hashID ||
  //                 localRT[0][m]!.hashID != localRT[2][m]!.hashID)) {
  //           mRtt.remove(localRT[0][m]);
  //         }
  //         localRT[0][m] = nodeID; //replacing successor node id
  //       } else if (min(((idealMidNodeIdint - midNodeIdint + 16) % 16),
  //               ((midNodeIdint - idealMidNodeIdint + 16) % 16)) >
  //           min(((idealMidNodeIdint - nodeIdint + 16) % 16),
  //               ((nodeIdint - idealMidNodeIdint + 16) % 16))) {
  //         if (mRtt.containsKey(localRT[1][m]!.hashID) &&
  //             (localRT[1][m] != localRT[0][m] ||
  //                 localRT[1][m] != localRT[2][m])) {
  //           mRtt.remove(localRT[1][m]!.hashID);
  //         }
  //         localRT[1][m] = nodeID; // replacing middle node id
  //         //Next 3 conditions are checking rtt if nodeID nibble matches which any of pre,success,mid nodeID.
  //       } else if (nodeIdint == preNodeIdint && mRtt[nodeID]! > rtt) {
  //         if (mRtt.containsKey(localRT[2][m]!.hashID) &&
  //             (localRT[2][m] != localRT[1][m] ||
  //                 localRT[2][m] != localRT[0][m])) {
  //           mRtt.remove(localRT[2][m]!.hashID);
  //         }
  //         localRT[2][m] =
  //             nodeID; // NodeID having less rtt is kept in the routing table.
  //       } else if (nodeIdint == midNodeIdint && mRtt[nodeID]! > rtt) {
  //         if (mRtt.containsKey(localRT[1][m]!.hashID) &&
  //             (localRT[1][m] != localRT[0][m] ||
  //                 localRT[1][m] != localRT[2][m])) {
  //           mRtt.remove(localRT[1][m]!.hashID);
  //         }
  //         localRT[1][m] = nodeID;
  //       } else if (nodeIdint == sucNodeIdint && mRtt[nodeID]! > rtt) {
  //         if (mRtt.containsKey(localRT[0][m]!.hashID) &&
  //             (localRT[0][m] != localRT[1][m] ||
  //                 localRT[0][m] != localRT[2][m])) {
  //           mRtt.remove(localRT[0][m]!.hashID);
  //         }
  //         localRT[0][m] = nodeID;
  //       }
  //     }
  //   } else if (mRtt.containsKey(nodeID)) {
  //     mRtt.remove(nodeID);
  //   }
  // }




  // Future<List<double>?> getLocation() async {
  //   // Request permission to access the device's location
  //   LocationPermission permission = await Geolocator.requestPermission();
  //
  //   if (permission == LocationPermission.denied) {
  //     print('Location permissions are denied.');
  //     return null;
  //   }
  //
  //   if (permission == LocationPermission.deniedForever) {
  //     print('Location permissions are permanently denied, we cannot request permissions.');
  //     return null;
  //   }
  //
  //   // Get the current position (latitude and longitude)
  //   Position position = await Geolocator.getCurrentPosition(
  //       desiredAccuracy: LocationAccuracy.best);
  //
  //   // Output the latitude and longitude
  //   return ['${position.latitude}' as double,'${position.longitude}' as double];
  //  // print('Latitude: ${position.latitude}, Longitude: ${position.longitude}');
  // }




  //this is update id function
  //exactly same as void updateNodeID () fx above... just few modifictaions

  // void updateNodeIDtest(NodeID nodeID, Duration rtt) {
  //
  //   //check if node is present in putonHold, if present them remove from there.
  //
  //   if (onHoldNodes != null) {
  //     if (onHoldNodes!.containsKey(nodeID)) {
  //       onHoldNodes!.remove(nodeID);
  //     }
  //   }
  //   mRtt[nodeID.hashID] = rtt;
  //   List<String>? nodeIdC = nodeID.hashID.split('');
  //   String? localNodeId = localIdb!.nodeid.hashID;
  //   List<String> localNodeIdC = localNodeId.split('');
  //
  //   int m = -1; // initialising variable for index for finding first mis-match....
  //   for (int i = 0; i < 40; i++) {
  //     if (nodeIdC[i] != localNodeIdC[i]) {
  //       m = i;
  //       i = 40; // to exit the loop after getting index of first mismatch
  //     }
  //   }
  //   if (nodeIdC[m] != localNodeIdC[m])
  //   {
  //     //
  //     if (RoutingTable[0][m]==null && RoutingTable[1][m] == null && RoutingTable[2][m] == null)
  //     {
  //       RoutingTable[2][m] = nodeID; // If routing table is null in the column then copy the nodeID in all 3 rows of column.
  //       RoutingTable[1][m] = nodeID;
  //       RoutingTable[0][m] = nodeID;
  //     }
  //     // If routing table is not null, then we take node id of pre, succ and mid nodes.Then splitting the string node id into string of characters to compare.
  //     else
  //     {
  //       String? preNodeId = RoutingTable[2][m]?.hashID;
  //       String? midNodeId = RoutingTable[1][m]?.hashID;
  //       String? sucNodeId = RoutingTable[0][m]?.hashID;
  //
  //       List<String>? preNodeIdC = preNodeId!.split('');
  //       List<String>? midNodeIdC = midNodeId!.split('');
  //       List<String>? sucNodeIdC = sucNodeId!.split('');
  //
  //       int preNodeIdint = int.parse(preNodeIdC[m],radix: 16); // coverting hexadecimal value into int for comparison
  //       int midNodeIdint = int.parse(midNodeIdC[m], radix: 16);
  //       int sucNodeIdint = int.parse(sucNodeIdC[m], radix: 16);
  //       int localnodeIdint = int.parse(localNodeIdC[m], radix: 16);
  //       int nodeIdint = int.parse(nodeIdC[m], radix: 16);
  //       int idealMidNodeIdint = (localnodeIdint + 8)%16;
  //
  //       if (((localnodeIdint - preNodeIdint + 16) % 16) > ((nodeIdint - preNodeIdint + 16) % 16))
  //       {
  //
  //         if (mRtt.containsKey(RoutingTable[2][m]!.hashID) && (RoutingTable[2][m] != RoutingTable[1][m] || RoutingTable[2][m] != RoutingTable[0][m]))
  //         {
  //           mRtt.remove(RoutingTable[2][m]!.hashID); // this is done so that if node ID is not present anywhere in RT then it should also not be present in mRTT table.
  //         }
  //         RoutingTable[2][m] = nodeID; //replacing pre-decessor nodeID
  //
  //
  //       }
  //       else if (((sucNodeIdint - localnodeIdint + 16) % 16) >((nodeIdint - localnodeIdint + 16) % 16))
  //       {
  //
  //         if (mRtt.containsKey(RoutingTable[0][m]) && (RoutingTable[0][m]!.hashID != RoutingTable[1][m]!.hashID || RoutingTable[0][m]!.hashID != RoutingTable[2][m]!.hashID))
  //         {
  //           mRtt.remove(RoutingTable[0][m]);
  //         }
  //
  //         RoutingTable[0][m] = nodeID; //replacing successor node id
  //
  //
  //       } else if (min(((idealMidNodeIdint - midNodeIdint + 16) % 16),((midNodeIdint - idealMidNodeIdint + 16) % 16)) > min(((idealMidNodeIdint - nodeIdint + 16) % 16),((nodeIdint - idealMidNodeIdint + 16) % 16)))
  //       {
  //         if (mRtt.containsKey(RoutingTable[1][m]!.hashID) &&  (RoutingTable[1][m] != RoutingTable[0][m] || RoutingTable[1][m] != RoutingTable[2][m]))
  //         {
  //           mRtt.remove(RoutingTable[1][m]!.hashID);
  //         }
  //
  //
  //         RoutingTable[1][m] = nodeID; // replacing middle node id
  //
  //       } else if (nodeIdint == preNodeIdint && mRtt[nodeID]! > rtt)
  //       {
  //         if (mRtt.containsKey(RoutingTable[2][m]!.hashID) && (RoutingTable[2][m] != RoutingTable[1][m] || RoutingTable[2][m] != RoutingTable[0][m]))
  //         {
  //           mRtt.remove(RoutingTable[2][m]!.hashID);
  //         }
  //
  //
  //         //Next 3 conditions are checking rtt if nodeID nibble matches which any of pre,success,mid nodeID.
  //
  //
  //         RoutingTable[2][m] = nodeID; // NodeID having less rtt is kept in the routing table.
  //
  //       } else if (nodeIdint == midNodeIdint && mRtt[nodeID]! > rtt)
  //       {
  //
  //         if (mRtt.containsKey(RoutingTable[1][m]!.hashID) && (RoutingTable[1][m] != RoutingTable[0][m] || RoutingTable[1][m] != RoutingTable[2][m]))
  //         {
  //           mRtt.remove(RoutingTable[1][m]!.hashID);
  //         }
  //         RoutingTable[1][m] = nodeID;
  //       } else if (nodeIdint == sucNodeIdint && mRtt[nodeID]! > rtt)
  //       {
  //
  //         if (mRtt.containsKey(RoutingTable[0][m]!.hashID) && (RoutingTable[0][m] != RoutingTable[1][m] || RoutingTable[0][m] != RoutingTable[2][m]))
  //         {
  //           mRtt.remove(RoutingTable[0][m]!.hashID);
  //         }
  //         RoutingTable[0][m] = nodeID;
  //       }
  //     }
  //   }
  //   else if (mRtt.containsKey(nodeID)) {
  //     mRtt.remove(nodeID);
  //   }
  // }




  // long lat based neighbour table is to be maintained. 16 nodes to be maintained based on shortest distance based on long
  // lat from the current node.
  // layering in RT table...

  // Future<void> latlongTable(Map<NodeID, List<String>>? latLongNode) async {
  //   Distance distance = const Distance();
  //   List<double>? coordinates = await getLocation();
  //
  //
  //   for (var entry_1 in latLongNode!.entries) {
  //     double lat = double.parse(entry_1.value[0]);
  //     double long = double.parse(entry_1.value[1]);
  //     final double meterDistance1 = distance.as(
  //         LengthUnit.Meter, LatLng(lat, long),
  //         LatLng(coordinates![0], coordinates[1]));
  //
  //     for (var entry_2 in latLongLocal!.entries) {
  //       double latNodeList = double.parse(entry_2.value[0]);
  //       double longLongList = double.parse(entry_2.value[1]);
  //       final double meterDistance2 = distance.as(
  //           LengthUnit.Meter, LatLng(latNodeList, longLongList),
  //           LatLng(coordinates[0], coordinates[1]));
  //
  //       if (meterDistance1 < meterDistance2) {
  //         latLongLocal!.remove(entry_2);
  //         latLongLocal![entry_1.key] = latLongNode[entry_1.key]!;
  //       }
  //     }
  //   }
  // }
