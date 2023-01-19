import 'package:basic_utils/basic_utils.dart';
import 'package:nodeid/nodeid.dart';
import 'package:test/test.dart';
import 'dart:typed_data';

void main() {
  LocalNodeID localnd = LocalNodeID();
  dynamic pvt1 = localnd.pvtKey;
  dynamic hash1 = localnd.nodeid.hashID;
  dynamic pub1 = localnd.nodeid.pubKey;
  dynamic sign1 = localnd.nodeid.sign;

  Uint8List pubBytes = CryptoUtils.rsaPublicKeyModulusToBytes(pub1);
  dynamic hash2 = CryptoUtils.getHash(pubBytes, algorithmName: 'SHA-1');
  test('hashID', () {
    expect(hash1, hash2);
  });

  final List<int> codeUnits = (hash1 + pub1.toString()).codeUnits;
  final Uint8List unit8List = Uint8List.fromList(codeUnits);
  dynamic sign2 =
      CryptoUtils.rsaSign(pvt1, unit8List, algorithmName: 'SHA-256/RSA');
  test('signature', () {
    expect(sign1, sign2);
  });

  bool verify = CryptoUtils.rsaVerify(pub1, unit8List, sign1);
  test('signature verification', () {
    expect(verify, true);
  });
}
