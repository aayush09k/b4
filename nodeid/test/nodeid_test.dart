import 'package:basic_utils/basic_utils.dart';
import 'package:nodeid/nodeid.dart';
import 'package:test/test.dart';
import 'dart:typed_data';

void main() {
  LocalNodeID localnd = LocalNodeID();
  dynamic pvt1 = localnd.pvtKey;
  dynamic hash1 = localnd.nodeid.hashID;
  print('hash1: $hash1');
  dynamic pub1 = localnd.nodeid.pubKey;
  dynamic sign1 = localnd.nodeid.sign;
  print('sign1: $sign1');
  dynamic publicKeyPem = localnd.nodeid.publicKeyPem;

  //final publicKeyPem = CryptoUtils.encodeEcPublicKeyToPem(pub1);
  Uint8List pubBytes2 = CryptoUtils.getBytesFromPEMString(publicKeyPem);
  dynamic hash2 = CryptoUtils.getHash(pubBytes2, algorithmName: 'SHA-1');
  print('hash2: $hash2');
  test('hashID', () {
    expect(hash1, hash2);
  });

  final List<int> codeUnits = (hash2 + publicKeyPem).codeUnits;
  final Uint8List unit8List = Uint8List.fromList(codeUnits);
  final sign2 = CryptoUtils.ecSign(pvt1, unit8List);
  print('sign2: $sign2');
  /*test('signature', () {
    expect(sign1, sign2);
  });*/

  bool verify1 = CryptoUtils.ecVerify(pub1, unit8List, sign1);
  print('verify1: $verify1');
  bool verify2 = CryptoUtils.ecVerify(pub1, unit8List,sign2);
  print('verify2: $verify2');
  test('sign verify', () {
    expect(verify1, verify2);
  });

  /*test('signature verification', () {
    expect(verify, true);
  });*/
}



/*void main() {
  LocalNodeID localnd = LocalNodeID();
  dynamic pvt1 = localnd.pvtKey;
  dynamic hash1 = localnd.nodeid.hashID;
  print('hash1: $hash1');
  dynamic pub1 = localnd.nodeid.pubKey;
  dynamic sign1 = localnd.nodeid.sign;
  print('sign1: $sign1');

  Uint8List pubBytes = CryptoUtils.rsaPublicKeyModulusToBytes(pub1);
  dynamic hash2 = CryptoUtils.getHash(pubBytes, algorithmName: 'SHA-1');
  print('hash2: $hash2');
  test('hashID', () {
    expect(hash1, hash2);
  });

  final List<int> codeUnits = (hash1 + pub1.toString()).codeUnits;
  final Uint8List unit8List = Uint8List.fromList(codeUnits);
  dynamic sign2 =
      CryptoUtils.rsaSign(pvt1, unit8List, algorithmName: 'SHA-256/RSA');
  print('sign2: $sign2');
  test('signature', () {
    expect(sign1, sign2);
  });

  bool verify = CryptoUtils.rsaVerify(pub1, unit8List, sign1);
  test('signature verification', () {
    expect(verify, true);
  });
}*/
