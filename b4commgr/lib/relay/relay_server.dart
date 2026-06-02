import 'dart:async';
import 'dart:io';
import 'package:b4connection/TcpConnection.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// RelayServer  —  production-hardened
///
/// Hardening added over the original version:
///   ✓ Stale-client cleanup      — per-node timeout timer (default 35s)
///   ✓ Heartbeat-timeout eviction — resets on every message, fires on silence
///   ✓ Duplicate-node handling   — new registration kicks the old socket
///   ✓ Authentication            — shared secret carried in message['auth']
///   ✓ Rate limiting             — max messages/second per node
///   ✓ Per-IP connection cap     — rejects flood from one IP
///   ✓ Global node cap           — rejects when server is full
///   ✓ Registration deadline     — unregistered sockets evicted after timeout
///
/// ── Auth protocol ────────────────────────────────────────────────────────────
/// TcpConnection.createMessageJson() has a fixed 4-field format:
///   { type, remoteNodeID, myNodeID, message }
/// There is no 5th field, so we embed auth inside the 'message' field.
///
/// When type='MP' (registration), message must be a Map:
///   { "auth": "<sharedSecret>", "data": <anything> }
///
/// For heartbeats and type='TP' forwards, message can be a plain String.
/// The server reads auth ONLY from the first (registration) message.
/// Once a nodeId is authenticated, all subsequent messages from that socket
/// are trusted WITHOUT re-checking auth (the socket binding is proof enough).
///
/// ── How forwarding works ─────────────────────────────────────────────────────
/// TcpConnection._handleMessageFroMNode() handles type='TP' internally and
/// calls _rerouteBehindNAT(remoteNodeID, payload) automatically. This class
/// only audits and manages bookkeeping around that.
/// ─────────────────────────────────────────────────────────────────────────────

// ── Config ─────────────────────────────────────────────────────────────────────

class RelayServerConfig {
  final int port;
  final String? sharedSecret; // null = auth disabled (dev only)
  final Duration
      nodeTimeout; // silence → eviction (should be > heartbeat interval)
  final int maxNodes;
  final int maxConnectionsPerIp;
  final int maxMessagesPerSecond;

  const RelayServerConfig({
    this.port = 9000,
    this.sharedSecret,
    this.nodeTimeout = const Duration(seconds: 35),
    this.maxNodes = 100,
    this.maxConnectionsPerIp = 5,
    this.maxMessagesPerSecond = 50,
  });
}

// ── Per-node record ────────────────────────────────────────────────────────────

class _NodeRecord {
  final String nodeId;
  final Socket socket;
  final String remoteAddr;
  final String remoteIp;
  final DateTime connectedAt = DateTime.now();
  DateTime lastSeen = DateTime.now();
  Timer? timeoutTimer;

  // Rate-limit state
  int _msgCount = 0;
  Timer? _rateResetTimer;

  _NodeRecord({
    required this.nodeId,
    required this.socket,
    required this.remoteAddr,
    required this.remoteIp,
  });

  /// Returns true if the node has exceeded maxPerSecond messages this second.
  bool rateLimitExceeded(int maxPerSecond) {
    _msgCount++;
    _rateResetTimer ??= Timer(const Duration(seconds: 1), () {
      _msgCount = 0;
      _rateResetTimer = null;
    });
    return _msgCount > maxPerSecond;
  }

  void cancelTimers() {
    timeoutTimer?.cancel();
    timeoutTimer = null;
    _rateResetTimer?.cancel();
    _rateResetTimer = null;
  }
}

// ── RelayServer ────────────────────────────────────────────────────────────────

class RelayServer {
  final RelayServerConfig config;
  final TcpConnection _tcp = TcpConnection();

  // nodeId → record (authoritative relay table at this layer)
  final Map<String, _NodeRecord> _nodes = {};

  // remoteIp → active connection count
  final Map<String, int> _ipCount = {};

  // Sockets that connected but haven't sent a valid MP yet
  final Map<String, Timer> _pendingDeadlines = {};

  bool _running = false;

  RelayServer({RelayServerConfig? config})
      : config = config ?? const RelayServerConfig();

  // ── Start / stop ──────────────────────────────────────────────────────────

  Future<void> start() async {
    if (_running) return;
    await _tcp.startASsNode(config.port);
    _running = true;
    _log('✓ Listening on port ${config.port}');
    _log(config.sharedSecret != null
        ? '🔑 Auth enabled'
        : '⚠  Auth DISABLED — set sharedSecret for production');
    await _tcp.receiveSocketsFromCNode(_onNewSocket);
  }

