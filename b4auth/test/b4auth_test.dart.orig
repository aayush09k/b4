import 'dart:convert';
import 'dart:math';
import 'package:b4auth/b4auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:basic_utils/basic_utils.dart' as x509;
import 'package:basic_utils/basic_utils.dart' as crypto_utils;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/widgets.dart' hide Padding;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:mockito/mockito.dart';
import 'package:nodeid/nodeid.dart';
import 'package:pointycastle/api.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AuthManager myObject =AuthManager ();

  String country = "india";
  String organization = "iitkanpur";
  String commonName = "inderpal";
  String surname = "singh";
  String stateOrProvinceName = "UP";
 // String givenName = "123456789125";
  //String userID = "iitk@iitk.ac.in";
  String userID = "kinginder@rediffmail.com";
  String content = " data for digital signature";
  String email = 'kinginder@rediffmail.com';
  //String email = 'inderpals22@iitk.ac.in';
  //String email = 'singh.inderpal.86@gmail.com';
  //String email = 'billabond@gmail.com';
  String otp = "01234567";


  test('generate the initial user certificate for saving  ', () async {
    myObject.generateSelfSignedUserCertificate(country, organization, commonName, surname,
        stateOrProvinceName, /*givenName*/ userID);

    final userCert = generatedCertificate?.x509cert;
    File('C:\\Users\\HP\\Desktop\\b4testdata\\userSelfSignedCertificate.pem').writeAsStringSync(userCert!);
    final userPrivateKey = generatedCertificate?.privateKeyPem;
    File('C:\\Users\\HP\\Desktop\\b4testdata\\userPrivateKey.pem').writeAsStringSync(userPrivateKey!);
    final userCertRead =File('C:\\Users\\HP\\Desktop\\b4testdata\\userSelfSignedCertificate.pem').readAsStringSync();
    final userPrivateKeyRead =File('C:\\Users\\HP\\Desktop\\b4testdata\\userPrivateKey.pem').readAsStringSync();
    if (kDebugMode) {
      debugPrint('user self signed cert : $userCertRead');
    }
    if (kDebugMode) {
      debugPrint('user private key : $userPrivateKeyRead');
    }
    expect(userCert, userCertRead);
    expect(userPrivateKey, userPrivateKeyRead);


   // String serverCertificate = '';
   // String serverPrivateKey = '';
   // String serverPublicKey = '';

    /// Now here we write these files in local storage so that we can later on read and use them in other functions
    /// by emulating that we are reading from a secure storage. Currently the files are not encrypted. We will
    /// use these same files with different names with respect to the context of the function
   // myObject.saveToLocalStorage(serverCertificate,serverPrivateKey,serverPublicKey,
       // 'C:\\Users\\HP\\Desktop\\b4testdata\\serverCertificate.pem',
       // 'C:\\Users\\HP\\Desktop\\b4testdata\\serverPrivateKey.pem',
       // 'C:\\Users\\HP\\Desktop\\b4testdata\\serverPublicKey.pem');
  });

   test('server signature validation', () async {
    final serverSignedCertificate =File('C:\\Users\\HP\\Desktop\\b4testdata\\serverSignedCertificateFromAuthServer.pem').readAsStringSync();
    if (kDebugMode) {
      debugPrint('signed cert read is :$serverSignedCertificate');
    }
    final serverCertificate =File('C:\\Users\\HP\\Desktop\\b4testdata\\b4AuthServerCertificate.pem').readAsStringSync();
    if (kDebugMode) {
      debugPrint('server cert read is :$serverCertificate');
    }
    final certificateServerSignatureVerification = await myObject.verifyServerSignature
      (serverSignedCertificate,serverCertificate);
    expect(certificateServerSignatureVerification, true);
  });

  test('certificate expiry verification', () async {
final decryptedServerSignedCertificate =File('C:\\Users\\HP\\Desktop\\b4testdata\\serverSignedCertificateFromAuthServer.pem').readAsStringSync();
        final isValid = await myObject.validateTime(decryptedServerSignedCertificate);
      expect(isValid, true);
          });

  ///digital signature verify
  test('digital signature check', () async {
    //final data2Future = myObject.readFromLocalStorage(LocalStorageValueType.serverPrivateKey);
    final privateKeyPemDecrypted = File('C:\\Users\\HP\\Desktop\\b4testdata\\userPrivateKey.pem').readAsStringSync();
    final digitalSignature = await myObject.createDigitalSignature(content, privateKeyPemDecrypted);
    final userCert = File('C:\\Users\\HP\\Desktop\\b4testdata\\userSelfSignedCertificate.pem').readAsStringSync();
    //final data3Future = myObject.readFromLocalStorage(LocalStorageValueType.serverPublicKey);
    //final publicKeyPemDecrypted = await data3Future;
    final publicKeyPemDecrypted = await myObject.extractPublicKeyFromCertificate(userCert);
    final publicKey = crypto_utils.CryptoUtils.ecPublicKeyFromPem(publicKeyPemDecrypted);
    Uint8List dataToVerify = Uint8List.fromList(utf8.encode(content));
    bool isSignatureValid = crypto_utils.CryptoUtils.ecVerifyBase64(publicKey ,dataToVerify,digitalSignature);
    expect(isSignatureValid, true);
  });



  ///message checking for authentication
   test('message authentication check', () async {
    final privateKeyPemDecrypted = File('C:\\Users\\HP\\Desktop\\b4testdata\\userPrivateKey.pem').readAsStringSync();
    final message = await myObject.createMessageForAuthentication(content, privateKeyPemDecrypted);
    if (kDebugMode) {
      debugPrint('message is : $message');
    }
    final userCert = File('C:\\Users\\HP\\Desktop\\b4testdata\\userSelfSignedCertificate.pem').readAsStringSync();
    final returnedContent = await myObject.checkMessageForAuthentication(message, userCert);
    if (kDebugMode) {
      debugPrint('returned content is : $returnedContent');
    }
    expect(returnedContent, content);
  });



  /// Check email presence in server database
     test('email check in server repository', () async {
    var respFuture = myObject.verifyEmailInServerDatabase(email);
    final emailVerificationResponse = await respFuture;
    if (kDebugMode) {
      debugPrint('Response from server is : $emailVerificationResponse');
    }
    expect(emailVerificationResponse == '14' || emailVerificationResponse == '15', true);

    });


  /// send self signed certificate to server
  test('send self signed certificate to server', () async {
    //var respFuture = myObject.verifyEmailInServerDatabase(email);
  // final selfSignedCertFuture = myObject.readFromLocalStorage(LocalStorageValueType.serverCertificate);
   //final selfSignedCertificate = await selfSignedCertFuture;
   final selfSignedCertificate =File('C:\\Users\\HP\\Desktop\\b4testdata\\userSelfSignedCertificate.pem').readAsStringSync();
    final responseAfterSendingCertificate = myObject.sendSelfSignedCertificateToServer(selfSignedCertificate);
    if (kDebugMode) {
      debugPrint('Response from server is : $responseAfterSendingCertificate');
    }
    //expect(resp == '14', true);
  });


 /// send otp, device id(MAC Address), node id, self signed certificate
  /// to auth server and in response receive the signed certificate from server
   test('send otp, device id, node id and self signed certificate to server', () async{
String nodeId = '5211CFBDE65267453631FB0B29B6A785390EA3AF'; // for testing only, actual node id will be read by getNodeId function in auth storage and then passed to this function
   final decryptedSelfSignedCertificate = File('C:\\Users\\HP\\Desktop\\b4testdata\\userSelfSignedCertificate.pem').readAsStringSync();
   final dataMap = await myObject.sendOtpNodeIdDeviceIdSelfSignedCertificateToServer
     (otp, decryptedSelfSignedCertificate, nodeId);
   final signedCertificatePem = dataMap['signedCertificate'];
   final serverCertificatePem = dataMap['serverCertificate'];

   //print('signed cert recd is :$signedCertificateReceived');
   expect(signedCertificatePem, isNotNull);
   expect(serverCertificatePem, isNotNull);

 });



   test('extract public key from certificate', () async {
    final serverSignedCertificate = File('C:\\Users\\HP\\Desktop\\b4testdata\\serverSignedCertificateFromAuthServer.pem').readAsStringSync();
    final publicKeyPem = await myObject.extractPublicKeyFromCertificate(serverSignedCertificate);
    if (kDebugMode) {
      debugPrint('public key read is : $publicKeyPem');
    }
    expect(publicKeyPem, isNotNull);
  });




   test('generate random key, encrypt and decrypt data with symmetric random key ', ()  async {
       String random1 = await myObject.generateRandomNumber();
       String random2 = await myObject.generateRandomNumber();
       final randomKey = await myObject.generateRandomKey(random1, random2);
       if (kDebugMode) {
         debugPrint ('random key : $randomKey');
       }
       String data = 'This is test data to encrypt and decrypt by random key generated by two random numbers';

       final encryptedData = await myObject.encryptDataWithRandomKey(data, randomKey);
       final decryptedData = await myObject.decryptDataWithRandomKey(encryptedData, randomKey);

       expect(decryptedData,'This is test data to encrypt and decrypt by random key generated by two random numbers' );
     });


   test('encryption by user key of 8 characters  ', ()  async {

    String data = 'to test encryption by 8 characters';
    String userKey = 'abcdefgh';

    final encryptedData = await myObject.toEncrypt(data, userKey);
    //final decryptedData = await myObject.decryptDataWithRandomKey(encryptedData, randomKey);
    expect(encryptedData, isNotNull );
    final decryptedData = await myObject.toDecrypt(encryptedData, userKey);
    expect(decryptedData, 'to test encryption by 8 characters' );

    //expect(decryptedData,'This is test data to encrypt and decrypt by random key generated by two random numbers' );
  });






     test('encrypt and decrypt by ECC public and private key', () async {
    String data = 'ECC Test data FROM USER1 TO USER2';
    final user1PrivateKeyPem = File('C:\\Users\\HP\\Desktop\\b4testdata\\user1PrivateKey.pem').readAsStringSync();
    final user1PublicKeyPem = File('C:\\Users\\HP\\Desktop\\b4testdata\\user1PublicKey.pem').readAsStringSync();
    final user2PublicKeyPem = File('C:\\Users\\HP\\Desktop\\b4testdata\\user2PublicKey.pem').readAsStringSync();
    final user2PrivateKeyPem = File('C:\\Users\\HP\\Desktop\\b4testdata\\user2PrivateKey.pem').readAsStringSync();
    final encryptedData = await myObject.encryptWithEcc(data,user2PublicKeyPem, user1PrivateKeyPem);
    final decryptedData = await myObject.decryptWithEcc(encryptedData,user2PrivateKeyPem, user1PublicKeyPem);
    expect(encryptedData,isNotNull );
    expect(decryptedData,'ECC Test data FROM USER1 TO USER2' );


    String dataReverse = 'FROM USER2 TO USER1 Ecc Test Data';
    final encryptedDataReverse = await myObject.encryptWithEcc(dataReverse,user1PublicKeyPem, user2PrivateKeyPem);
    final decryptedDataReverse = await myObject.decryptWithEcc(encryptedDataReverse,user1PrivateKeyPem, user2PublicKeyPem);
    expect(encryptedDataReverse,isNotNull );
    expect(decryptedDataReverse,'FROM USER2 TO USER1 Ecc Test Data' );
  });


  test('complete key exchange and encryption scenario', () async{
  final user1PrivateKeyPem = File('C:\\Users\\HP\\Desktop\\b4testdata\\user1PrivateKey.pem').readAsStringSync();
  final user1PublicKeyPem = File('C:\\Users\\HP\\Desktop\\b4testdata\\user1PublicKey.pem').readAsStringSync();
  final user2PublicKeyPem = File('C:\\Users\\HP\\Desktop\\b4testdata\\user2PublicKey.pem').readAsStringSync();
  final user2PrivateKeyPem = File('C:\\Users\\HP\\Desktop\\b4testdata\\user2PrivateKey.pem').readAsStringSync();


  /// User1 is Sender and User2 is Receiver

  /// Sender generates random number 1 , encrypts it and sends it to receiver
String random1 = await myObject.generateRandomNumber();
if (kDebugMode) {
  debugPrint('random num 1 : $random1');
}
final encryptRandom1 = await myObject.encryptWithEcc(random1,user2PublicKeyPem, user1PrivateKeyPem);

/// receiver decrypts the random number 1
final decryptRandom1 = await myObject.decryptWithEcc(encryptRandom1,user2PrivateKeyPem, user1PublicKeyPem);
  if (kDebugMode) {
    debugPrint('random num 1 received at receiver : $decryptRandom1');
  }

  /// receiver encrypts the random num 1 again and sends it back to sender
  final encryptRandom1Received = await myObject.encryptWithEcc(decryptRandom1,user1PublicKeyPem, user2PrivateKeyPem);

  /// sender receives back the same random num 1 , so verification is done.
  final decryptRandom1Received = await myObject.decryptWithEcc(encryptRandom1Received,user1PrivateKeyPem, user2PublicKeyPem);
  if (kDebugMode) {
    debugPrint('random num 1 received back at sender : $decryptRandom1Received');
  }
  expect(random1, decryptRandom1Received);


  /// Receiver generates random number 2, encrypts it and sends it to sender.
  String random2 = await myObject.generateRandomNumber();
  if (kDebugMode) {
    debugPrint('random num 2 : $random2');
  }
  final encryptRandom2 = await myObject.encryptWithEcc(random2,user1PublicKeyPem, user2PrivateKeyPem);

  /// sender receives random number 2 , decrypts it and gets random number 2.
  final decryptRandom2 = await myObject.decryptWithEcc(encryptRandom2,user1PrivateKeyPem, user2PublicKeyPem);
  if (kDebugMode) {
    debugPrint('random num 2 received at sender : $decryptRandom2');
  }


  /// sender encrypts random number 2 and sends it back to the receiver
  final encryptRandom2Received = await myObject.encryptWithEcc(decryptRandom2,user2PublicKeyPem, user1PrivateKeyPem);

  /// receiver receives back the same random num 2 , so verification is done.
  final decryptRandom2Received = await myObject.decryptWithEcc(encryptRandom2Received,user2PrivateKeyPem, user1PublicKeyPem);
  if (kDebugMode) {
    debugPrint('random num 2 received back at receiver : $decryptRandom2Received');
  }
  expect(random2, decryptRandom2Received);


  /// sender generates symmetric key by help of random number 1 which it receives back from the receiver
  /// which should be same random number 1 and random number 2 received from the receiver.
  final randomKeyAtSender = await myObject.generateRandomKey(decryptRandom1Received, decryptRandom2);
  if (kDebugMode) {
    debugPrint('symmetric key generated at sender : $randomKeyAtSender');
  }

  /// receiver generates symmetric key by help of random number 2 which it receives back from the sender
  /// which should be same random number 2 and random number 1 received from the sender.
  final randomKeyAtReceiver = await myObject.generateRandomKey(decryptRandom2Received, decryptRandom1);
    if (kDebugMode) {
      debugPrint('symmetric key generated at receiver : $randomKeyAtReceiver');
    }

  /// The symmetric random key generated at both ends independently must be same
  expect(randomKeyAtSender, randomKeyAtReceiver);


  /// Use the symmetric key generated at sender to encrypt data.
  String  testData = 'test data for encryption and decryption by symmetric key';
  final encryptedTestData = await myObject.encryptDataWithRandomKey(testData, randomKeyAtSender);


  /// Use the symmetric key generated at receiver to decrypt data
  final decryptedTestData = await myObject.decryptDataWithRandomKey(encryptedTestData, randomKeyAtReceiver);
  if (kDebugMode) {
    debugPrint('decryptedTestData : $decryptedTestData');
  }
  expect(decryptedTestData, 'test data for encryption and decryption by symmetric key');

});



   test('check revocation status of a certificate', () async{
    final certificate = File('C:\\Users\\HP\\Desktop\\b4testdata\\serverSignedCertificateFromAuthServer.pem').readAsStringSync();
    final revocation = await myObject.isRevoked(certificate);
    if (kDebugMode) {
      debugPrint('Revocation status is : $revocation');
    }
    expect(revocation, isNotNull);
  });






  test('genUsersForMutAuth() generate two users for mutual authentication', () async{

    final commonName = 'user1';
    final organization = 'user1';
    final country = 'user1';
    final attributes1 = {
      'C': country,
      'O': organization,
      'CN': commonName,
      // for user email ID
    };
    final eccKeyPair = crypto_utils.CryptoUtils.generateEcKeyPair();
    final privateKeyOne = eccKeyPair.privateKey as x509.ECPrivateKey;
    final publicKeyOne = eccKeyPair.publicKey as x509.ECPublicKey;
    final user1PrivateKeyPem = crypto_utils.CryptoUtils.encodeEcPrivateKeyToPem(privateKeyOne);

    // Modify the file path below as per your machine, remember this is just for testing not in production code.
    File('C:\\Users\\HP\\Desktop\\b4testdata\\user1PrivateKey.pem').writeAsStringSync(user1PrivateKeyPem);

    final user1PublicKeyPem = crypto_utils.CryptoUtils.encodeEcPublicKeyToPem(publicKeyOne);

    // Modify the file path below as per your machine, remember this is just for testing not in production code.
    File('C:\\Users\\HP\\Desktop\\b4testdata\\user1PublicKey.pem').writeAsStringSync(user1PublicKeyPem);

    final csr = x509.X509Utils.generateEccCsrPem(attributes1, privateKeyOne, publicKeyOne);
    final user1Certificate = x509.X509Utils.generateSelfSignedCertificate(privateKeyOne, csr, 365);

    // Modify the file path below as per your machine, remember this is just for testing not in production code.
    File('C:\\Users\\HP\\Desktop\\b4testdata\\user1Certificate.pem').writeAsStringSync(user1Certificate);

    final commonName2 = 'user2';
    final organization2 = 'user2';
    final country2 = 'user2';
    final attributes2 = {
      'C': country2,
      'O': organization2,
      'CN': commonName2,
      // for user email ID
    };
    final eccKeyPairTwo = crypto_utils.CryptoUtils.generateEcKeyPair();
    final privateKeyTwo = eccKeyPairTwo.privateKey as x509.ECPrivateKey;
    final publicKeyTwo = eccKeyPairTwo.publicKey as x509.ECPublicKey;
    final user2PrivateKeyPem = crypto_utils.CryptoUtils.encodeEcPrivateKeyToPem(privateKeyTwo);

    // Modify the file path below as per your machine, remember this is just for testing not in production code.
    File('C:\\Users\\HP\\Desktop\\b4testdata\\user2PrivateKey.pem').writeAsStringSync(user2PrivateKeyPem);

    final user2PublicKeyPem = crypto_utils.CryptoUtils.encodeEcPublicKeyToPem(publicKeyTwo);

    // Modify the file path below as per your machine, remember this is just for testing not in production code.
    File('C:\\Users\\HP\\Desktop\\b4testdata\\user2PublicKey.pem').writeAsStringSync(user2PublicKeyPem);

    final csr2 = x509.X509Utils.generateEccCsrPem(attributes2, privateKeyTwo, publicKeyTwo);
    final user2Certificate = x509.X509Utils.generateSelfSignedCertificate(privateKeyTwo, csr2, 365);

    // Modify the file path below as per your machine, remember this is just for testing not in production code.
    File('C:\\Users\\HP\\Desktop\\b4testdata\\user2Certificate.pem').writeAsStringSync(user2Certificate);



  });


}




