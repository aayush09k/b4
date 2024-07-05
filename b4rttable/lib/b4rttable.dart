// Written by Sqn Ldr Aman Sharma & Sqn Ldr Tarun Chaudhary...

library b4rttable;


import 'dart:math';
//import 'package:latlong2/latlong.dart';
import 'package:nodeid/nodeid.dart';
//import 'package:geolocator/geolocator.dart';


class B4RoutingTable {
  Map<NodeID, int>? onHoldNodes; //NodeId & attemptsCounter
  Map<String, Duration> mRtt = {};
  String? LayerID;
  LocalNodeID? localIdb;
  List<List<NodeID?>> RoutingTable = List.generate( 3, (_) => List.filled(40, null)); // To be removed later.
  List<NodeID?> neibhourTable = List.generate(16, (index) => null);
  List<NodeID?> latLongTable = List.generate(16, (index) => null);
  Map<NodeID, List<String>>? latLongLocal;
  List<double>? coords = [0.0, 0.0]; //  initialising the co-ordinates

  B4RoutingTable(LocalNodeID localId) {
    onHoldNodes =
    {
    }; 
	// It is a map which hold nodes which are present in local RT but does not respond to ping test. An unresponsive Node is removed from local RT table and
    // added to the map. If they do not respond to ping test 3 times then,
    // they are removed from the onHoldNodes map as well. If they respond to 1st or 2nd ping then they are removed from map and updated into local RT .
    localIdb = localId;
    localIdb!.nodeid.hashID="62D67DFC3E4616381DACA70A90CDF3C59EA80D32";
  }

  // Function to update the nodeID in the routing table. When any new Node Id is received by the node, it is always updated
  // in RT table using this function only.

  // long lat based neighbour table is to be maintained. 16 nodes to be maintained based on shortest distance based on long
  // lat from the current node.
  // Each layer will have its own RT. To identify the layer, LayerID is used.

  // This function receives local Routing table, and Routing table of other node and rtt . It checks for each node ID in RT and update it's own local Routing table,
  // based on the routing algorithm (chord-tapestry).
  