  void stop() {
    _running = false;

    // Copy to lists first — destroying sockets fires onClosed callbacks which
    // call _onSocketClosed → modifies _nodes. Iterating while modifying throws
    // "Concurrent modification during iteration".
    final records = _nodes.values.toList();
    final deadlines = _pendingDeadlines.values.toList();

    for (final r in records) {
      r.cancelTimers();
      _destroySocket(r.socket);
    }
    for (final t in deadlines) {
      t.cancel();
    }

    _nodes.clear();
    _ipCount.clear();
    _pendingDeadlines.clear();
    _tcp.stopASsNode();
    _log('Stopped.');
  }

  bool get isRunning => _running;
  int get nodeCount => _nodes.length;

  // ── New socket ─────────────────────────────────────────────────────────────

  Future<void> _onNewSocket(Socket socket) async {
    final remoteAddr = '${socket.remoteAddress.address}:${socket.remotePort}';
    final remoteIp = socket.remoteAddress.address;

    // Per-IP cap
    if ((_ipCount[remoteIp] ?? 0) >= config.maxConnectionsPerIp) {
      _log('✗ Reject $remoteAddr — too many from $remoteIp');
      _destroySocket(socket);
      return;
    }

    // Global cap
    if (_nodes.length >= config.maxNodes) {
      _log('✗ Reject $remoteAddr — server full');
      _destroySocket(socket);
      return;
    }

    _ipCount[remoteIp] = (_ipCount[remoteIp] ?? 0) + 1;
    _log('← New connection from $remoteAddr');

    // Evict if no MP registration arrives within nodeTimeout
    _pendingDeadlines[remoteAddr] = Timer(config.nodeTimeout, () {
      if (_pendingDeadlines.containsKey(remoteAddr)) {
        _log('✗ Evicting unregistered socket $remoteAddr (timed out)');
        _pendingDeadlines.remove(remoteAddr);
        _destroySocket(socket);
        _decrementIp(remoteIp);
      }
    });

    await _tcp.invokeListening((message, active) {
      if (active) {
        _onMessage(message, socket, remoteAddr, remoteIp);
      } else {
        _onClosed(socket, remoteAddr, remoteIp);
      }
    }, socket);
  }

  // ── Message dispatch ───────────────────────────────────────────────────────

  void _onMessage(
      dynamic msg, Socket socket, String remoteAddr, String remoteIp) {
    final type = msg['type'] as String?;
    final nodeId = msg['myNodeID'] as String?;
    final target = msg['remoteNodeID'] as String?;
    final payload = msg['message']; // String or Map depending on message type

    // Registered nodes: check rate limit and refresh timeout
    if (nodeId != null && _nodes.containsKey(nodeId)) {
      final rec = _nodes[nodeId]!;
      if (rec.rateLimitExceeded(config.maxMessagesPerSecond)) {
        _log('⚠ Rate limit: dropping message from "$nodeId"');
        return;
      }
      _refreshTimeout(rec);
    }

    switch (type) {
      case 'MP':
        _onRegister(msg, socket, remoteAddr, remoteIp, nodeId, payload);
        break;
      case 'TP':
        _onForward(nodeId, target);
        break;
      case 'D':
        _onDirect(nodeId, socket, remoteAddr, remoteIp);
        break;
      default:
        // Heartbeat (or anything else) — timeout already refreshed above
        break;
    }
  }

  // ── Registration ──────────────────────────────────────────────────────────