/// hash check for certificate tampering
/*final verifyHash = await myObject.verifyHash(decryptedCertificate!, decryptedHash!);
    test('verification of cert for tampering', () {
      expect(verifyHash, true);
    });*/


//String dn1country = " mickey ";
//String dn2organization = " goofy ";
//String dn3commonName = " donald ";
//String dn4surname = " pluto ";
//String dn5stateOrProvinceName = "daffy ";
//String dn6givenName = " 989800764523 ";
//String dn7userID = "singh.inderpal.86@gmail.com ";

/// Server certificate verification for authenticity
//final privateFuture = myObject.readFromLocalStorage(LocalStorageValueType.serverPrivateKey);
//final serverPrivateKeyPemToSign = await privateFuture;
//final serverPrivateKeyToSign = crypto_utils.CryptoUtils.ecPrivateKeyFromPem(serverPrivateKeyPemToSign);
//final userSignedCertificate = x509.X509Utils.generateSelfSignedCertificate(serverPrivateKeyToSign, userCsr!, 365);


/// validity check of certificate for expiry. for testing we are using the same certificate because we want to
/// emulate the effect that we are getting a decrypted certificate from flutter secure storage
//final data1Future = myObject.readFromLocalStorage(LocalStorageValueType.serverCertificate);
//final decryptedServerSignedCertificate = await data1Future;// actually this certificate is encrypted by passkey and its
// hash has also been generated and stored in auth storage package
//final privateKeyPemDecrypted = generatedCertificate?.privateKeyPem;
//final publicKeyPemDecrypted = generatedCertificate?.publicKeyPem;
// final decryptedCertificate = generatedCertificate?.x509cert;
//final decryptedHash = generatedCertificate?.certHash;
//final userCsr = generatedCertificate?.csr;




