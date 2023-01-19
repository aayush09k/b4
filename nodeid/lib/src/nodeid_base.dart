import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';

class NodeID {
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

