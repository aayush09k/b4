import 'dart:async';
import 'package:b4commgr/b4commgr.dart';

Future<void> main(List<String> args) async {
  final relayPort = args.isNotEmpty ? int.parse(args[0]) : 8888;
  final cm = CommunicationManager();

  cm.isProxy = true;
  cm.selfNodeHash = "NODE_A";

  await cm.startRelayServer(port: relayPort);
  print('Machine A (Relay Server) started on port $relayPort');

  Timer.periodic(
    const Duration(seconds: 10),
    (_) {
      print("\nRELAY TABLE");
      if (cm.connectedClients.isEmpty) {
        print("No registered clients");
      }
      cm.connectedClients.forEach(
        (nodeId, socket) {
          print(
              "$nodeId -> ${socket.remoteAddress.address}:${socket.remotePort}");
        },
      );
    },
  );
}