/* test('server signed certificate generated', () async{
    final String serverSignedCertificate = await myObject.createClientCsrAndServerSignedCertificate(dn1country, dn2organization,
        dn3commonName, dn4surname, dn5stateOrProvinceName, dn6givenName, dn7userID);
    x509.X509CertificateData serverSignedCertContent = x509.X509Utils.x509CertificateFromPem(serverSignedCertificate );

      print('SUBJECT: ${serverSignedCertContent.tbsCertificate?.subject}');
    //print('sub pub key info: ${serverSignedCertContent.tbsCertificate?.subjectPublicKeyInfo}');
      print('ISSUER: ${serverSignedCertContent.tbsCertificate?.issuer}');
      print('VERSION: ${serverSignedCertContent.tbsCertificate?.version}');
      print('SERIAL NUMBER: ${serverSignedCertContent.tbsCertificate?.serialNumber}');
      print('VALID FROM: ${serverSignedCertContent.tbsCertificate?.validity.notBefore}');
      print('VALID UNTIL: ${serverSignedCertContent.tbsCertificate?.validity.notAfter}');
      print('SIGNATURE ALGORITHM: ${serverSignedCertContent.tbsCertificate?.signatureAlgorithm}');
      print('PUBLIC KEY ALGORITHM: ${serverSignedCertContent.tbsCertificate?.subjectPublicKeyInfo.algorithmReadableName}');
      print('PUBLIC KEY SHA 256 VALUE: ${serverSignedCertContent.tbsCertificate?.subjectPublicKeyInfo.sha256Thumbprint}');
      List<String?>? allAttributes = serverSignedCertContent.tbsCertificate?.subject.entries.map((entry) => entry.value).toList();
    print('ALL ATTRIBUTES: $allAttributes');
    String? clientemail = allAttributes?.elementAt(6);
    print('Client email : $clientemail');
    expect(serverSignedCertificate, isNotNull);
  });*/

/*test('generate node id and save in storage', () async {
  final nodeId = await myObject.getNodeId();
  print('node id generated and saved is :$nodeId');
  var nodeIdFuture = myObject.readFromLocalStorage(LocalStorageValueType.nodeid);
  var nodeIdRead = await nodeIdFuture; // Wait for the future to complete
  print('node id read  is :$nodeIdRead');
  expect(nodeIdRead, nodeId);
});*/