  void updateRtTable(List<List<NodeID?>> localRTtable, List<List<NodeID?>> rtTable) {
    RoutingTable = localRTtable;
    // this is the loop to check for each node in rtTable and compare with node already present in it's localRTtable.
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 40; col++) {
        if (rtTable[row][col] != null && rtTable[row][col]!.hashID != localIdb!.nodeid.hashID) {
          //check if node is present in putonHold, if present them remove from there.
          if (onHoldNodes != null) {
            if (onHoldNodes!.containsKey(rtTable[row][col])) {
              onHoldNodes!.remove(rtTable[row][col]);
            }
          }
          //String node= rtTable[row][col]!["nodeId"];
          // rtt is stored in map with nodeID as key.
          // The node ID received from rt Table is splitted and stored as List in variable nodeIdC,
          // so to enable us to carry out nibble wise comparison.This results in faster computation.
          //  mRtt[rtTable[row][col]!.hashID] = rtt;

          List<String> nodeIdC = rtTable[row][col]!.hashID.split('');

          List<String>? localNodeIdC = localIdb?.nodeid.hashID.split('');

          int m = -1; // initialising variable for index for finding first mis-match....
          for (int i = 0; i < 40; i++) {
            if (nodeIdC[i] != localNodeIdC![i]) {
              m = i;
              i = 40; // to exit the loop after getting index of first mismatch
            }
          }
          if (nodeIdC[m] != localNodeIdC![m]) {
            // If routing table is null in the column then copy the nodeID in all 3 rows of column.In our algorithm no column can pe partially empty,
            // Hence, we copy nodeID in all three index in a column at first mismatch we have obtained from above logic(line 51-57).
            if (RoutingTable[0][m] == null && RoutingTable[1][m] == null && RoutingTable[2][m] == null) {
              RoutingTable[2][m] = rtTable[row][col];
              RoutingTable[1][m] = rtTable[row][col];
              RoutingTable[0][m] = rtTable[row][col];
            }
            // If routing table is not null, then we take nodeIds of pre-decessor, successor and mid nodes.
            // Then splitting the string node id into string of characters to compare.
            else {
              String? preNodeId = RoutingTable[2][m]!.hashID; // Extracting  pre-decessor node ID from map using key nodeID.
              String? midNodeId = RoutingTable[1][m]!.hashID; //Extracing mid nodeID from map using key nodeID.
              String? sucNodeId = RoutingTable[0][m]!.hashID; // Extracting successor nodeID from map using key nodeID.

              List<String>? preNodeIdC = preNodeId.split('');
              List<String>? midNodeIdC = midNodeId.split('');
              List<String>? sucNodeIdC = sucNodeId.split('');

              // Converting hexadecimal value into int for comparison. Our NodeID is hexadecimal, hence we are converting nibble(first mismatch nibble)
              // of data-type String into  data-type Integer(hexadecimal to decimal conversion).
              int preNodeIdint = int.parse(preNodeIdC[m], radix: 16);
              int midNodeIdint = int.parse(midNodeIdC[m], radix: 16);
              int sucNodeIdint = int.parse(sucNodeIdC[m], radix: 16);
              int localnodeIdint = int.parse(localNodeIdC[m], radix: 16);
              int nodeIdint = int.parse(nodeIdC[m], radix: 16);

              // This is the integer value of ideal mid distance from localnodeID. It will be used in later part of code to update mid nodeID
              // of the routing table.NodeIDs are arranged in circular fashionIt is circular hence modulo operation is done.
              int idealMidNodeIdint = (localnodeIdint + 8) % 16;

              // This part of code(06 if-elseif conditions) deals with various scenarios where we calculate distance between pre-nodeID,suc-nodeID,mid-nodeID.

              //First condition calculates distance between prenodeID to localnodeID and  prenodeID   to nodeID   is calculated.
              // NodeIDs are arranged circularly hence using modulo operations.If distance between localnodeID  to  prenodeID is >
              // nodeID  to prenodeID ,then nodeID is updated in the local routing table at the relevant index. Since, all distances of 40 bit hexadecimal
              // nodeID is calculated on basis of only single hexadecimal bit, it makes the routing system highly efficient and fast.
              if (((localnodeIdint - preNodeIdint + 16) % 16) >
                  ((nodeIdint - preNodeIdint + 16) % 16)) {
                //In this condition, we check if nodeID is being removed from table from all possible locations then we also remove the node from rtt map,
                // this is done on order prevent overflow of the Map mrtt.
                if (mRtt.containsKey(RoutingTable[2][m]) && (RoutingTable[2][m] != RoutingTable[1][m] || RoutingTable[2][m] != RoutingTable[0][m])) {
                  mRtt.remove(RoutingTable[2][m]);
                }
                RoutingTable[2][m] =
                rtTable[row][col]; //replacing pre-decessor nodeID
              }
              // Second condition calculates distance between successor nodeID to localNodeID and localNodeID to nodeID. If former distance is greater than latter,
              // then nodeID is updated as successor in the routing table. Similar operation to Map mrtt as above has been carried out.
              else if (((sucNodeIdint - localnodeIdint + 16) % 16) > ((nodeIdint - localnodeIdint + 16) % 16)) {
                if (mRtt.containsKey(RoutingTable[0][m]) &&
                    (RoutingTable[0][m] != RoutingTable[1][m] ||
                        RoutingTable[0][m] != RoutingTable[2][m])) {
                  mRtt.remove(RoutingTable[0][m]);
                }

                RoutingTable[0][m] = rtTable[row][col]; //replacing successor node
                //return localRTtable;

                // Since NodeIds are arranged circularly, for mid distance we take minimum ditance from either side.If minimum distance between idealMidNodeIdint
                // and midNodeIdint  is  greater than minimum distance between idealMidNodeIdint and nodeIdint. Then nodeID is updated in mid position of the column in RT.
              } else if (min(((idealMidNodeIdint - midNodeIdint + 16) % 16),
                  ((midNodeIdint - idealMidNodeIdint + 16) % 16)) >
                  min(((idealMidNodeIdint - nodeIdint + 16) % 16),
                      ((nodeIdint - idealMidNodeIdint + 16) % 16))) {
                // if (mRtt.containsKey(RoutingTable[1][m]) &&  (RoutingTable[1][m] != RoutingTable[0][m] || RoutingTable[1][m] != RoutingTable[2][m]))
                // {
                //     mRtt.remove(RoutingTable[1][m]);
                // }

                RoutingTable[1][m] = rtTable[row][col]; // replacing middle node id
              }
            }
          }
        }
      }
    }
  }

  // PutonHold function is called when a node in RT does not respond to a ping test(which is periodic in our app) then node has to be moved into onHold Map. After this the node is also removed from RT.
  // This function receives two arguments first node that needs to be put on hold and second argument is local RT. It will add the node in onHold map and
  //remove the node from local RT.Counter key with data type integer is also created to track the number of attempts made to reach node.If node is un-responsive even after
  // three attempts then node is  purged from on hold Map.

  void putOnHold(NodeID node, List<List<NodeID?>> localRTtable) {
    {
      // String nodeID=node["nodeID"];
      if (onHoldNodes != null && onHoldNodes!.containsKey(node)) {
        if (onHoldNodes![node]! >= 2) {
          // If node is non-responsive for 3 attempts.
          onHoldNodes!.remove(node); // purge the NodeId
        } else {
          onHoldNodes![node]! + 1; // increments the attempts counter.
          // if (mRtt.containsKey(nodeID)) {
          //     mRtt.remove(nodeID);//removing the rtt of node from mrtt map
          // }
        }
      } else {
        onHoldNodes![node] = 1; //if node is not present in the
        List<String> nodeIdC = node.hashID.split('');
        String? localnodeId = localIdb!.nodeid.hashID;
        List<String> localnodeIdC = localnodeId.split('');
        for (int i = 0; i < 40; i++) {
          if (nodeIdC[i] != localnodeIdC[i]) {
            for (int k = 0; k < 3; k++) {
              if (localRTtable[k][i] == node) {
                if (k == 0) {
                  localRTtable[k][i] = localRTtable[1][
                  i]; //cyclically copies the previous node, where node id needs to be removed.
                }
                if (k == 1) {
                  localRTtable[k][i] = localRTtable[2][i];
                }
                if (k == 2) {
                  localRTtable[k][i] = localRTtable[1][i];
                }
              }
            }
            i = 40;
          }
        }
      }
    }
  }

  // This function will be used to calculate distance in nextHop function.It receives nodeID nibble and HashID nibble and calculates distance between the two.
  int calculateDistanceHop(String nodeID, String hashId) {
    int nodeIDint = int.parse(nodeID, radix: 16);
    int hashIdint = int.parse(hashId, radix: 16);

    int distance = (nodeIDint - hashIdint + 16) % 16;
    return distance;
  }

