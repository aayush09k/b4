import 'dart:convert';
import 'package:nodeid/src/nodeid_base.dart';

/// Represents the network endpoint address of a node.
class EndpointAddress {
  /// Unique node ID associated with this endpoint.
  //final String? nodeID;

  /// Public IPv4 address. Should not be loopback, link-local, or multicast.
  /// (May not be loopback (127.0.0.0/8 or ::1), link-local (169.254.0.0/16 or fe80::/10), or link-local multicast (224.0.0.0/24 or ff02::/16).)
  String? publicipv4;

  /// Public IPv6 address. Should not be loopback, link-local, or multicast.
  /// (May not be loopback (127.0.0.0/8 or ::1), link-local (169.254.0.0/16 or fe80::/10), or link-local multicast (224.0.0.0/24 or ff02::/16).)
  String? publicipv6;

  /// Port number for public IPv4 communication.
  int? publicipv4port;

  /// Port number for public IPv6 communication.
  int? publicipv6port;

  /// Indicates whether IPv4 is being proxied.
  bool? proxyipv4;

  /// Indicates whether IPv6 is being proxied.
  bool? proxyipv6;

  /// Communication protocol (UDP or TCP). Defaults to TCP.
  String protocol;

  /// Constructor for [EndpointAddress].
  /// Default constructor.
  EndpointAddress({
    required NodeID nodeID,
    this.publicipv4,
    this.publicipv6,
    this.publicipv4port,
    this.publicipv6port,
    this.proxyipv4,
    this.proxyipv6,
    this.protocol = 'TCP',
  });

  /// Creates an instance from a JSON object.
  factory EndpointAddress.fromJson(Map<String, dynamic> json) {
    return EndpointAddress(
      nodeID: json['nodeID'],
      publicipv4: json['publicipv4'] as String?,
      publicipv6: json['publicipv6'] as String?,
      publicipv4port: json['publicipv4port'] as int?,
      publicipv6port: json['publicipv6port'] as int?,
      proxyipv4: json['proxyipv4'] as bool?,
      proxyipv6: json['proxyipv6'] as bool?,
      protocol: json['protocol'] as String? ?? 'TCP',
    );
  }

  /// Converts the instance to a JSON object.
  Map<String, dynamic> toJson() => {
    'nodeID': NodeID,
    'publicipv4': publicipv4,
    'publicipv6': publicipv6,
    'publicipv4port': publicipv4port,
    'publicipv6port': publicipv6port,
    'proxyipv4': proxyipv4,
    'proxyipv6': proxyipv6,
    'protocol': protocol,
  };

/// Override the toString() method to define how the object should be printed
  @override
  String toString() => jsonEncode(toJson());
}
/*
/// inplace of node id class we use nodeid package
/// Represents the identity of a node.
class NodeID {
  /// Node identifier of the node.
  final String nodeID;

  /// Public key associated with the node.
  final String publicKey;

  /// Digital signature for this node.
  final String sign;

  /// Constructor for [NodeID].
  const NodeID({
    required this.nodeID,
    required this.publicKey,
    required this.sign,
  });

  /// Creates an instance from a JSON object.
  factory NodeID.fromJson(Map<String, dynamic> json) {
    return NodeID(
      nodeID: json['nodeID'] as String,
      publicKey: json['publicKey'] as String,
      sign: json['sign'] as String,
    );
  }

  /// Converts the instance to a JSON object.
  Map<String, dynamic> toJson() => {
    'nodeID': nodeID,
    'publicKey': publicKey,
    'sign': sign,
  };

  /// Override the toString() method to define how the object should be printed
  @override
  String toString() => jsonEncode(toJson());
}
*/
/// Represents a full node with identity and network address.
/// Define the Node class that combines NodeID and EndpointAddress
class Node {
  /// Node's unique identity information
  final NodeID nodeID;

  /// Network address information.
  final EndpointAddress endpointAddress;

  /// Constructor for [Node].
  const Node({
    required this.nodeID,
    required this.endpointAddress,
  });

  /// Creates an instance from a JSON object.
  factory Node.fromJson(Map<String, dynamic> json) {
    return Node(
      nodeID: NodeID.fromJson(json['nodeID'] as Map<String, dynamic>),
      endpointAddress: EndpointAddress.fromJson(json['endpointAddress'] as Map<String, dynamic>),
    );
  }

  /// Converts the instance to a JSON object.
  Map<String, dynamic> toJson() => {
    'nodeID': nodeID.toJson(),
    'endpointAddress': endpointAddress.toJson(),
  };

  /// Override the toString() method to define how the object should be printed
  @override
  String toString() => jsonEncode(toJson());
}
/*
/// Represents a structured communication message between nodes.
class CreateMessage {
  /// Hash of the destination node's ID.
  final String destinationNodeHash;

  /// Source node object.
  final Node sourceNode;

  /// Destination node object.
  final Node destinationNode;

  /// Originating module name.
  final String sourceModule;

  /// Receiving module name.
  final String destinationModule;

  /// Query payload.
  final String query;

  /// Communication layer identifier.
  final int layerID;

  /// Optional response message from the destination node.
  String? response;

  /// Constructor for [CreateMessage].
  CreateMessage({
    required this.destinationNodeHash,
    required this.sourceNode,
    required this.destinationNode,
    required this.sourceModule,
    required this.destinationModule,
    required this.query,
    required this.layerID,
    this.response,
  });

  /// Creates an instance from a JSON object.
  factory CreateMessage.fromJson(Map<String, dynamic> json) {
    return CreateMessage(
      destinationNodeHash: json['destinationNodeHash'] as String,
      sourceNode: Node.fromJson(json['sourceNode'] as Map<String, dynamic>),
      destinationNode: Node.fromJson(json['destinationNode'] as Map<String, dynamic>),
      sourceModule: json['sourceModule'] as String,
      destinationModule: json['destinationModule'] as String,
      query: json['query'] as String,
      layerID: json['layerID'] as int,
      response: json['response'] as String?,
    );
  }

  /// Converts the instance to a JSON object.
  Map<String, dynamic> toJson() => {
    'destinationNodeHash': destinationNodeHash,
    'sourceNode': sourceNode.toJson(),
    'destinationNode': destinationNode.toJson(),
    'sourceModule': sourceModule,
    'destinationModule': destinationModule,
    'query': query,
    'layerID': layerID,
    'response': response,
  };

  /// Override the toString() method to define how the object should be printed
  @override
  String toString() => jsonEncode(toJson());
*/
  // Override the toString() method to define how the object should be printed
 /* @override
  String toString() {
    return 'destnodehash: $destinationNodeHash, srcnode: $sourceNode, destnode : $destinationNode, '
        'srcmod : $sourceModule, desctmod : $destinationModule, query : $query, layerid : $layerID, resp : $response ';
  }
  */
//}
