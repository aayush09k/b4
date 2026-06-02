import 'dart:async';
import 'package:b4connection/B4connection.dart';
import 'package:b4utils/bufferdata.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// RelayClient  (updated: sends auth secret on registration)
///
/// Auth protocol:
///   On type='MP' registration, message body is a Map:
///     { "auth": "<sharedSecret>", "data": "register" }
///   The server reads payload['auth'] and rejects if it doesn't match.
///   Heartbeats remain plain strings — only registration carries auth.
/// ─────────────────────────────────────────────────────────────────────────────
class RelayClient {
  final String relayServerIp;
  final int relayServerPort;
  final String myNodeId;
  final String authSecret; // must match RelayServerConfig.sharedSecret
  final Duration heartbeatInterval;
  final int maxReconnectAttempts; // 0 = retry forever
  final Duration maxBackoff;

  final void Function(dynamic frame)? onFrame;
  final void Function(String reason)? onDisconnect;

  B4connection _conn = B4connection();
  final DataBuffer _buffer =
      DataBuffer(); // singleton, same as B4connection uses

  Timer? _heartbeatTimer;
  Timer? _pollTimer;
  Timer? _reconnectTimer;

  bool _connected = false;
  bool _intentionalDisconnect = false;
  int _reconnectAttempt = 0;

  RelayClient({
    required this.relayServerIp,
    required this.relayServerPort,
    required this.myNodeId,
    required this.authSecret,
    this.heartbeatInterval = const Duration(seconds: 10),
    this.maxReconnectAttempts = 0,
    this.maxBackoff = const Duration(seconds: 60),
    this.onFrame,
    this.onDisconnect,
  });

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> connect() async {
    _intentionalDisconnect = false;
    _reconnectAttempt = 0;
    await _attemptConnect();
  }

  dynamic pollFrame() => _buffer.pullIntemp();

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
        'as "$myNodeId" (attempt ${_reconnectAttempt + 1})...');

    try {
      final socket = await _conn
          .startConnection(relayServerIp, relayServerPort, 'MP', myNodeId)
          .timeout(const Duration(seconds: 10));

      if (socket == null) throw Exception('socket is null');

      // Registration message — auth secret embedded in the message body Map.
      // Server reads: decoded['message']['auth']
      await _conn.sendMessage(
          {'auth': authSecret, 'data': 'register'}, 'MP', myNodeId);

      _connected = true;
      _reconnectAttempt = 0;
      _log('✓ Registered as "$myNodeId"');

      _startHeartbeat();
      _startPolling();
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
      onDisconnect
          ?.call('Max retries exceeded after $_reconnectAttempt attempts');
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
        // Plain string heartbeat — no auth needed after registration
        await _conn.sendMessage('heartbeat', 'MP', myNodeId);
        _log('♥ Heartbeat sent');
      } catch (e) {
        _log('Heartbeat failed: $e');
        _connected = false;
        _stopAll();
        _scheduleReconnect();
      }
    });
  }

  // ── Polling ────────────────────────────────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    if (onFrame == null) return;

    _pollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      while (!_buffer.isIntempEmpty()) {
        final frame = _buffer.pullIntemp();
        if (frame == null) continue;

        // Filter out internal handshake frames from sender
        if (frame is Map) {
          final data = frame['data'];
          if (data == 'sender_online' || data == 'register') continue;
        }

        _log('▼ Frame: $frame');
        try {
          onFrame!(frame);
        } catch (e) {
          _log('onFrame error: $e');
        }
      }
    });
  }

  void _stopAll() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _log(String m) => print('[RelayClient] $m');
}

// ── main ──────────────────────────────────────────────────────────────────────

void main() async {
  final client = RelayClient(
    relayServerIp: '0.tcp.ngrok.io', // ← ngrok hostname
    relayServerPort: 12345, // ← ngrok TCP port
    myNodeId: 'CLIENT_NODE',
    authSecret: 'your-secret-key-change-me', // ← same as server
    heartbeatInterval: const Duration(seconds: 10),
    maxReconnectAttempts: 0,
    maxBackoff: const Duration(seconds: 60),
    onFrame: (frame) => print('>>> Received: $frame'),
    onDisconnect: (r) => print('!!! Disconnected: $r'),
  );

  await client.connect();
  await Future.delayed(const Duration(days: 365));
}
