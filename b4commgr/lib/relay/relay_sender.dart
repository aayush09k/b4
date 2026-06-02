import 'dart:async';
import 'package:b4connection/B4connection.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// RelaySender  (updated: sends auth secret on first message)
///
/// Auth protocol:
///   The sender connects with type='TP'. Because TcpConnection stores TP
///   connections in _remoTecNodeSocket under myNodeID just like D connections,
///   we send a self-registration as type='D' first, carrying the auth secret.
///   After that, all data messages use type='TP' (no auth needed per message).
///
///   Actually — looking at TcpConnection source, type='TP' sockets are NOT
///   stored in _remoTecNodeSocket (only MP and D are stored there). The sender
///   doesn't NEED a return path from the server, so this is fine.
///   We still send an initial 'D' registration with auth so the server can
///   log and verify who we are.
/// ─────────────────────────────────────────────────────────────────────────────
class RelaySender {
  final String relayServerIp;
  final int relayServerPort;
  final String myNodeId;
  final String targetNodeId;
  final String authSecret; // must match RelayServerConfig.sharedSecret
  final Duration heartbeatInterval;
  final int maxReconnectAttempts;
  final Duration maxBackoff;

  final void Function(String reason)? onDisconnect;

  B4connection _conn = B4connection();

  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  bool _connected = false;
  bool _intentionalDisconnect = false;
  int _reconnectAttempt = 0;

  RelaySender({
    required this.relayServerIp,
    required this.relayServerPort,
    required this.myNodeId,
    required this.targetNodeId,
    required this.authSecret,
    this.heartbeatInterval = const Duration(seconds: 10),
    this.maxReconnectAttempts = 0,
    this.maxBackoff = const Duration(seconds: 60),
    this.onDisconnect,
  });

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> connect() async {
    _intentionalDisconnect = false;
    _reconnectAttempt = 0;
    await _attemptConnect();
  }

  /// Send data to the target client via the relay.
  Future<void> sendMessage(dynamic message) async {
    if (!_connected) {
      _log('⚠ Not connected — message dropped: $message');
      return;
    }
    try {
      await _conn.sendMessage(message, 'TP', targetNodeId);
      _log('▲ Sent to "$targetNodeId": $message');
    } catch (e) {
      _log('Send failed: $e — reconnecting');
      _connected = false;
      _stopAll();
      _scheduleReconnect();
    }
  }

  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _connected = false;
    _stopAll();
    try {
      _conn.close();
    } catch (_) {}
    _log('Disconnected intentionally.');
  }

  bool get isConnected => _connected;

  // ── Connect ────────────────────────────────────────────────────────────────

  Future<void> _attemptConnect() async {
    if (_intentionalDisconnect) return;

    _conn = B4connection();
    _conn.setMyNodeId(myNodeId);
    _conn.onClosed = () {
      if (_intentionalDisconnect) return;
      if (_connected) {
        _connected = false;
        _stopAll();
        _log('Connection dropped — scheduling reconnect');
        _scheduleReconnect();
      }
    };

    _log('Connecting to $relayServerIp:$relayServerPort '
        '(attempt ${_reconnectAttempt + 1})...');

    try {
      // Connect with type='TP' — this is how senders identify themselves.
      // targetNodeId here tells the server which NAT-ed node we want to reach.
      final socket = await _conn
          .startConnection(relayServerIp, relayServerPort, 'TP', targetNodeId)
          .timeout(const Duration(seconds: 10));

      if (socket == null) throw Exception('socket is null');

      // Announce ourselves to the server with auth embedded in a Map message.
      // The server sees type='TP' and will try to forward this to targetNodeId —
      // that is fine (it acts as an initial "sender is online" notification to client).
      // Auth in payload lets server log and verify sender identity.
      await _conn.sendMessage(
        {'auth': authSecret, 'data': 'sender_online'},
        'TP',
        targetNodeId,
      );

      _connected = true;
      _reconnectAttempt = 0;
      _log('✓ Connected. Ready to send to "$targetNodeId".');

      _startHeartbeat();
    } on TimeoutException {
      _log('Connection timed out');
      _scheduleReconnect();
    } catch (e) {
      _log('Connection error: $e');
      _scheduleReconnect();
    }
  }

  // ── Reconnect ──────────────────────────────────────────────────────────────

  void _scheduleReconnect() {
    if (_intentionalDisconnect) return;
    _reconnectAttempt++;
    if (maxReconnectAttempts > 0 && _reconnectAttempt > maxReconnectAttempts) {
      onDisconnect?.call('Max retries exceeded');
      return;
    }
    final delay = _backoff(_reconnectAttempt);
    _log('Reconnecting in ${delay.inSeconds}s...');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _attemptConnect);
  }

  Duration _backoff(int n) {
    final s = (2 << (n - 1)).clamp(2, maxBackoff.inSeconds);
    final jitter = (n % 3) - 1;
    return Duration(seconds: (s + jitter).clamp(1, maxBackoff.inSeconds));
  }

  // ── Heartbeat ──────────────────────────────────────────────────────────────

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) async {
      if (!_connected) return;
      try {
        await _conn.sendMessage('heartbeat', 'TP', targetNodeId);
        _log('♥ Heartbeat sent');
      } catch (e) {
        _log('Heartbeat failed: $e');
        _connected = false;
        _stopAll();
        _scheduleReconnect();
      }
    });
  }

  void _stopAll() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _log(String m) => print('[RelaySender] $m');
}

// ── main ──────────────────────────────────────────────────────────────────────

void main() async {
  final sender = RelaySender(
    relayServerIp: '0.tcp.ngrok.io', // ← ngrok hostname
    relayServerPort: 12345, // ← ngrok TCP port
    myNodeId: 'SENDER_NODE',
    targetNodeId: 'CLIENT_NODE', // must match client's myNodeId
    authSecret: 'your-secret-key-change-me', // ← same as server
    heartbeatInterval: const Duration(seconds: 10),
    maxReconnectAttempts: 0,
    maxBackoff: const Duration(seconds: 60),
    onDisconnect: (r) => print('!!! Disconnected: $r'),
  );

  await sender.connect();

  // Example: send a message every 5 seconds
  Timer.periodic(const Duration(seconds: 5), (_) async {
    await sender.sendMessage('Hello @ ${DateTime.now()}');
  });

  await Future.delayed(const Duration(days: 365));
}