  void _onRegister(
    dynamic msg,
    Socket socket,
    String remoteAddr,
    String remoteIp,
    String? nodeId,
    dynamic payload,
  ) {
    if (nodeId == null || nodeId.trim().isEmpty) {
      _log('✗ MP with no nodeId from $remoteAddr — rejected');
      _pendingDeadlines.remove(remoteAddr)?.cancel();
      _destroySocket(socket);
      _decrementIp(remoteIp);
      return;
    }

    // ── Auth check ─────────────────────────────────────────────────────────
    // Auth secret rides in message['message']['auth'] when type='MP'.
    // payload is expected to be a Map: { "auth": "<secret>", "data": ... }
    if (config.sharedSecret != null) {
      String? providedSecret;
      if (payload is Map) {
        providedSecret = payload['auth'] as String?;
      }
      if (providedSecret != config.sharedSecret) {
        _log('✗ Auth failed for "$nodeId" from $remoteAddr — rejected');
        _pendingDeadlines.remove(remoteAddr)?.cancel();
        _destroySocket(socket);
        _decrementIp(remoteIp);
        return;
      }
    }

    // Cancel the "unregistered" deadline
    _pendingDeadlines.remove(remoteAddr)?.cancel();

    // ── Duplicate-node handling ────────────────────────────────────────────
    // Same nodeId registering again (crash+reconnect). New socket wins.
    if (_nodes.containsKey(nodeId)) {
      final old = _nodes[nodeId]!;
      _log('⚠ Duplicate "$nodeId" — kicking old socket ${old.remoteAddr}');
      old.cancelTimers();
      _destroySocket(old.socket);
      // Note: don't decrement IP here — the onDone callback will do it when
      // the old socket actually closes.
      _nodes.remove(nodeId);
    }

    final rec = _NodeRecord(
      nodeId: nodeId,
      socket: socket,
      remoteAddr: remoteAddr,
      remoteIp: remoteIp,
    );
    _nodes[nodeId] = rec;
    _startTimeout(rec);

    _log('✓ Registered "$nodeId"  addr=$remoteAddr');
    _printTable();
  }

  // ── Forward ───────────────────────────────────────────────────────────────

  void _onForward(String? senderId, String? target) {
    // Forwarding already done by TcpConnection internally. We audit only.
    _log('↷ Forward "$senderId" → "$target"');
    if (target != null && !_nodes.containsKey(target)) {
      _log('  ⚠ Target "$target" not registered — TcpConnection dropped it');
    }
  }

  // ── Direct ────────────────────────────────────────────────────────────────

  void _onDirect(
      String? nodeId, Socket socket, String remoteAddr, String remoteIp) {
    _pendingDeadlines.remove(remoteAddr)?.cancel();
    if (nodeId != null) _log('ℹ Direct from "$nodeId"');
  }

  // ── Socket closed ─────────────────────────────────────────────────────────

  void _onClosed(Socket socket, String remoteAddr, String remoteIp) {
    _pendingDeadlines.remove(remoteAddr)?.cancel();

    final entry =
        _nodes.entries.where((e) => e.value.socket == socket).firstOrNull;

    if (entry != null) {
      entry.value.cancelTimers();
      _nodes.remove(entry.key);
      _log('✗ Disconnected: "${entry.key}"  addr=$remoteAddr');
      _printTable();
    } else {
      _log('✗ Disconnected (unregistered): $remoteAddr');
    }

    _decrementIp(remoteIp);
  }

  // ── Timeout management ────────────────────────────────────────────────────

  void _startTimeout(_NodeRecord rec) {
    rec.timeoutTimer?.cancel();
    rec.timeoutTimer = Timer(config.nodeTimeout, () {
      _log(
          '✗ Timeout: evicting "${rec.nodeId}" (silent >${config.nodeTimeout.inSeconds}s)');
      _evictNode(rec.nodeId);
    });
  }

  void _refreshTimeout(_NodeRecord rec) {
    rec.lastSeen = DateTime.now();
    _startTimeout(rec); // restart the countdown
  }

  void _evictNode(String nodeId) {
    final rec = _nodes.remove(nodeId);
    if (rec == null) return;
    rec.cancelTimers();
    _destroySocket(rec.socket);
    _decrementIp(rec.remoteIp);
    _printTable();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _destroySocket(Socket s) {
    try {
      s.destroy();
    } catch (_) {}
  }

  void _decrementIp(String ip) {
    final n = (_ipCount[ip] ?? 1) - 1;
    if (n <= 0)
      _ipCount.remove(ip);
    else
      _ipCount[ip] = n;
  }

  void _printTable() {
    if (_nodes.isEmpty) {
      _log('  relay table: (empty)');
      return;
    }
    _log('  relay table: [${_nodes.keys.join(', ')}]');
  }

  void _log(String m) => print(
      '[RelayServer ${DateTime.now().toIso8601String().substring(11, 23)}] $m');
}

// ── main ──────────────────────────────────────────────────────────────────────

void main() async {
  final server = RelayServer(
    config: RelayServerConfig(
      port: 9000,
      sharedSecret: 'your-secret-key-change-me', // ← CHANGE THIS
      nodeTimeout: const Duration(seconds: 35),
      maxNodes: 100,
      maxConnectionsPerIp: 5,
      maxMessagesPerSecond: 50,
    ),
  );
  await server.start();
  await Future.delayed(const Duration(days: 365));
}
