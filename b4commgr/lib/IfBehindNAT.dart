import 'dart:io';
import 'helperfunction.dart'; // Imports your helper file directly

/// Dynamically tests network configuration using a public STUN server connection
Future<bool> checkIfBehindNAT() async {
  try {
    String stunServer = 'stun.l.google.com';
    int stunPort = 19302;

    // 1. Run the raw transaction test to obtain 'PublicIP:Port'
    String mappedAddress = await performStunTest(stunServer, stunPort);

    if (mappedAddress.isEmpty) {
      print(
          "No STUN connectivity detected. Defaulting to behind NAT fallback.");
      return true;
    }

    // Split string to separate the IP string from the port integer
    var parts = mappedAddress.split(':');
    if (parts.length != 2) return true;
    String publicIP = parts[0];

    print("STUN server public observation address: $publicIP");

    // 2. Query active network hardware interface mapping lists
    List<NetworkInterface> interfaces = await NetworkInterface.list();

    for (var interface in interfaces) {
      for (var address in interface.addresses) {
        // If an explicit network interface adapter contains the public IP address matching
        // the external observer tracking metrics, no intermediate translation layer is present.
        if (!isPrivateIP(address.address) && address.address == publicIP) {
          return false; // Direct connection found (Not behind NAT)
        }
      }
    }
  } catch (e) {
    print("Error during NAT check evaluation sequence: $e");
  }

  // If local adapters lack matching public addresses, the target node is hidden behind NAT
  return true;
}
