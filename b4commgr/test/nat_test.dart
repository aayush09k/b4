import 'package:b4commgr/IfBehindNAT.dart'; // Ensure this matches your project name/path
import 'dart:io';

void main() async {
  print('==================================================');
  print('STARTING LIVE STUN NAT DETECTION TEST...');
  print('==================================================');

  // Trigger your function to query the STUN server and look at local interfaces
  bool isBehindNAT = await checkIfBehindNAT();

  print('--------------------------------------------------');
  print('TEST COMPLETE!');
  print('RESULT: Is this computer behind a NAT? -> $isBehindNAT');
  print('==================================================');

  // Clean exit
  exit(0);
}