// nextHop function receives a node map and local RT and then  returns the next hop destination(nodeID) based on node entries in local RT.

  String nextHop(String hashID, List<List<NodeID?>> localRTtable) {
    // if hashID matches with local nodeID then return local nodeID as root nodeID.Otherwise proceed to else condition of the code.
    if (localIdb!.nodeid.hashID == hashID) {
      return localIdb!.nodeid.hashID; // current node is the root node
    } else {
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
      int l = -1,
          i = -1; // loop variables are initialised.

      for (i = 0; i < 40; i++) {
        // This part of code runs only when,
        if (hashIdC[i] != localNodeIdC[i]) {
          misMatch = i;
          if (localRTtable[0][i] == null) {
            for (l = i; l < 40; l++) {
              if (localRTtable[0][l] == null || hashIdC[l] == localNodeIdC[l]) {
                misMatch++;
                if (misMatch == 40) {
                  return localNodeId;
                }
              } else {
                l = 40;
              }
            }
          }
          i = 40;
        }
      }

      String? preNodeId = localRTtable[2][misMatch]!.hashID;
      String? midNodeId = localRTtable[1][misMatch]!.hashID;
      String? sucNodeId = localRTtable[0][misMatch]!.hashID;

      List<String>? preNodeIdC = preNodeId.split('');
      List<String>? midNodeIdC = midNodeId.split('');
      List<String>? sucNodeIdC = sucNodeId.split('');

      distanceHashId[0] =
          calculateDistanceHop(preNodeIdC[misMatch], hashIdC[misMatch]);
      distanceHashId[1] =
          calculateDistanceHop(midNodeIdC[misMatch], hashIdC[misMatch]);
      distanceHashId[2] =
          calculateDistanceHop(sucNodeIdC[misMatch], hashIdC[misMatch]);
      distanceLocalID =
          calculateDistanceHop(localNodeIdC[misMatch], hashIdC[misMatch]);

      int minValue = distanceHashId
          .reduce((min, current) => current < min ? current : min);

      if (distanceHashId.indexOf(minValue) < distanceLocalID) {
        if (distanceHashId.indexOf(minValue) == 0) {
          return preNodeId;
        }

        if (distanceHashId.indexOf(minValue) == 1) {
          return midNodeId;
        } else {
          return sucNodeId;
        }
      } else {
        return localNodeId;
      }
    }
  }


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


  void updateNeighbourTable(Map<NodeID, Duration> neighbourTable) {

  }


