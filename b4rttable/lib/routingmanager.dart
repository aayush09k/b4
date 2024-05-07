import 'dart:convert';

import 'package:b4rttable/b4rttable.dart';
import 'dart:io';
import 'package:nodeid/nodeid.dart';
import 'package:b4rttable/config.dart';
import 'package:b4commgr/b4commgr.dart';
import 'package:b4commgr/bufferdata.dart';
import 'package:basic_utils/basic_utils.dart';



class RoutingManager{


    String filePath=AppConfig.filepath;// Get file path from AppConfig.
    String? rcvdMessage;
    String? RTfilepath; //
    int layers=AppConfig.numberOfLayers;
    late LocalNodeID _localNodeID;
    Map<String,B4RoutingTable> routingTables={};
    /*
    0 - Base layer
    1 - IPv4 non-nated layer
    2 - IPv6 non-nated layer
    3 - IPv4/IPv6 dual stack non-nated layer
    4 - file storage layer
    5 - file storage reputation layer
    */
    Map<String,B4RoutingTable> neighbourTables={};
    Map<String,B4RoutingTable> latlongTables={};
    CommunicationManager manager= CommunicationManager();

    RoutingManager._() {


        RTfilepath = "${filePath}rttable.json"; // the path where routing table file will be stored as json.
        _localNodeID = LocalNodeID();
        _localNodeID.nodeid.hashID="367E7DFC3E4616381DACA70A90CDF3C59EA80D32";
        // Call the init() function when the instance is created
       init();
    }
    LocalNodeID get localNodeID => _localNodeID;
    // Getter to access the singleton instance
    static RoutingManager get instance {
        _instance ??= RoutingManager._();
        return _instance!;
    }
    static RoutingManager? _instance;


String createMessageRM(String RM,String Relay,String myNodeID,String hashID,String s,String current,String R,String nodeID,String myEndpoint, String layerID,String reqRT  ){
   String requestRT='N';



    List<List<Map<String, dynamic>?>> jsonRT= routingTables[layerID]!.RoutingTable.map((innerList) {
        return innerList.map((nodeID) {
            if (nodeID != null) {
                return {
                    'hashID': nodeID.hashID,
                    'publicKey': nodeID.pubKey.toString(),
                    'sign':{'r':nodeID.sign.r.toString(),
                        's':nodeID.sign.s.toString()},
                    'publicKeyPem':nodeID.publicKeyPem.toString(),
                    // Add other properties if needed
                };
            } else {
                return null;
            }
        }).toList();
    }).toList();

    // Convert to JSON String
    String jsonNodesString = jsonEncode(jsonRT);
    Map<String,dynamic> messageRM={

        'RM':RM,
        'Relay':R,
        'myNodeID': localNodeID.nodeid.hashID,
        'hashID':hashID,
        's':s,
        'current':current,
        'R': R,
        'nodeID':nodeID,
        'myEndpoint': myEndpoint,
        'reqRT': requestRT,
        'layerID':layerID,
        'RT':jsonNodesString,

    };

    String jsonMessageRM=jsonEncode(messageRM);
    return jsonMessageRM;


}



    void init() {

        // Check if the file exists
        if (File(filePath).existsSync()) {
            print('File exists.');
            // Perform actions related to the existing file,check liveliness of nodes.

        } else {
            print('File does not exist.');
           for(int i=0; i<=layers;i++){
               routingTables[i.toString()] = B4RoutingTable(localNodeID);

           }
             if(localNodeID.nodeid.hashID!="Bootstrap") {
               sendmessageRM(
                   'RM',
                   "Relay",
                   "myNodeID",
                   "hashID",
                   "s",
                   "current",
                   "R",
                   "nodeID",
                   "myEndpoint",
                   "layerID",
                   'Y'); //it will alsways be bootstrap.
             }



            // now connect to bootstrap for updated routing table

        }


    }

    Future<void> sendmessageRM(String RM,String Relay,String myNodeID,String hashID,String s,String current,String R,String nodeID,String myEndpoint, String layerID,String reqRT )async {
      String message;


    message=createMessageRM(RM , Relay, myNodeID, hashID, s, current, R, nodeID, myEndpoint,  layerID,reqRT  );

    manager.sendMessage("35.185.142.", 22356, "D", message, "google");

    }



    void rMessageRM(String rcvdMessage ){


      Map<String, dynamic> decodedMessageRM = jsonDecode(rcvdMessage);
      String RM= decodedMessageRM['RM'];
      String Relay= decodedMessageRM['Relay'];
      String myNodeID= decodedMessageRM['myNodeID'];
      String hashID= decodedMessageRM['hashID'];
      String s= decodedMessageRM['s'];
      String current= decodedMessageRM['current'];
      String R= decodedMessageRM['R'];
      String nodeID= decodedMessageRM['nodeID'];
      String Endpoint= decodedMessageRM['Endpoint'];
      String reqRT= decodedMessageRM['Y'];
      String layerID= decodedMessageRM['layerID'];
      String RT= decodedMessageRM['RT'];

      List<dynamic> decodedRT=jsonDecode(RT);

      List<List<NodeID?>> nodeList = decodedRT.map((innerList) {
        return (innerList as List<dynamic>).map((jsonNode) {
          if (jsonNode != null) {
            ECSignature?  signature = ECSignature(BigInt.parse( jsonNode['sign']['r']),BigInt.parse(jsonNode['sign']['s']));
            return NodeID.createFromTable(
              jsonNode['pubKey'], // Assuming this is how you reconstruct pubKey
              jsonNode['hashID'],
              signature.toString(), // Assuming this is how you reconstruct sign
              jsonNode['publicKeyPem'],
            );
          } else {
            return null;
          }
        }).toList();
      }).toList();

      if(nodeList!=null && RT=='Y'){
       //mergeTables(newRoutingTable, layerId, rtt);
        sendmessageRM('RM' , "Relay", "myNodeID", "hashID", "s", "current", "R",  "nodeID", "myEndpoint",  "layerID" ,'N');
      }

    }



    Map<String,B4RoutingTable> getFullRT(){

            return routingTables;


        }


        void mergeTables(Map<String,B4RoutingTable> newRoutingTable,String layerId,Duration rtt){

            List<List<NodeID?>> newRT=  newRoutingTable[layerId]!.RoutingTable;
            List<List<NodeID?>> localRT=routingTables[layerId]!.RoutingTable;


        routingTables[layerId]!.updateRtTable(localRT, newRT);

        }






}