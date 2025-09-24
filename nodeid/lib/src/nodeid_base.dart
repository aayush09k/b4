import 'dart:convert';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:basic_utils/basic_utils.dart';

class NodeID {
  var pubKey;
  late String hashID;
  late ECSignature sign;
  late String publicKeyPem ;
  late String? localIpv4=null;
  late String? publicIpv4=null;
  late String? publicIpv6=null;
  late int? natStatus=null;
  late int? localIpv4Port=null;
  late int? publicIpv4Port=null;
  late int? publicIpv6Port=null;
  late String? communicatorIP=null;
  late int? communicatorPort=null;
  late int listeningPort=22800;
  var keyp;

  NodeID(AsymmetricKeyPair keyPair) {
    keyp=keyPair;
    pubKey = keyPair.publicKey;
    publicKeyPem = CryptoUtils.encodeEcPublicKeyToPem(pubKey);
    final pubBytes = CryptoUtils.getBytesFromPEMString(publicKeyPem);
    hashID = CryptoUtils.getHash(pubBytes, algorithmName: 'SHA-1');
    final List<int> codeUnits = (hashID + publicKeyPem).codeUnits;
    final Uint8List unit8List = Uint8List.fromList(codeUnits);
    dynamic pvtKey = keyPair.privateKey;
    sign = CryptoUtils.ecSign(pvtKey, unit8List);
  }

  /// Creates an instance from a JSON object.
  ///
  // Named constructor from raw fields (fromJson)
  NodeID.fromRaw({
    required this.hashID,
    required this.pubKey,
    required this.sign,
  });

  /// Creates an instance from a JSON object.
  factory NodeID.fromJson(Map<String, dynamic> json) {
    return NodeID.fromRaw(
      hashID: json['nodeID'] as String,
      pubKey: json['publicKey'] as String,
      sign: json['sign'],
    );
  }

  /// Converts the instance to a JSON object.
  Map<String, dynamic> toJson() => {
    'nodeID': hashID,
    'publicKey': pubKey,
    'sign': sign,
  };

  /// Override the toString() method to define how the object should be printed
  @override
  String toString() => jsonEncode(toJson());


  NodeID.createFromTable(this.publicKeyPem,this.sign,this.hashID,this.pubKey,this.localIpv4,this.publicIpv4,this.publicIpv6,this.natStatus,this.localIpv4Port,this.publicIpv4Port,this.publicIpv6Port,this.communicatorIP,this.communicatorPort,this.listeningPort);
}

class LocalNodeID {
  dynamic pvtKey;
  late NodeID nodeid;

  LocalNodeID() {
    AsymmetricKeyPair keyPair = CryptoUtils.generateEcKeyPair();
    pvtKey = keyPair.privateKey;
    nodeid = NodeID(keyPair);
  }
  LocalNodeID.k(AsymmetricKeyPair keyPair) {
    pvtKey = keyPair.privateKey;
    nodeid = NodeID(keyPair);
  }
}


//final eccPublicKey = pubKey as ECPublicKey;
//final pubPoint = eccPublicKey.Q;
//Uint8List? pubBytes = pubPoint?.getEncoded(false);

//List<int> rBytes = ecSignature.r.toBytes();
//List<int> sBytes = ecSignature.s.toBytes();
//final sign = Uint8List.fromList([...rBytes, ...sBytes]);
//sign = Uint8List.fromList(ecSignature as List<int>);
//List<int> rBytes = hex.decode(ecSignature.r.toRadixString(64));
//List<int> sBytes = hex.decode(ecSignature.s.toRadixString(64));
//sign = Uint8List.fromList([...rBytes, ...sBytes]);
//sign = Uint8List.fromList(List<int>.from(ecSignature.r as Iterable)..addAll(ecSignature.s as Iterable<int>));


/*class NodeID {

  dynamic pubKey;
  late String hashID;
  late Uint8List sign;

  NodeID(AsymmetricKeyPair keyPair) {
    pubKey = keyPair.publicKey;

    Uint8List pubBytes = CryptoUtils.rsaPublicKeyModulusToBytes(pubKey);
    hashID = CryptoUtils.getHash(pubBytes, algorithmName: 'SHA-1');

    final List<int> codeUnits = (hashID + pubKey.toString()).codeUnits;
    final Uint8List unit8List = Uint8List.fromList(codeUnits);
    dynamic pvtKey = keyPair.privateKey;
    sign = CryptoUtils.rsaSign(pvtKey, unit8List, algorithmName: 'SHA-256/RSA');
  }
}

class LocalNodeID {
  dynamic pvtKey;
  late NodeID nodeid;

  LocalNodeID() {
    AsymmetricKeyPair keyPair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
    pvtKey = keyPair.privateKey;
    nodeid = NodeID(keyPair);

  }

  LocalNodeID.k(AsymmetricKeyPair keyPair) {
    pvtKey = keyPair.privateKey;
    nodeid = NodeID(keyPair);
  }
}*/


