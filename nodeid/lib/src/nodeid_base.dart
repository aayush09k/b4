import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';

class LocalNodeID {
  late String nodeID;
  dynamic pvtKey;
  dynamic pubKey;
  late AsymmetricKeyPair keyPair;
  late Uint8List sign;
  late bool verify;

  LocalNodeID() {
    keyPair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
    dynamic rPub = keyPair.publicKey;
    Uint8List pubBytes = CryptoUtils.rsaPublicKeyModulusToBytes(rPub);
    nodeID = CryptoUtils.getHash(pubBytes,
        algorithmName: 'SHA-1'); //default is SHA256

    final List<int> codeUnits = nodeID.codeUnits;
    final Uint8List unit8List = Uint8List.fromList(codeUnits);
    pubKey = keyPair.publicKey;

    pvtKey = keyPair.privateKey;

    sign = CryptoUtils.rsaSign(pvtKey, unit8List, algorithmName: 'SHA-256/RSA');
    verify = CryptoUtils.rsaVerify(pubKey, unit8List, sign);
  }
}
