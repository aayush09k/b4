// message sending:
// message from message factory is choosen by source node, decide whether
// dht or direct message, then decided whether relay or not based on
// NAT status(stungeip.dart) then if yes call routing manager to
// find the next hop node id(b4rttable) to which messager to be relayed
// get now the endpoint address of the relay and send the
// data to communication manager for despatch.

// this message factory is there to define the format of various
// message types and payload associated with the message types,
// this is the inner most message over which headers will be placed
// as per requirement.

class MessageFactory {

  // method to crate message with a given type and payload
  static Map<String, dynamic> createMessage(  //create base structure of message
      String type, Map<String, dynamic> payload) {
    return {
      'type': type.toLowerCase(), 
      'payload': payload, // Includes the given payload
    };
  }

  // Static method to create a routing table update message
  static Map<String, dynamic> createRTUpdate(
      String nodeID, String endpoint, bool isCore, int layerID,
      [List<Map<String, dynamic>>? table]) {
    // Calls createMessage to create the RT update message with additional routing info
    return createMessage('rt_update', {
      'source_node_id': nodeID, 
      'source_endpoint': endpoint, 
      'node_type': isCore ? 'core' : 'leaf', // Determines if the node is 'core' or 'leaf'
      'layer_id': layerID, 
      'routing_table': isCore ? table : null, // Only adds routing table if node is core
    });
  }

  // Method to create an endpoint query message for DHT routing
  Map<String, dynamic> createEndpointQuery({ //This message use for finding DHT-based endpoint of a key.
    required String nodeID,
    required String endpoint,
    required String hashID, // The destination key for DHT routing
  }) {
    final query = createMessage('endpoint_query', {
      'source_node_id': nodeID, 
      'source_endpoint': endpoint, // The source endpoint
    });

    // Wraps the query in DHT message format if required, returning the final message
    return wrapDHTMessageIfNeeded(query, true, hashID); // Always routed through DHT
  }

  // Static method to create an endpoint response message , node reply of any query then send this message.
  static Map<String, dynamic> createEndpointResponse({
    required String sourceNodeID,
    required String hashID,
    required String rootNodeID,
    required bool useRelay,
    required String ip,
    required int port,
  }) {
    return createMessage('endpoint_response', { //tells were actual node is found and relay required or not.
      'source_node_id': sourceNodeID, // ID of the source node
      'hash_id': hashID, // Hash ID for the routing key
      'root_node_id': rootNodeID, // Root node ID for the response
      'relay_flag': useRelay ? 'yes' : 'no', // Whether to use relay or not
      'root_endpoint_address': {'ip': ip, 'port': port, 'protocol': 'TCP'} // Root endpoint details
    });
  }

  Map<String, dynamic> createInnerMessage({
    required Map<String, dynamic> sourceNode,
    required Map<String, dynamic> destinationNode,
    required String msg,
  }) {
    final message = createMessage('innermost_message', {
      "sourceModule": "CM",
      "destinationModule": "CM",
      "query": msg,
      "layerID": 0,
      "response": ""
    });
    return wrapInnerMsgWithDestination(
        sourceNode: sourceNode,
        destinationNode: destinationNode,
        message: message);

    // "destinationNodeHash": destinationNode["hashID"],
    // "sourceNode": sourceNode,
    // "destinationNode": destinationNode,
  }
  static Map<String, dynamic> wrapProxyDestination({
    required String proxyHash,
    required Map<String, dynamic> message,
  }) {
    return createMessage("proxy_destination", {
      "ProxyHash": proxyHash,
      "Data": message,
    });
  }

  Map<String, dynamic> wrapInnerMsgWithDestination({
    required Map<String, dynamic> sourceNode,
    required Map<String, dynamic> destinationNode,
    required Map<String, dynamic> message,
  }) {
    return createMessage("destination", {
      "destinationNodeHash": destinationNode["hashID"],
      "sourceNode": sourceNode,
      "destinationNode": destinationNode,
      "message": message
    });
  }


  // Static method to create a publish request message
  static Map<String, dynamic> createPublish(
      String nodeID, String endpoint, List<Map<String, String>> kvPairs) {
    return createMessage('publish', {
      'source_node_id': nodeID, // The node publishing the message
      'source_endpoint': endpoint, // The endpoint sending the message
      'data': kvPairs, // Key-value pairs of data being published
    });
  }

  // Static method to create a search query message
  static Map<String, dynamic> createSearchQuery(
      String keyword, String sourceNodeID, String endpoint) {
    return createMessage('search', {
      'source_node_id': sourceNodeID, 
      'source_endpoint': endpoint, // The source endpoint
      'key': keyword // The search keyword or key
    });
  }

