import 'dart:async';
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
    DataBuffer dataBuffer=DataBuffer();

    RoutingManager._() {


        RTfilepath = "${filePath}rttable.json"; // the path where routing table file will be stored as json.
        _localNodeID = LocalNodeID();
        _localNodeID.nodeid.hashID="777E7DFC3E4616381DACA70A90CDF3C59EA80D32";// we have to get this from auth manager
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


String createMessageRM(String RM,String Relay,NodeID myNodeID,String hashID,String s,String current,String R,String nodeID,String myEndpoint, String layerID,String reqRT  ){




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

   Map<String, dynamic> jsonMyNode = {
     'pubKey': myNodeID.pubKey.toString(),
     'hashID': myNodeID.hashID.toString(),
     'sign': {'r':myNodeID.sign.r.toString(),'s':myNodeID.sign.s.toString()}     , // Replace this with actual ECSignature JSON
     'publicKeyPem': myNodeID.publicKeyPem.toString(),
   };

   String jsonStringMyNode=jsonEncode(jsonMyNode);

    // Convert to JSON String
    String jsonNodesString = jsonEncode(jsonRT);
    Map<String,dynamic> messageRM={

        'RM':"RM",
        'Relay':"R",
        'myNodeID': jsonStringMyNode,
        'hashID':hashID,
        's':"s",
        'current':current,
        'R': "R",
        'nodeID':nodeID,
        'myEndpoint': myEndpoint,
        'reqRT': 'Y',
        'layerID':layerID,
        'RT':jsonNodesString,

    };

    String jsonMessageRM=jsonEncode(messageRM);
    return jsonMessageRM;


}



    Future<void> init() async {

        // Check if the file exists
        if (File(filePath).existsSync()) {
            print('File exists.');
            // Perform actions related to the existing file,check liveliness of nodes.

        } else {
            print('File does not exist.');
           for(int i=0; i<=layers;i++){
               routingTables[i.toString()] = B4RoutingTable(localNodeID);

           }

           // add in this line logic to check for bootstrap
               await sendmessageRM(
                   'RM',
                   "Relay",
                   localNodeID.nodeid,
                   "hashID",
                   "s",
                   "current",
                   "R",
                   "nodeID",
                   "myEndpoint",
                   "0",
                   'Y'); //it will alsways be bootstrap.




            // now connect to bootstrap for updated routing table

        }
        checkForMessagesCMExecution();


    }

    Future<void> sendmessageRM(String RM,String Relay,NodeID myNodeID,String hashID,String s,String current,String R,String nodeID,String myEndpoint, String layerID,String reqRT )async {
      String message;


    message=createMessageRM(RM , Relay, myNodeID, hashID, s, current, R,  nodeID, myEndpoint,  layerID,reqRT  );

     // await manager.sendMessage("35.185.142.164", 22355, "D", "hello psj", "google");

    await manager.sendMessage("35.185.142.164", 22355, "TP", message, "aman");
     // await Future.delayed(Duration(milliseconds: 500));
    //  checkForMessagesCMExecution();

    }



    void rMessageRM(dynamic rcvdMessage ){


      Map<String, dynamic> decodedMessageRM = jsonDecode(rcvdMessage);
      String RM= decodedMessageRM['RM'];
      String Relay= decodedMessageRM['Relay'];
      String senderNodeID= decodedMessageRM['myNodeID'];
      String hashID= decodedMessageRM['hashID'];
      String s= decodedMessageRM['s'];
      String current= decodedMessageRM['current'];
      String R= decodedMessageRM['R'];
      String nodeID= decodedMessageRM['nodeID'];
      String Endpoint= decodedMessageRM['myEndpoint'];
      String reqRT= decodedMessageRM['reqRT'];
      String layerID= decodedMessageRM['layerID'];
      String RT= decodedMessageRM['RT'];

// This part of code is written to take senders node and update it because that will be not part of it's own routing table.

      Map<String,dynamic> jsonNodeid=jsonDecode(senderNodeID);
      ECSignature?  signNode = ECSignature(BigInt.parse( jsonNodeid['sign']['r']),BigInt.parse(jsonNodeid['sign']['s']));
      NodeID sendersNodeID= NodeID.createFromTable(jsonNodeid['pubKey'], signNode, jsonNodeid['hashID'], jsonNodeid['publicKeyPem']);
      routingTables[layerID]!.updateNodeID(sendersNodeID, Duration(milliseconds: 300), routingTables[layerID]!.RoutingTable);

      List<dynamic> decodedRT=jsonDecode(RT);

      List<List<NodeID?>> nodeList = decodedRT.map((innerList) {
        return (innerList as List<dynamic>).map((jsonNode) {
          if (jsonNode != null) {
            ECSignature?  sign = ECSignature(BigInt.parse( jsonNode['sign']['r']),BigInt.parse(jsonNode['sign']['s']));
            return NodeID.createFromTable(
              jsonNode['pubKey'], // Assuming this is how you reconstruct pubKey
              sign,
              jsonNode['hashID'],
               // Assuming this is how you reconstruct sign
              jsonNode['publicKeyPem'],
            );
          } else {
            return null;
          }
        }).toList();
      }).toList();

      if(  RT=='Y'){
       //mergeTables(newRoutingTable, layerId, rtt);
        sendmessageRM('RM' , "D", localNodeID.nodeid, "hashID", "s", "current", "R",  "nodeID", "myEndpoint",  "0" ,'N');
      }

    }

    Future<void> checkForMessagesCMExecution() async{
      const duration = Duration(seconds: 5); // Adjust duration as needed
      Timer.periodic(duration, (timer) {
        // This function will be executed periodically

        handleForMessages();
      });
    }

    void handleForMessages(){
      dynamic messageFromCMBuffer=manager.getBufferData();
      print(messageFromCMBuffer);

      if(messageFromCMBuffer!=null){
        Map<String, dynamic> decodedMessageRM = jsonDecode(messageFromCMBuffer);
        String RM= decodedMessageRM['RM'];

        if( RM!='RM'){
         dataBuffer.push(messageFromCMBuffer);

        }
        else{
          rMessageRM(messageFromCMBuffer);
        }

      }

      else{


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