///
/// This function was made first to update object of NodeID for simplified implementation and testing.
    /// It was later modified to function updateRtTable which is implemented above.It will be removed later.
    void updateNodeID(NodeID nodeID, Duration rtt,List<List<NodeID?>> localRT) {

        //check if node is present in putonHold, if present them remove from there.

        if (onHoldNodes != null) {
            if (onHoldNodes!.containsKey(nodeID)) {
                onHoldNodes!.remove(nodeID);
            }
        }
        mRtt[nodeID.hashID] = rtt;
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
        if (nodeIdC[m] != localNodeIdC[m])
        {
            //
            if (localRT[0][m]==null && localRT[1][m] == null && localRT[2][m] == null)
            {
              localRT[2][m] = nodeID; // If routing table is null in the column then copy the nodeID in all 3 rows of column.
              localRT[1][m] = nodeID;
              localRT[0][m] = nodeID;
            }
            // If routing table is not null, then we take node id of pre, succ and mid nodes.Then splitting the string node id into string of characters to compare.
            else
            {
                String? preNodeId = localRT[2][m]?.hashID;
                String? midNodeId = localRT[1][m]?.hashID;
                String? sucNodeId = localRT[0][m]?.hashID;

                List<String>? preNodeIdC = preNodeId!.split('');
                List<String>? midNodeIdC = midNodeId!.split('');
                List<String>? sucNodeIdC = sucNodeId!.split('');

                int preNodeIdint = int.parse(preNodeIdC[m],radix: 16); // coverting hexadecimal value into int for comparison
                int midNodeIdint = int.parse(midNodeIdC[m], radix: 16);
                int sucNodeIdint = int.parse(sucNodeIdC[m], radix: 16);
                int localnodeIdint = int.parse(localNodeIdC[m], radix: 16);
                int nodeIdint = int.parse(nodeIdC[m], radix: 16);
                int idealMidNodeIdint = (localnodeIdint + 8) % 16;

                if (((localnodeIdint - preNodeIdint + 16) % 16) > ((nodeIdint - preNodeIdint + 16) % 16))
                {

                    if (mRtt.containsKey(localRT[2][m]!.hashID) && (localRT[2][m] != localRT[1][m] || localRT[2][m] != localRT[0][m]))
                    {
                        mRtt.remove(localRT[2][m]!.hashID); // this is done so that if node ID is not present anywhere in RT then it should also not be present in mRTT table.
                    }
                    localRT[2][m] = nodeID; //replacing pre-decessor nodeID


                }
                else if (((sucNodeIdint - localnodeIdint + 16) % 16) >((nodeIdint - localnodeIdint + 16) % 16))
                {

                    if (mRtt.containsKey(localRT[0][m]) && (localRT[0][m]!.hashID != localRT[1][m]!.hashID || localRT[0][m]!.hashID != localRT[2][m]!.hashID))
                    {
                        mRtt.remove(localRT[0][m]);
                    }

                    localRT[0][m] = nodeID; //replacing successor node id


                } else if (min(((idealMidNodeIdint - midNodeIdint + 16) % 16),((midNodeIdint - idealMidNodeIdint + 16) % 16)) > min(((idealMidNodeIdint - nodeIdint + 16) % 16),((nodeIdint - idealMidNodeIdint + 16) % 16)))
                {
                    if (mRtt.containsKey(localRT[1][m]!.hashID) &&  (localRT[1][m] != localRT[0][m] || localRT[1][m] != localRT[2][m]))
                    {
                        mRtt.remove(localRT[1][m]!.hashID);
                    }


                    localRT[1][m] = nodeID; // replacing middle node id

                } else if (nodeIdint == preNodeIdint && mRtt[nodeID]! > rtt)
                {
                    if (mRtt.containsKey(localRT[2][m]!.hashID) && (localRT[2][m] != localRT[1][m] || localRT[2][m] != localRT[0][m]))
                    {
                        mRtt.remove(localRT[2][m]!.hashID);
                    }


                    //Next 3 conditions are checking rtt if nodeID nibble matches which any of pre,success,mid nodeID.


                    localRT[2][m] = nodeID; // NodeID having less rtt is kept in the routing table.

                } else if (nodeIdint == midNodeIdint && mRtt[nodeID]! > rtt)
                {

                    if (mRtt.containsKey(localRT[1][m]!.hashID) && (localRT[1][m] != localRT[0][m] || localRT[1][m] != localRT[2][m]))
                    {
                        mRtt.remove(localRT[1][m]!.hashID);
                    }
                    localRT[1][m] = nodeID;
                } else if (nodeIdint == sucNodeIdint && mRtt[nodeID]! > rtt)
                {

                    if (mRtt.containsKey(localRT[0][m]!.hashID) && (localRT[0][m] != localRT[1][m] || localRT[0][m] != localRT[2][m]))
                    {
                        mRtt.remove(localRT[0][m]!.hashID);
                    }
                    localRT[0][m] = nodeID;
                }
            }
        }
        else if (mRtt.containsKey(nodeID)) {
            mRtt.remove(nodeID);
        }
    }

    //this is update id function

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

}