  // Static method to create an update index message
  static Map<String, dynamic> createUpdateIndex({
    required String hashID,
    required String sourceEndpoint,
    required String rootEndpoint,
    required String keyCopyNumber,
    required Map<String, dynamic> indexData,
    required int totalCopies,
    required String signature,
    required int copyNumber,
    required int expiryTimer,
  }) {
    return createMessage('UpdateIndex', {
      'hash_id': hashID, 
      'source_endpoint': sourceEndpoint, 
      'root_endpoint': rootEndpoint, // Root endpoint
      'key_copy_number': keyCopyNumber, 
      'index_data': indexData, // The index data to be updated
      'total_copies': totalCopies, 
      'expiry_timer': expiryTimer, // Expiry timer for the index
      'signature': signature, 
      'copy_number': copyNumber, 
    });
  }

  // Static method to create a delete index message
  static Map<String, dynamic> createDeleteIndex({
    required String hashID,
    required String sourceEndpoint,
    required String keyCopyNumber,
    required String signature,
    required int copyNumber,
  }) {
    return createMessage('DeleteIndex', {
      'hash_id': hashID, // The hash ID of the index to be deleted
      'source_endpoint': sourceEndpoint, 
      'key_copy_number': keyCopyNumber, // Key copy number
      'signature': signature, // signature
      'copy_number': copyNumber, // Copy number for index deletion
    });
  }

  // Static method to create a maintenance index message
  static Map<String, dynamic> createMaintenanceIndex({
    required String hashID,
    required String maintenanceNodeID,
    required String taskType, // e.g., "purge", "refresh"
    required String timestamp, // Timestamp of the task
  }) {
    return createMessage('MaintenanceIndex', {
      'hash_id': hashID, // The hash ID of the index being maintained
      'maintenance_node_id': maintenanceNodeID, // Maintenance node ID
      'task_type': taskType, // Task type (e.g., "purge", "refresh")
      'timestamp': timestamp, // Timestamp for the maintenance task
    });
  }

  // Static method to create a relay registration request message
  static Map<String, dynamic> createRelayRegistrationRequest(String nodeID) {
    return createMessage('relay_registration_request', {
      'node_id': nodeID, // The ID of the node requesting registration
    });
  }

  // Static method to create a relay registration response message
  static Map<String, dynamic> createRelayRegistrationResponse(
      String nodeID, String relayIP, int relayPort) {
    return createMessage('relay_registration_response', {
      'node_id': nodeID, // The ID of the node
      'relay_ip': relayIP, // IP address of the relay node
      'relay_port': relayPort, // Port of the relay node
    });
  }

  // Method to wrap transport message with relay flag
  static Map<String, dynamic> wrapTransportMessage(
      {required bool useRelay,
      required Map<String, dynamic> message,
      required String? hashID,
      String? relayIP,
      int? relayPort,
      String? destIP,
      int? destPort}) {
    if (useRelay) {
      // Wrap message in relay flag if relay is used
      return {'relay_flag': 'yes','nodeid':hashID, 'payload': message};
    } else {
      // If no relay is used, just return the message
      return {'relay_flag': 'no','nodeid':hashID, 'payload': message};
    }
  }

  // Method to wrap message with DHT routing if needed
  static Map<String, dynamic> wrapDHTMessageIfNeeded(
      Map<String, dynamic> message, bool useDHT, String? hashID) {
    if (useDHT && hashID != null && hashID.isNotEmpty) {
      // Wrap the message in DHT format if DHT is required
      return {
        'type': 'dht_msg',
        'hash_id': hashID,
        'message': message, // The original message
      };
    }
    // Return the original message if no DHT routing is required
    return message;
  }
}









// class MessageFactory {
//   static Map<String, dynamic> createMessage(
//       String type, Map<String, dynamic> payload) {
//     return {
//       'type': type.toLowerCase(),
//       'payload': payload,
//     };
//   }

//   static Map<String, dynamic> createRTUpdate(
//       String nodeID, String endpoint, bool isCore, int layerID,
//       [List<Map<String, dynamic>>? table]) {
//     return createMessage('rt_update', {
//       'source_node_id': nodeID,
//       'source_endpoint': endpoint,
//       'node_type': isCore ? 'core' : 'leaf',
//       'layer_id': layerID,
//       'routing_table': isCore ? table : null,
//     });
//   }

// // message to create an end point query
// // [endpoint address query, source node id, source node endpoint address]
//   Map<String, dynamic> createEndpointQuery({
//     required String nodeID,
//     required String endpoint,
//     required String hashID, // This is the destination key for DHT routing
//   }) {
//     final query = createMessage('endpoint_query', {
//       'source_node_id': nodeID,
//       'source_endpoint': endpoint,
//     });

//     return wrapDHTMessageIfNeeded(query, true, hashID); // Always routed
//   }

