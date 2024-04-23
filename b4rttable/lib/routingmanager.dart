import 'package:b4rttable/b4rttable.dart';
import 'dart:io';
import 'package:nodeid/nodeid.dart';
import 'package:b4rttable/config.dart';


class RoutingManager{

    String filePath=AppConfig.filepath;// Get file path from AppConfig.
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



            // now connect to bootstrap for updated routing table

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