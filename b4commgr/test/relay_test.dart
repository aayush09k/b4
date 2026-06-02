import 'dart:async';
import '../lib/relay/relay_server.dart';
import '../lib/relay/relay_client.dart';
import '../lib/relay/relay_sender.dart';

const _secret = 'your-secret-key-change-me'; // must match server config

void main() async {
  print('=== Relay Test Starting ===\n');

  // Step 1: Start server
  print('--- Step 1: Starting RelayServer on port 9000 ---');
  final server = RelayServer(
    config: RelayServerConfig(
      port: 9000,
      sharedSecret: _secret,
      nodeTimeout: const Duration(seconds: 35),
    ),
  );
  await server.start();
  await Future.delayed(const Duration(milliseconds: 300));

  // Step 2: Connect client
  print('\n--- Step 2: Connecting RelayClient as "nodeA" ---');
  String? receivedMessage;

  final client = RelayClient(
    relayServerIp: '127.0.0.1',
    relayServerPort: 9000,
    myNodeId: 'nodeA',
    authSecret: _secret, // ← required by hardened server
    onFrame: (frame) {
      receivedMessage = frame.toString();
      print('[TEST] RelayClient received: $frame');
    },
    onDisconnect: (r) => print('[TEST] Client disconnected: $r'),
  );

  await client.connect();
  await Future.delayed(const Duration(milliseconds: 500));

  // Step 3: Send via sender
  print('\n--- Step 3: RelaySender sending "hello nodeA" ---');
  final sender = RelaySender(
    relayServerIp: '127.0.0.1',
    relayServerPort: 9000,
    myNodeId: 'senderX',
    targetNodeId: 'nodeA', // ← fixed API: set at construction
    authSecret: _secret,
  );

  await sender.connect();
  await Future.delayed(const Duration(milliseconds: 300));

  await sender.sendMessage('hello nodeA'); // ← correct method name

  // Step 4: Wait and check
  print('\n--- Step 4: Waiting for forward... ---');
  await Future.delayed(const Duration(seconds: 2));

  // Results
  print('\n=== Test Results ===');
  print('Server node count:      ${server.nodeCount}'); // public getter
  print('Client connected:       ${client.isConnected}');
  print('Sender connected:       ${sender.isConnected}');
  print('Message received:       $receivedMessage');

  if (receivedMessage != null && receivedMessage!.contains('hello nodeA')) {
    print('\n✓ PASS — message relayed successfully!');
  } else {
    print('\n✗ FAIL — message not received. Check server logs above.');
  }

  // Cleanup
  print('\n--- Cleanup ---');
  await client.disconnect();
  await sender.disconnect(); // ← await the async disconnect
  server.stop();

  print('\n=== Relay Test Complete ===');
}