// // message to create an endpoint response
// // [endpoint address resp, hash id, root node id, relay = y/n, endpoint address]
//   static Map<String, dynamic> createEndpointResponse({
//     required String sourceNodeID,
//     required String hashID,
//     required String rootNodeID,
//     required bool useRelay,
//     required String ip,
//     required int port,
//   }) {
//     return createMessage('endpoint_response', {
//       'source_node_id': sourceNodeID,
//       'hash_id': hashID,
//       'root_node_id': rootNodeID,
//       'relay_flag': useRelay ? 'yes' : 'no',
//       'root_endpoint_address': {'ip': ip, 'port': port, 'protocol': 'TCP'}
//     });
//   }

// // message to create publish request
//   static Map<String, dynamic> createPublish(
//       String nodeID, String endpoint, List<Map<String, String>> kvPairs) {
//     return createMessage('publish', {
//       'source_node_id': nodeID,
//       'source_endpoint': endpoint,
//       'data': kvPairs,
//     });
//   }

// // message to create search query
// //[query, source node id, source node endpoint,[key]]
//   static Map<String, dynamic> createSearchQuery(
//       String keyword, String sourceNodeID, String endpoint) {
//     return createMessage('search', {
//       'source_node_id': sourceNodeID,
//       'source_endpoint': endpoint,
//       'key': keyword
//     });
//   }

// //message to create update index
// // [UpdateIndex, hash_id, source_endpoint,root_endpoint, key_copy_number,
// //index_data, total_copies, expiry_timer, signature, copy_number]
//   static Map<String, dynamic> createUpdateIndex({
//     required String hashID,
//     required String sourceEndpoint,
//     required String rootEndpoint,
//     required String keyCopyNumber,
//     required Map<String, dynamic> indexData,
//     required int totalCopies,
//     required String signature,
//     required int copyNumber,
//     required int expiryTimer,
//   }) {
//     return createMessage('UpdateIndex', {
//       'hash_id': hashID,
//       'source_endpoint': sourceEndpoint,
//       'root_endpoint': rootEndpoint,
//       'key_copy_number': keyCopyNumber,
//       'index_data': indexData,
//       'total_copies': totalCopies,
//       'expiry_timer': expiryTimer,
//       'signature': signature,
//       'copy_number': copyNumber,
//     });
//   }

// //message to create delete index.
// // [DeleteIndex, hash_id, source_endpoint, key_copy_number, signature, copy_number]
//   static Map<String, dynamic> createDeleteIndex({
//     required String hashID,
//     required String sourceEndpoint,
//     required String keyCopyNumber,
//     required String signature,
//     required int copyNumber,
//   }) {
//     return createMessage('DeleteIndex', {
//       'hash_id': hashID,
//       'source_endpoint': sourceEndpoint,
//       'key_copy_number': keyCopyNumber,
//       'signature': signature,
//       'copy_number': copyNumber,
//     });
//   }

// //message to create maintenance index
// // [MaintenanceIndex, hash_id, maintenance_node_id, task_type, timestamp]
//   static Map<String, dynamic> createMaintenanceIndex({
//     required String hashID,
//     required String maintenanceNodeID,
//     required String taskType, // e.g., "purge", "refresh"
//     required String timestamp,
//   }) {
//     return createMessage('MaintenanceIndex', {
//       'hash_id': hashID,
//       'maintenance_node_id': maintenanceNodeID,
//       'task_type': taskType,
//       'timestamp': timestamp,
//     });
//   }

//   // Relay Registration: Node → Proxy (Request)
//   //[proxyentry req, nodeid]
//   static Map<String, dynamic> createRelayRegistrationRequest(String nodeID) {
//     return createMessage('relay_registration_request', {
//       'node_id': nodeID,
//     });
//   }

//   // Relay Registration: Proxy → Node (Response)
//   // [proxy entry response, node id, proxy ip address, proxy port]
//   static Map<String, dynamic> createRelayRegistrationResponse(
//       String nodeID, String relayIP, int relayPort) {
//     return createMessage('relay_registration_response', {
//       'node_id': nodeID,
//       'relay_ip': relayIP,
//       'relay_port': relayPort,
//     });
//   }

//   /// method to do entry in tabels at proxy and at the node
//   /// requesting for registration during the registration is to be
//   /// included as binding of sockets is there: Mr NK singh

// // method to choose between relay vs not relay: function deciding the same
//   static Map<String, dynamic> wrapTransportMessage(
//       {required bool useRelay,
//       required Map<String, dynamic> message,
//       String? relayIP,
//       int? relayPort,
//       String? destIP,
//       int? destPort}) {
//     if (useRelay) {
//       return {'relay_flag': 'yes', 'payload': message};
//     } else {
//       return {'relay_flag': 'no', 'payload': message};
//     }
//   }

// // function to decide between dht and non dht
//   Map<String, dynamic> wrapDHTMessageIfNeeded(
//       Map<String, dynamic> message, bool useDHT, String? hashID) {
//     if (useDHT && hashID != null && hashID.isNotEmpty) {
//       return {
//         'type': 'dht_msg',
//         'hash_id': hashID,
//         'message': message,
//       };
//     }
//     return message;
//   }
// }
